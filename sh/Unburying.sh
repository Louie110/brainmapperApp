#!/bin/bash

#  unbury.sh
#  brainmapper
#
#  Created by Veena Krish on 7/22/13.
#  Copyright (c) 2013 University of Pennsylvania. All rights reserved.

IMAGEPATH=$1
RESPATH=$2
UPDATEPATH=$3

# Add binaries to path in case they weren't there (add $RESPATH to path and export again; hopefully no one will complain)
PATH=${RESPATH}:${PATH}
export PATH

#--------------------------------------------------------------------------------------------------------
cd $IMAGEPATH
echo We Are At: $PWD

# 1. unload files
c3d ${IMAGEPATH}/electrode_aligned.nii.gz -binarize -o eImg.img

# 1.5
# ad hoc cleaning of wires outside brain
c3d ${IMAGEPATH}/mri_brain_mask.nii.gz -dilate 1 2x2x2mm electrode_aligned.nii.gz -times -o electrode_aligned_cleanup.nii.gz
c3d ${IMAGEPATH}/electrode_aligned_cleanup.nii.gz -binarize -o eImg.img

#2. get centroids:
c3d eImg.img -comp -o mImg.img
numCOMPS=$(c3d eImg.img -comp | head -n 1| sed 's/[^0-9]/ /g')

echo numCOMPS = $numCOMPS

echo "UNBURYING.SH: Locating electrodes for unburying."
echo "Locating electrodes for unburying." >> $UPDATEPATH

rm -f eCent.txt
rm -f eCenters.txt
rm -f eCenters2.txt

counter = 0
for i in `seq 1 $numCOMPS`; do
echo Locating electrode: $i
  c3d mImg.img -threshold $i $i 1 0 -o nImg.img
  elecSize=$(c3d nImg.img -voxel-sum | awk '{print $3}')
  if [[ $elecSize -gt 10 ]] ; then
    c3d nImg.img -centroid >> eCent.txt
    (( counter++ ))
  fi
done
echo "Added " $counter " elements from " $numCOMPS " components."

cat eCent.txt | sed -e '/VOX/d' -e '/There/d' -e '/Largest/d' -e 's/[^0-9.-]/ /g' >> eCenters.txt #(this gets rid of unneccessary info in the txt file)
sed -e 's/$/ 1/' eCenters.txt > eCenters2.txt

#3. get center of brain:

#c3d mri_brain.nii.gz -info > info
#cat info | tr ';' '\012' | grep 'bb =' | sed 's/[^0-9.]/ /g' > bounds
#
#bBounds=( `cat bounds`)
#
#bb0=${bBounds[0]}
#bb1=${bBounds[1]}
#bb2=${bBounds[2]}
#bb3=${bBounds[3]}
#bb4=${bBounds[4]}
#bb5=${bBounds[5]}
#
#bCOMx=$( echo "scale=4; (${bb0}+${bb3}) / 2" | bc);
#bCOMy=$( echo "scale=4; (${bb1}+${bb4}) / 2" | bc);
#bCOMz=$( echo "scale=4; (${bb2}+${bb5}) / 2" | bc);
#
#4. Get the directions each electrode needs to travel in:
#cat eCenters.txt | awk -v x=${bCOMx} -v y=${bCOMy} -v z=${bCOMz} '{ printf("%f %f %f\n",$1-x, $2-y, $3-z) }' >> directions

#5. AND NOW FOR EACH ELECTRODE, retrieve its direction vector in lowest termss
#NUMELECTRODES=$( cat directions | wc -l )
#for i in `seq 1 $NUMELECTRODES`; do
#for i in `seq 1 10`; do
#  echo "UNBURY.SH: Analyzing electrode: " $i
#
#  eDir=(`sed -n "${i}p" < directions`)
#  dirX=${eDir[0]}
#  dirY=${eDir[1]}
#  dirZ=${eDir[2]} #(there's prob a better way to do this)
#
#  #get the electrode's CoM from the big file
#  eCOMS=(`sed -n "${i}p" < eCenters.txt`)
#  eCOMx=${eCOMS[0]}
#  eCOMy=${eCOMS[1]}
#  eCOMz=${eCOMS[2]}
#
#  startValue=$( c3d bImg.img -probe ${eCOMx}x${eCOMy}x${eCOMz}mm | awk '{ print substr($0,length,1) }' )
#  echo $startValue >> startValues
#  if [[ $startValue -eq 0 ]]; then
#    echo "UNBURY.SH: Artifact found outside brain."
#    continue
#  fi
#
#  #TRY: instead of reducing to lowest terms with the gcd, just normalize the vector....I'm doing this in physical mm's so having decimals shouldn't matter.
#  norm=$( echo "scale=10; ${dirX}^2 + ${dirY}^2 + ${dirZ}^2" | bc )
#  norm=$( echo "scale=10; sqrt($norm)" | bc )
#
#  dirX=$( echo "scale=10; $dirX / $norm" | bc )
#  dirY=$( echo "scale=10; $dirY / $norm" | bc )
#  dirZ=$( echo "scale=10; $dirZ / $norm" | bc )
#
#
#  #and get the "step": the direction in increments...
#  distance=$( echo "scale=4; sqrt((${eCOMS[0]} - ${dirX})^2 + (${eCOMS[1]} - ${dirY}) ^2 + (${eCOMS[2]} - ${dirZ})^2 )" | bc);
#  stepX=$( echo "scale=4; 100 * ${dirX} / (${distance} - 1)" | bc);
#  stepY=$( echo "scale=4; 100 * ${dirY} / (${distance} - 1)" | bc);
#  stepZ=$( echo "scale=4; 100 * ${dirZ} / (${distance} - 1)" | bc);
#  echo "$stepX $stepY $stepZ" >> steps
#
#  echo Before loop
#
#  # this really should work......
#  #7. Create a path from bCOM in the direction of each electrode's eDir
#  value=1
#  counter=0
#  oldPoint=$eCOMx\ $eCOMy\ $eCOMz
#  until [[ $value -eq 0 ]]; do
#    #echo "counter is: $counter"
#    #echo "value is: $value"
#    newPoint=$eCOMx\ $eCOMy\ $eCOMz
#    value=$( c3d bImg.img -probe ${eCOMx}x${eCOMy}x${eCOMz}mm | awk '{ print substr($0,length,1) }' )
#    status=$?
#    if [[ $status -ne 0 ]]; then break
#    elif [[ $counter -eq 50 ]]; then
#      newPoint=$oldPoint
#      echo "counter reached 20; breaking"
#      break
#      #fi
#    elif [[ $value -eq 1 ]]; then
#      eCOMx=$( echo "scale=4; ${eCOMx}+${stepX}" | bc);
#      eCOMy=$( echo "scale=4; ${eCOMy}+${stepY}" | bc);
#      eCOMz=$( echo "scale=4; ${eCOMz}+${stepZ}" | bc);
#      counter=`expr $counter + 1`
#      continue
#    fi
#    break
#  done
#
#  echo "$newPoint 1" >> landmarks
#  echo $i $newPoint landmarked
#done


#8. AND FINALLY
echo "UNBURY.SH: #8 Create unburied_electrode_aligned.nii.gz"
c3d mImg.img -scale 0 -landmarks-to-spheres eCenters2.txt 2 -o landmarked.img
c3d landmarked.img -o unburied_electrode_aligned.nii.gz