/*
 * This script processes a stack of masks exported from napari
 * to scale the images to the right size and bit depth.
 * 
 * Parameters:
 * ----------
 * Masks: path to the masks.
 * Output directory: directory in which to save the images.
 * Scale factor: scaling factor used during downsampling.
 * 	
 * 	License BSD 3-Clause, AI4Life, 2024
 */

// Parameters
#@ File(label="Masks", style="file") maskPath
#@ File(label="Output directory", style="directory") outputDirectory
#@ Integer(label="Scale factor", value=8) scaleFactor 


// Load image
run("Bio-Formats Importer", "open=[" + maskPath + "] open_all_series windowless=true");

// Re-scale values
run("Divide...", "value=2 stack");

bits = bitDepth();
max_val = Math.pow(2, bits)-1;
run("Multiply...", "value="+max_val+" stack");

// Set to 8 bit
setOption("ScaleConversions", true);
run("8-bit");

// Scale
newWidth = getWidth() * scaleFactor;
newHeight = getHeight() * scaleFactor;
depth = getSliceNumber();
run("Scale...", "x="+scaleFactor+" y="+scaleFactor+" z=1.0 width="+newWidth+" height="+newHeight+" depth="+depth+" interpolation=Bilinear average process create");

// Export
run("Image Sequence... ", "dir="+outputDirectory+" format=TIFF");

close("*");
