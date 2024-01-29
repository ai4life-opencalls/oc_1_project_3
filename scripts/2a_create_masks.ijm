/*
 * This script allows users to create a mask for regions
 * they wish to exclude in the next step of the analysis.
 * The script pauses on each image and users can draw ROIs
 * of any shape and add them to the ROI manager (shortcut
 * [t]). The output masks are saved with the same filename
 * in the output directory.
 * 
 * License BSD 3-Clause, AI4Life, 2024
 */


// Parameters 
#@ File(label="Input directory", style="directory") rawDirectory
#@ File(label="Output directory", style="directory") masksDirectory


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

// Prepare Fiji state
setTool("rectangle");
setForegroundColor(255, 255, 255);
setBackgroundColor(0, 0, 0);

// List all images
files = listTiffs(rawDirectory);

// Run on all images
for (i = 0; i < files.length; i++) {
	roiManager("reset");
	roiManager("Show All");
	
	// Open image
	path = rawDirectory + File.separator + files[i];
	fileName = File.getName(files[i]);
	run("Bio-Formats Importer", "open=[" + path + "] open_all_series windowless=true");
	
	print("Opened " + fileName);
	
	// Retrieve width and height
	width = getWidth();
	height = getHeight();
	
	// Pause and allow use to draw ROIs
	waitForUser("Draw ROIs, add them to the ROI manager [t], then click Ok!");
	
	// Check number of ROIs
	nROIs = roiManager("count");
	print("Found "+ nROIs + " ROIs.");
	
	// If there is at least one ROI
	if(nROIs > 0){
		// Select all ROIs, create a black image and fill the ROIs with white
		indexes = Array.getSequence(nROIs);
		roiManager("select", indexes);
		newImage("Mask", "8-bit black", width, height, 1);
		roiManager("Fill");
		
		// Save mask
		mask = masksDirectory + File.separator + fileName;
		print("Saved " + mask);
		saveAs("Tiff", mask);
	}
	
	close("*");
}

print("Done!");