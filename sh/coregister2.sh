#!/bin/sh

#  Coregistration.sh
#  brainmapper
#
#  Created by John Wu
#  Adapted by Allison Pearce and Veena Krish, 2014
#  Copyright (c) 2013 University of Pennsylvania. All rights reserved.

RESPATH=$1
IMAGEPATH=$2
UPDATEPATH=$3
echo "Path to executables is $RESPATH, images is $IMAGEPATH, updateFile is $UPDATEPATH"
SEGMENT=$4
UNBURY=$5
THRES=$6


# FSL Configuration (add FSL directory to path)
FSLDIR=${RESPATH}
echo $FSLDIR
PATH=${FSLDIR}/bin:${PATH}
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Add binaries to path (add $RESPATH to path)
PATH=${RESPATH}:${PATH}
ANTSPATH=${RESPATH}/

export ANTSPATH PATH FSLDIR

#--------------------Below copied from fsh.sh-------------------------------
#  - note that the user should set

# Written by Mark Jenkinson
#  FMRIB Analysis Group, University of Oxford

# SHCOPYRIGHT


#### Set up standard FSL user environment variables ####

# The following variable selects the default output image type
# Legal values are:  ANALYZE  NIFTI  NIFTI_PAIR  ANALYZE_GZ  NIFTI_GZ  NIFTI_PAIR_GZ
# This would typically be overwritten in ${HOME}/.fslconf/fsl.sh if the user wished
#  to write files with a different format
FSLOUTPUTTYPE=NIFTI_GZ
export FSLOUTPUTTYPE

# Comment out the definition of FSLMULTIFILEQUIT to enable
#  FSL programs to soldier on after detecting multiple image
#  files with the same basename ( e.g. epi.hdr and epi.nii )
FSLMULTIFILEQUIT=TRUE ; export FSLMULTIFILEQUIT

FSLCONFDIR=$FSLDIR/config
#FSLMACHTYPE=`$RESPATH/fslmachtype.sh`

#export FSLCONFDIR FSLMACHTYPE


###################################################
####    DO NOT ADD ANYTHING BELOW THIS LINE    ####
###################################################

if [ -f /usr/local/etc/fslconf/fsl.sh ] ; then
. /usr/local/etc/fslconf/fsl.sh ;
fi


if [ -f /etc/fslconf/fsl.sh ] ; then
. /etc/fslconf/fsl.sh ;
fi


if [ -f "${HOME}/.fslconf/fsl.sh" ] ; then
. "${HOME}/.fslconf/fsl.sh" ;
fi

#------------------------------------------------------------
#!/bin/bash


cd ${IMAGEPATH}
echo working directory is `pwd`
echo "setting paths to images in coregister.sh" >> ${UPDATEPATH}
T1=${IMAGEPATH}/mri.nii.gz # pre-resection
template=${RESPATH}/NIREPG1template.nii.gz
templateLabels=${RESPATH}/NIREPG1template_35labels.nii.gz
templateTissueLabels=${RESPATH}/NIREPG1_3tissue.nii.gz
warpOutputPrefix=NIREP # don't be the same as template file main body
CT=${IMAGEPATH}/ct.nii.gz # with electrodes
#T2=20070922_t2w003.nii.gz # post-resection
#resection=20070922_t2w003_resectedRegion.nii.gz
MRF_smoothness=0.1
electrode_thres=${THRESH}



#T2=nii.gz # post-resection
#resection=resectedRegion.nii.gz
#MRF_smoothness=0.1
#doParcellation=0 # if 1, do parcellation else do tissue segmentation only

# strip the skull in T1
bet2 $T1 ${T1%.nii.gz}_brain -m

# align CT to T1 and extract the electrodes
antsIntroduction.sh -d 3 -r $T1 -i $CT -o ${CT%.nii.gz}_ -t RI -s MI
c3d ${CT%.nii.gz}_deformed.nii.gz -threshold ${electrode_thres} 99999 1 0 -o electrode_aligned.nii.gz


# ad hoc cleaning of wires outside brain
c3d ${T1%.nii.gz}_brain_mask.nii.gz -dilate 1 5x5x5mm electrode_aligned.nii.gz -times electrode_aligned_cleanup.nii.gz

# combine electrode with monochrome brain mask
c3d electrode_aligned_cleanup.nii.gz -scale 2 ${T1%.nii.gz}_brain_mask.nii.gz -add -clip 0 2 -o electro_brain_mask.nii.gz

# exit

# warp the NIREP template to skull-stripped T1
antsIntroduction.sh -d 3 -r $template -i ${T1%.nii.gz}_brain.nii.gz -o ${warpOutputPrefix}_ -m 30x90x20 -l $templateLabels

if [[ $SEGMENT == "1" ]]
then
# perform prior-based segmentation on the warped labels (may require more memory)
# :<<commentblock
mkdir priorBasedSeg
cd priorBasedSeg
rm labels.txt
for i in `seq 1 9`; do echo 0$i >> labels.txt; done
for i in `seq 10 35`; do echo $i >> labels.txt; done
for i in `cat labels.txt`
do
ThresholdImage 3 ../${warpOutputPrefix}_labeled.nii.gz label${i}.nii.gz $i $i
ImageMath 3 label_prob${i}.nii.gz G label${i}.nii.gz 3
done

Atropos -d 3 -a ../$T1 -x ../${T1%.nii.gz}_brain_mask.nii.gz -i PriorProbabilityImages[35,./label_prob%02d.nii.gz,0.5] -m [${MRF_smoothness},1x1x1] -c [5,0] -p Socrates[0] -o [./NIREP_seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz]

cp NIREP_seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz ../seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz
cd ..

# combine electrodes with T1 segmentation
c3d electrode_aligned.nii.gz -scale 40 seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz -add -clip 0 40 -o seg35labels_prior0.5_mrf${MRF_smoothness}_electro.nii.gz
itksnap -g $T1 -s seg35labels_prior0.5_mrf${MRF_smoothness}_electro.nii.gz -l templateCorticalLabels.txt &

else
echo "not segmenting"
WarpImageMultiTransform 3 ${templateTissueLabels} ${warpOutputPrefix}tissue_labeled.nii.gz -R ${T1} -i ${warpOutputPrefix}_Affine.txt ${warpOutputPrefix}_InverseWarp.nii.gz --use-NN

mkdir tissueSeg
cd tissueSeg
rm labels.txt
for i in `seq 1 3`; do echo 0$i >> labels.txt; done
for i in `cat labels.txt`
do
pwd
ThresholdImage 3 ../${warpOutputPrefix}tissue_labeled.nii.gz label${i}.nii.gz $i $i
ImageMath 3 label_prob${i}.nii.gz G label${i}.nii.gz 3
done

num_its=3

N4BiasFieldCorrection -d 3 -i ../${T1} -x ../${T1%.nii.gz}_brain_mask.nii.gz -o ./${T1%.nii.gz}_n4.nii.gz -s 2 -c [50x50x50x50,0.0000000001] -b [200]

echo Tissue segmentation iteration 1
Atropos -d 3 -a ./${T1%.nii.gz}_n4.nii.gz -x ../${T1%.nii.gz}_brain_mask.nii.gz -i PriorProbabilityImages[3,./label_prob%02d.nii.gz,0.1] -m [0.1,1x1x1] -c [3,0] -p Socrates[0] -o [./NIREP_tissue_it1.nii.gz,./prob%02d.nii.gz]

for it in `seq 2 ${num_its}` ; do
echo Tissue segmentation iteration $it
Atropos -d 3 -a ./${T1%.nii.gz}_n4.nii.gz -x ../${T1%.nii.gz}_brain_mask.nii.gz -i PriorProbabilityImages[3,./prob%02d.nii.gz,0.1] -m [0.1,1x1x1] -c [3,0] -p Socrates[0] -o [./NIREP_tissue_it${it}.nii.gz,./prob%02d.nii.gz]
done

Atropos -d 3 -a ./${T1%.nii.gz}_n4.nii.gz -x ../${T1%.nii.gz}_brain_mask.nii.gz -i PriorProbabilityImages[3,./prob%02d.nii.gz,0.1] -m [0.2,1x1x1] -c [3,0] -p Socrates[1] -o ./NIREP_tissue_last.nii.gz

c3d ../electrode_aligned_cleanup.nii.gz -scale 4 ./NIREP_tissue_last.nii.gz  -add -clip 0 4 -o ../electro_3tissue.nii.gz
cd ..
itksnap -g $T1 -s electro_3tissue.nii.gz &
fi

# commentblock

exit


# RESECTION STUFF
# -----------------------------------------------------------------------------------
# aligned post-resection T2 to (pre-resection) T1
#./antsIntroduction.sh -d 3 -r $T1 -i $T2 -o ${T2%.nii.gz}_ -t RI -s MI

# transform resected region from post-resection T2 to (pre-resection) T1
#WarpImageMultiTransform 3 $resection ${resection%.nii.gz}_aligned.nii.gz -R $T1 ${T2%.nii.gz}_Affine.txt

# combine the resected cortex (brain mask minus resection) and the electrodes
#c3d ${T1%.nii.gz}_brain_mask.nii.gz ${resection%.nii.gz}_aligned.nii.gz -thresh 0.99 99 2 0 -add -clip 0 2 electrode_aligned.nii.gz -scale 3 -add -clip 0 3 -o ElectrodesOnResectedCortex.nii.gz
