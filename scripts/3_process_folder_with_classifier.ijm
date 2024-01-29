/*
 * This script processes all tiffs from an input folder using a Labkit classifier,
 * it then extracts and save the different class segmentations. Finally, it adds
 * the fiber and tissue segmentations, computes the ratio of the areas and save the
 * results in an excel-compatible file.
 * 
 * Parameters:
 * ----------
 * Labkit classifier: path to a trained labkit classifier.
 * Input directory: directory containing the images to segment.
 * Output directory: directory in which to save the images.
 * Exclude masks: whether to exclude masks from the quantification.
 * Masks directory: directory containing the masks.
 * 
 * Notes:
 * ------
 * 	- The labels "tissue" and "collagen" MUST be present (but their order depends
 * 	on the classifier)
 * 	- The default name of the labels can be changed by modifying the TISSUE and
 * 	FIBER variables.
 * 	- All results are saved in a result_summary.txt file.
 *  - Masks should be tiffs and have the same name as their target image. Their pixels
 *  value should be equal to 1 in the area to exclude, 0 otherwise.
 * 	
 * 	License BSD 3-Clause, AI4Life, 2024
 */

// Parameters
#@ File(label="Labkit classifier", style="file") classifier
#@ File(label="Input directory", style="directory") inputDirectory
#@ File(label="Output directory", style="directory") outputDirectory
#@ String(label="Labels (comma-separated)", value="bg, tissue, collagen") labels 
#@ Boolean(label="Exclude masks", value=false) excludeMasks 
#@ File(label="Masks directory", style="directory") masksDirectory

// These are the labels we are interested in
TISSUE = "tissue";
FIBER = "collagen";

// Other constants
SEG = "segmentation";
INPUT = "input";
MASK = "mask";
SUM = TISSUE+"_"+FIBER;
SUM_MASKED = SUM+"_masked";
FIBER_MASKED = FIBER+"_masked";

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


///////////////////////////////////
//////// Prepare variables ////////
///////////////////////////////////

// Script start
print("------ Starting process ------");

// Stops if the classifier does not end with ".classifier"
if (!classifier.endsWith(".classifier")) {
	classifierName = File.getName(classifier);
	exit("\"" + classifierName + "\" is not a Labkit classifier.");
}

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

// If output directory doesn't exist, attempt to create it
if(!File.exists(outputDirectory)){
	File.makeDirectory(outputDirectory);
}

// Check if will exclude masks
if(excludeMasks){
	print("Will exclude masks.");
} else{
	print("No mask exclusion");
}

///////////////////////////////////
//////// Loop over images /////////
///////////////////////////////////

// Set options
setBatchMode("hide"); // hides the images, this accelerates computation
setOption("BlackBackground", true);

// create arrays to store the results
resultFile = newArray(0); 
resultAreaTissue = newArray(0);
resultAreaFiber = newArray(0);
resultAreaPercentage = newArray(0);

// create arrays to store the results (mask exclusion)
resultAreaTissue_excl = newArray(0);
resultAreaFiber_excl = newArray(0);
resultAreaPercentage_excl = newArray(0);

for (i = 0; i < 1; i++) {
		
	///////////////////////////////////
	////////// Segment image //////////
	///////////////////////////////////
	
	// Open file
	path = inputDirectory + File.separator + files[i];
	fileName = File.getName(files[i]);
	run("Bio-Formats Importer", "open=[" + path + "] open_all_series windowless=true");
	rename(INPUT);

	// Segment with Labkit
	print("Will segment the following file with Labkit:");
	print(path);
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
		print("Error: "+filename+" needs " + nSegs + " labels, got " + nLabels + ".");
		continue;
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
	
	///////////////////////////////////
	////////// Quantification /////////
	///////////////////////////////////
	
	// Sum tissue and fiber
	imageCalculator("OR create", TISSUE, FIBER);
	
	// Close original tissue
	selectImage(TISSUE);
	close();
	
	// Compute areas in pixels using the histogram
	selectImage("Result of " + TISSUE);
	rename(SUM);	
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
	
	// Do the same for the masked areas
	if(excludeMasks){
		// Get potential file name
		maskPath = masksDirectory + File.separator + files[i];
		print("Mask: "+maskPath);
		
		// If the mask exists
		if(File.exists(maskPath)){
			print("Loading mask.");
			
			// Load it
			run("Bio-Formats Importer", "open=[" + maskPath + "] open_all_series windowless=true");
			rename(MASK);
			
			// Invert and normalize
			run("Invert");

			// Multiply tissue by the mask 
			imageCalculator("AND create", SUM, MASK);
			rename(SUM_MASKED);
			
			getStatistics(area, mean, min, max, std, histogram);
			areaTissueMasked = histogram[255];
	
			saveAs("Tiff", outputDirectory + File.separator + resultFile[i] + "_segmentation_sum_" + SUM_MASKED + ".tif");
			close();
						
			// Multiply collagen by the mask
			imageCalculator("AND create", FIBER, MASK);
			rename(FIBER_MASKED);
			
			getStatistics(area, mean, min, max, std, histogram);
			areaFiberMasked = histogram[255];
	
			saveAs("Tiff", outputDirectory + File.separator + resultFile[i] + "_segmentation_" + FIBER_MASKED + ".tif");
			close();
			
			// quantification
			percFiberMasked = 100*(areaFiberMasked / areaTissueMasked);
			
			// Add results to array
			resultAreaTissue_excl[i] = areaTissueMasked;
			resultAreaFiber_excl[i] = areaFiberMasked;
			resultAreaPercentage_excl[i] = percFiberMasked;
		} else {
			print("No mask found.");
		}
	}
	
	// Save and close images
	selectImage(SUM);	
	saveAs("Tiff", outputDirectory + File.separator + resultFile[i] + "_segmentation_sum_" + SUM + ".tif");
	close();
	
	selectImage(FIBER);	
	close();
	
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

if(excludeMasks){
	Table.create("Results Masked");
	Table.setColumn("File", resultFile);
	Table.setColumn(FIBER + " area", resultAreaFiber_excl);
	Table.setColumn(TISSUE + " area", resultAreaTissue_excl);
	Table.setColumn(FIBER + " %", resultAreaPercentage_excl);
	Table.save(outputDirectory + File.separator + "result_summary_masked.txt");
}

// Done
print("Done!");