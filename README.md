<p align="center">
  <a href="https://ai4life.eurobioimaging.eu/open-calls/">
    <img src="https://github.com/ai4life-opencalls/.github/blob/main/AI4Life_banner_giraffe_nodes_OC.png?raw=true">
  </a>
</p>

# Project 3: Treat CKD

The aim of the project is to compute the percentage of collagen versus tissue in each
of the tissue slices. There are two types of tissues, heart and kidney, originating
from mouse and rats. Additional structures can be excluded from the analysis, such as 
blood vessels or glomeruli.

In order to carry out the quantification, we perform pixel classification of the images
using Labkit, a plugin available in Fiji.


## Report problems or ask questions

If you have any questions or problems, please open 
[an issue](https://github.com/ai4life-opencalls/oc_1_project_3/issues) in this repository. 


## Installation

### Installing Fiji

You can download Fiji from [here](https://imagej.net/software/fiji/downloads).


## (Optional) Installing Jupyter and napari

The Jupyter notebooks are used for quality control, while our napari plugins provide
additional tools to create masks in order to exclude areas from the analysis.

Both need to be installed using Python, and we recommend to use a virtual environment.
To do that we will need a terminal (aka command prompt). While unix-based systems
(MacOS, Linux) have a terminal by default, Windows users will need to install one to
simplify the installation process. We recommend to use 
[git bash](https://gitforwindows.org/).

1. Open the terminal and check whether your have `conda` installed by typing `conda -V`.
   If you get an error, you will need to install it. Otherwise, you can skip to step 3.
2. Install [miniconda](https://docs.conda.io/projects/miniconda/en/latest/). Make sure to check "Add to Path environment variable". Restart 
   your terminal and verify that now conda works.
3. Let's download the repository. In the terminal, type the following lines (see the primer on bash commands below):
    ```bash
    mkdir git
    cd git
    git clone https://github.com/ai4life-opencalls/oc_1_project_3
    cd oc_1_project_3
    ```
4. We then create a `conda` environment in which to install both Jupyter and napari.
    ```bash
    conda env create -f environment.yml
    ```
   You will need to answer `y` to the installation of the packages.
5. Now, and everytime you start your terminal, it is important to activate the 
   environment. To do that, type `conda activate ckd`. If this does not work, that means
   that you probably need to do a `conda init bash` first and restart your terminal.
6. You can start a Jupyter server by typing `jupyter notebook`. It will open a new page
   in your browser. There, navigate to the `quality_control` folder and open one of the
   notebook.
7. Open a new terminal, activate the environment and start napari by typing `napari`.

> **Primer on bash commands:**
> - `pwd`: prints the working directory
> - `ls`: lists the files in the directory
> - `cd <directory>`: goes to <directory>, if you are in the correct parent folder.


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
5. [Results](#5---results): explore the results.

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

> **Note**: You can use any type of ROI selection, e.g. lasso. This is useful when the
> background regions are not really compatible with a rectangle selection.

All resulting images are saved into a new folder (`*-normalized`). We recommend to
perform a quality control to check whether the normalization was succesful. For this,
you can either open all images in Fiji and compare them, or used the 
`quality_control/1_explore_normalization.ipynb` notebook. 


### 2a - Mask creation

This one of the four methods we propose to create masks for exclusion of image regions
from the analysis. This method is more straightforward as it relies only on Fiji. It can
be used to create rectangles - the simplest shape -, or more complex ROIs by drawing
circles or even freehand shapes.

1. Open and run `scripts/2a_create_mask.ijm`.
2. For each image, the script will pause and ask you to draw a ROI around areas you want
to exclude from the analysis. Each time you draw a ROI, press `t` to add it to the ROI
manager.
3. Once you are done, press `OK` to move to the next image.

> **Note**: You can use any type of ROI selection, e.g. lasso or circle as well. It is 
> just important to remember to add each new ROI to the ROI manager using the `t` shortcut.


All resulting images are saved into the mask folder. We recommend to
perform a quality control to check whether the masks are correct. For this,
you can either open all images in Fiji and compare them, or used the 
`quality_control/2_explore_masks.ipynb` notebook. 


### 2b - Using SAM in napari

This method is more complex but potentially more powerful, as it levereages Segment
Anything Model (SAM), once of the most advanced AI model for segmentation. We use SAM 
by providing prompts (positive and negative points, or rectangles) to the model. SAM 
then output masks that can be saved for later use.

1. In order to limit the number of clicking, we advise to create a stack in Fiji of all
   your images (e.g. 20).
2. The second thing is to scale down your images to save computation time and space. For 
   instance, if your images are 3074x2048, you can scale them by a factor 0.125 (x8). In
   Fiji, click on `Image > Scale...` and enter the factor in the `X` and `Y` fields.
3. Save as a tiff stack.
4. Open napari by entering `napari` in a terminal.
5. 

+ scale at the masks at the end 

(soon to be expanded)

We recommend to perform a quality control to check whether the masks are correct. For this,
you can either open all images in Fiji and compare them, or used the 
`quality_control/2_explore_masks.ipynb` notebook. 

### 2c - Pairing SAM embeddings with Random Forest

This method is more complex but can prove incredibly powerful in guiding SAM towards
what we want to obtain. Since this is the main tool used in another project, we advise 
you to look in [OC project 52](https://github.com/ai4life-opencalls/oc_1_project_52) for 
how to proceed with this method.

Note that in this case, the goal is still to create masks for the areas we want to 
exclude!


1. In order to limit the number of clicking, we advise to create a stack in Fiji of all
   your images (e.g. 20).
2. The second thing is to scale down your images to save computation time and space. For 
   instance, if your images are 3074x2048, you can scale them by a factor 0.125 (x8). In
   Fiji, click on `Image > Scale...` and enter the factor in the `X` and `Y` fields.
3. Save as a tiff stack.
4. Open napari by entering `napari` in a terminal.
5. 

+ scale at the masks at the end 


### 2d - Painting with Labkit

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

We recommend to perform a quality control to check whether the masks are correct. For this,
you can either open all images in Fiji and compare them, or used the 
`quality_control/2_explore_masks.ipynb` notebook. 


### 3 - Training a pixel classifier

1. Load all normalized images into Fiji.
2. By default, the image might be loaded as a z-stack. Click on `Image > Properties...`,
   and set the number of slices to 1, and the number of frames equal to the number
   of images. Click `OK` and save the stack as a tiff image.
3. Load the stack again in Fiji.
4. In the search bar of Fiji, type `Labkit` and click on `Open current image with Labkit`.
5. Create the different labels corresponding to the classes you need (e.g. background,
   tissue, collagen, cells). It helps to make colors similar to the image, but also
   visible enough when overlaid (this comes with experience with Labkit).
6. For each label, select the brush (brush size 1) and draw small scribbles in the most
   representative pixels and borders of the class. Do not label too much at the beginning.
7. Add a Labkit classifier and train it.
8. Observe the results and correct them by adding a few labels to the area where the classifier 
    is not performing well.
9. Move to another slice of the stack often, in order to create a classifier that 
    generalizes well.
10. You can toggle the view between the classifier result and the original image using 
    the little eye icons.
11. Once you are happy with the results, save the classifier 
    (`Segmentation > Save Classifier ...`) and write down the order of the classes.


### 4 - Process images and quantification

1. Open and run `scripts/4_process_folder_with_classifier.ijm`.
2. If you want to exclude masks from the analysis, check `Exclude masks` and choose
   the folder containing the masks.
3. At the end of the computation, all results are saved in the result folder, 
   including the summary table.

We recommend to perform a quality control to check whether the masks are correct. For 
this, you can either open all images in Fiji and compare them, or used the 
`quality_control/4a_explore_segmentation_classes.ipynb` and 
`quality_control/4b_explore_tissue_collagen.ipynb` notebooks. 


### 5 - Results

You can use the software of your choice to plot the results (e.g. excel). In the 
`quality_control` folder, we provide a notebook to explore the results 
(`5_plot_results.ipynb`).


## Acknowledgements

AI4Life has received funding from the European Union’s Horizon Europe research and 
innovation programme under grant agreement number 101057970. Views and opinions 
expressed are however those of the author(s) only and do not necessarily reflect those 
of the European Union or the European Research Council Executive Agency. Neither the 
European Union nor the granting authority can be held responsible for them.
