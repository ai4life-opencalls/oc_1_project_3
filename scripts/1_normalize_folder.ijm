/*
 * This scripts open all tiffs in a folder and pause so that users
 * can draw around a white area in each image, it then computes the  
 * modes of the RGB distribution in the white area in order to  
 * adjust the white balance. The script then splits the image into
 * chanels, normalize them and saves the recomposed image.
 * 
 * White-balancing is performed by setting the max value in each
 * channel to the mode of the corresponding channel in the user 
 * delimited white patch.
 * 
 * License BSD 3-Clause, AI4Life, 2024
 */

// Parameters 
#@ File(label="Input directory", style="directory") rawDirectory

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

// Output directory
if(rawDirectory.endsWith(File.separator)){
	outputDirectory = rawDirectory.substring(0, rawDirectory.length - 1) + "-normalized";
} else {
	outputDirectory = rawDirectory + "-normalized";
}
File.makeDirectory(outputDirectory);
print("Output directory: " + outputDirectory);

// List all images
files = listTiffs(rawDirectory);

// Run on all images
for (i = 0; i < files.length; i++) {	
	// Open file
	path = rawDirectory + File.separator + files[i];
	fileName = File.getName(files[i]);
	run("Bio-Formats Importer", "open=[" + path + "] open_all_series windowless=true");
	
	print("Opened " + fileName);
	
	// Wait for user
	waitForUser("Select a background region (only white background) and click Ok!");
	
	// Record ROI in the ROI manager
	roiManager("reset");
	roiManager("add");
	
	// Split channels
	run("Split Channels");
	
	// Channels name
	c1 = "C1-" + fileName;
	c2 = "C2-" + fileName;
	c3 = "C3-" + fileName;

	channels = newArray(3);
	channels[0] = c1;
	channels[1] = c2;
	channels[2] = c3;
	
	// Normalize each channel
	for (j = 0; j < channels.length; j++) {
		// Select image
		selectImage(channels[j]);
		
		// Select roi
		roiManager("select", 0);
		
		// Calculate the mode
		mode = getValue("Mode");

		// Deselect roi
		Roi.remove;
		
		// Apply nornmalization
		setMinAndMax(0, mode);
		run("Apply LUT");
	}
	
	// Recompose image
	run("Merge Channels...", "c1=" + c1 + " c2=" + c2 + " c3=" + c3 + " create");
	run("RGB Color");
	
	// New name
	ind_extension = fileName.lastIndexOf(".");
	newName = fileName.substring(0, ind_extension) + "-normalized" + fileName.substring(ind_extension);
	
	// Save and close
	output = outputDirectory + File.separator + newName;
	print("Saved " + output);
	saveAs("Tiff", output);
	close("*");
}

print("Done!");


