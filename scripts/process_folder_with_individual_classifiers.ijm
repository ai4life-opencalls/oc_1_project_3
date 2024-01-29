/*
 * This script processes all tiffs from an input folder using Labkit classifiers,
 * it then extracts and save the different class segmentations. Finally, it adds
 * the fiber and tissue segmentations, computes the ratio of the areas and save the
 * results in an excel-compatible file.
 * 
 * Important:
 * 	- The labels "tissue" and "collagen" MUST be present (but their order depends
 * 	on the classifier)
 * 	- The default name of the labels can be changed by modifying the TISSUE and
 * 	FIBER variables.
 *
 * 	License BSD 3-Clause, AI4Life, 2024
 */

// Parameters
#@ File(label="Classifiers directory", style="directory") classifiers
#@ File(label="Input directory", style="directory") inputDirectory
#@ File(label="Output directory", style="directory") outputDirectory
#@ String(label="Labels (comma-separated)", value="bg, tissue, collagen") labels 

// These are the labels we are interested in
TISSUE = "tissue";
FIBER = "collagen";

// Other constants
SEG = "segmentation";
INPUT = "input";

// Functions
function listTiffs(dir) { 
	/*
	 * List of all tiff images in a directory.
	 * 
	 * Parameters
	 * ----------
	 * dir: String
	 * 	Directory in which the images are stored
	 * 	
	 * Return
	 * ------
	 * An array containing the images name
	 */

	// Get file list
	files = getFileList(dir);

	counter = 0;
	tiffFiles = newArray(0);

	// Check each file for the extension
	for (i = 0; i < files.length; i++) {
		if (files[i].endsWith("tif") || files[i].endsWith("tiff")) {
			tiffFiles[counter] = files[i];
			counter++;
		}
	}

	return tiffFiles;
}

// Script start
print("------ Starting process ------");

// List all images
files = listTiffs(inputDirectory);

// Stops if no image detected
if (files.length == 0) {
	folderName = File.getName(inputDirectory);
	exit("The folder \"" + folderName + "\" does not contain tiff files.");
}

// Create array labels
labelsArray = split(labels, ",");

// Check if there is at least 2 labels
if (labelsArray.length <= 1) {
	exit("Need at least 2 labels, got \"" + labels + "\".");
}

// Check if there are empty labels, find collagen and tissue
ind_tissue = -1;
ind_fiber = -1;
for (i = 0; i < labelsArray.length; i++) {
	// Remove spaces
	if (labelsArray[i].startsWith(" ")) {
		labelsArray[i] = substring(labelsArray[i], 1);
	}

	// Detect empty strings and tissue/fiber indices
	if (labelsArray[i] == "") {
		exit("Got an empty label.");
	} else if (labelsArray[i] == TISSUE) {
		ind_tissue = i;
	} else if (labelsArray[i] == FIBER) {
		ind_fiber = i;
	} 
}

// Check if both tissue and fiber are in the labels
if (ind_tissue == -1) {
	exit("Label \"" + TISSUE + "\" missing from labels.");
}
if (ind_fiber == -1) {
	exit("Label \"" + FIBER + "\" missing from labels.");
}

// Loop over the files
setBatchMode("hide"); // hides the images, this accelerates computation

resultFile = newArray(0); // create arrays to store the results
resultAreaTissue = newArray(0);
resultAreaFiber = newArray(0);
resultAreaPercentage = newArray(0);

for (i = 0; i < files.length; i++) {
	// Open file
	path = inputDirectory + File.separator + files[i];
	fileName = File.getName(files[i]);
	run("Bio-Formats Importer", "open=[" + path + "] open_all_series windowless=true");
	rename(INPUT);
	
	// If classifier exists
	ind_extension = fileName.lastIndexOf(".");
	classifier = classifiers + File.separator + fileName.substring(0, ind_extension) + ".classifier";
	print("Classifier: " + classifier);

	if(File.exists(classifier)) {
		// Segment with Labkit
		print("Will segment " + fileName + " with Labkit");
		run("Segment Image With Labkit", "input=[" + INPUT + "] segmenter_file=[" + classifier + "] use_gpu=false");
	
		// Close original image
		close(INPUT);
	
		// Save result and rename it
		selectImage("segmentation of " + INPUT);
		resultFile[i] = File.getNameWithoutExtension(fileName);
		saveAs("Tiff", outputDirectory + File.separator + resultFile[i] + "_segmentation.tif");
		rename(SEG);
	
		// Check number of channels versus the number of labels
		getStatistics(area, mean, min, max, std, histogram);
		if (max + 1 != labelsArray.length) {
			nSegs = max + 1;
			nLabels = labelsArray.length;
			exit("In " + fileName + ", need " + nSegs + " labels, got " + nLabels + ".");
		}
	
		// For each label, duplicate and threshold
		for (j = 0; j < labelsArray.length; j++) {
			// Duplicate image
			selectImage(SEG);	
			run("Duplicate...", "title="+labelsArray[j]);
			
			// Threshold image
			setThreshold(j, j);
			run("Convert to Mask");
			
			// Save image
			saveAs("Tiff", outputDirectory + File.separator + resultFile[i] + "_segmentation_" + labelsArray[j] + ".tif");
			rename(labelsArray[j]);
			
			// Close channels others than tissue and fibers
			if(j != ind_fiber && j != ind_tissue){
				close(labelsArray[j]);
			}
		}
		close(SEG);
		
		// Sum tissue and fiber
		imageCalculator("Add create", TISSUE, FIBER);
		
		// Close original tissue
		selectImage(TISSUE);
		close();
		
		// Compute areas in pixels using the histogram
		selectImage("Result of " + TISSUE);
		rename(TISSUE);	
		getStatistics(area, mean, min, max, std, histogram);
		areaTissue = histogram[255];
		
		selectImage(FIBER);
		getStatistics(area, mean, min, max, std, histogram);
		areaFiber = histogram[255];
		
		percFiber = 100*(areaFiber / areaTissue);
		
		// Add results to array
		resultAreaTissue[i] = areaTissue;
		resultAreaFiber[i] = areaFiber;
		resultAreaPercentage[i] = percFiber;
		
		// Save and close images
		selectImage(TISSUE);	
		saveAs("Tiff", outputDirectory + File.separator + resultFile[i] + "_segmentation_sum_" + TISSUE + "_" + FIBER + ".tif");
		close();
		
		selectImage(FIBER);	
		close();
	} else {
		// Close original image
		close(INPUT);
		
		print("Classifier does not exist.");
	}
	
	// Update user
	print("Processed " + files[i]);
}

// Create a table for the results
Table.create("Results");
Table.setColumn("File", resultFile);
Table.setColumn(FIBER + " area", resultAreaFiber);
Table.setColumn(TISSUE + " area", resultAreaTissue);
Table.setColumn(FIBER + " %", resultAreaPercentage);
Table.save(outputDirectory + File.separator + "result_summary.txt");

// Done
print("Done!");