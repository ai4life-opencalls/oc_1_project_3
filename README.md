<p align="center">
  <a href="https://ai4life.eurobioimaging.eu/open-calls/">
    <img src="https://github.com/ai4life-opencalls/.github/blob/main/AI4Life_banner_giraffe_nodes_OC.png?raw=true">
  </a>
</p>

# Treat CKD

The aim of the project is to compute the percentage of collagen versus tissue in each
of the tissue slices. There are two types of tissues, heart and kidney, originating
from mouse and rats. Additional structures can be excluded from the analysis, such as 
blood vessels or glomeruli.

In order to carry out the quantification, we perform pixel classification of the images
using Labkit, a plugin available in Fiji.

## Installation

### Installing Fiji

(soon)

### Installing Labkit

(soon)

## (Optional) Installing the napari plugin

(soon)


## Usage

The pipeline consists of [Fiji](https://fiji.sc/) scripts, a Fiji plugin and an 
optional [napari](https://napari.org/stable/) plugin. It includes the following steps:

1. [Data normalization](#1---data-normalization): normalize data to allow better 
  classification using a single Labkit trained classifier.
2. [Mask creation](#2a---mask-creation): create masks in order to exclude regions from
  the analysis.
3. [Training a pixel classifier](#3---training-a-pixel-classifier): training a Labkit
  classifier to segment the images into different classes.
4. [Process images and quantification](#4---process-images-and-quantification): process
  the images using the trained classifier and compute the percentage of collagen versus
  tissue+collagen.

The set of scripts expect normalized files and masks to have the same name. The structure
of the folder resulting from the analysis is as follows, but only the separation in 
folders and file naming are essential for the analysis to run:

```
├── trained_classifier.classifier
├── raw
│   ├── image1.tiff
│   ├── ...
│   └── imageN.tiff
├── raw-normalized
│   ├── image1-normalised.tiff
│   ├── ...
│   └── imageN-normalised.tiff
├── masks
│   ├── image1-normalised.tiff
│   ├── ...
│   └── imageN-normalised.tiff
└── result_analysis
    ├── image1-normalised_segmentation_bg.tiff
    ├── image1-normalised_segmentation_collagen_masked.tiff
    ├── image1-normalised_segmentation_collagen.tiff
    ├── image1-normalised_segmentation_sum_tissue_collagen_masked.tiff
    ├── image1-normalised_segmentation_sum_tissue_collagen.tiff
    ├── image1-normalised_segmentation_tissue.tiff
    ├── image1-normalised_segmentation.tiff
    ├── ...
    ├── result_summary_masked.tiff
    └── result_summary.tiff
```

`raw-normalized` is created in section 1, `masks` in section 2, the classifier in 
section 3 and finally, `result_analysis` in section 4.


### 1 - Data normalization

1. Place all data into a single folder, as tiff images.
2. Open Fiji and click on `Plugins > Macro > Edit`.
3. Open and run `scripts/1_normalize_folder.ijm`.
4. Select the folder containing the images.
5. For each image, the script will pause and ask you to draw a small rectangle on a 
white patch (background). After drawing a rectangle, click on `OK` to move to the next
image.

All resulting images are saved into a new folder (`*-normalized`).


### 2a - Mask creation

This one of the three methods we propose to create masks for exclusion of image regions
from the analysis. This method is more straightforward as it relies only on Fiji. It can
be used to create rectangles - the simplest shape -, or more complex ROIs by drawing
circles or even freehand shapes.

1. Open and run `scripts/2a_create_mask.ijm`.
2. For each image, the script will pause and ask you to draw a ROI around areas you want
to exclude from the analysis. Each time you draw a ROI, press `t` to add it to the ROI
manager.
3. Once you are done, press `OK` to move to the next image.

All resulting images are saved into the mask folder.


### 2b - Using SAM in napari

This method is more complex but potentially more powerful, as it levereages Segment
Anything Model (SAM), once of the most advanced AI model for segmentation. We use SAM 
in two different ways:

- By adding positive and negative prompts (points) or drawing recangles around the 
  regions we want to exclude from the analysis. This is the most straightforward way
  to use SAM.
- By using SAM together with Random Forests (similar to Labkit), where several classes
  need to be labeled with small scribbles.

(soon)

### 2c - Painting with Labkit

1. Load all normalized images into Fiji.
2. By default, the image might be loaded as a z-stack. Click on `Image > Properties...`,
   and set the number of slices to 1, and the number of frames point equal to the number
   of images. Click `OK` and save the stack as a tiff image.
3. Load the stack again in Fiji.
4. In the search bar of Fiji, type `Labkit` and click on `Open current image with Labkit`.
5. Delete the `background` label layer.
6. Select the brush and paint around the areas you want to exclude. You can either paint
with then brush, e.g. with a larger brush size, or make an outline and use the 
`Flood Fill` tool to fill in the center.
7. Save the labelings (`Labeling > Save Labeling...`) often.
8. Once you are done, show the labeling in Fiji (`Labeling > Show Labeling in ImageJ`).
9. Save the labeling as a sequence of images (`.tiff`).

Note that for the next sections, the normalized images and their corresponding masks
must have the same name, e.g. `raw-normalised/image1.tiff` and `masks/image1.tiff`. 
Therefore, you might have to rename the images, for instance by exporting the stack
as a sequence as well.


### 3 - Training a pixel classifier

1. Load all normalized images into Fiji.
2. By default, the image might be loaded as a z-stack. Click on `Image > Properties...`,
   and set the number of slices to 1, and the number of frames point equal to the number
   of images. Click `OK` and save the stack as a tiff image.
3. Load the stack again in Fiji.
4. In the search bar of Fiji, type `Labkit` and click on `Open current image with Labkit`.
5. (soon)


### 4 - Process images and quantification

1. Open and run `scripts/4_process_folder_with_classifier.ijm`.
2. If you want to exclude masks from the analysis, check `Exclude masks` and choose
   the folder containing the masks.



AI4Life has received funding from the European Union’s Horizon Europe research and 
innovation programme under grant agreement number 101057970. Views and opinions 
expressed are however those of the author(s) only and do not necessarily reflect those 
of the European Union or the European Research Council Executive Agency. Neither the 
European Union nor the granting authority can be held responsible for them.
