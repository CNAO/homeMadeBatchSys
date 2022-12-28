#!/bin/bash

inputFile=XPRcolli.inp
FLUKAexe=/usr/local/FLUKA/INFN/2021.2.8/flukadpm3
export FLUPRO=/usr/local/FLUKA/INFN/2021.2.8
export FLUKA=${FLUPRO}
export FLUFOR=gfortran

# start job
echo " starting job at `date` in folder $PWD..."

#  run
echo "running command: ${FLUKA}/flutil/rfluka -e ${FLUKAexe} -N0 -M5 ${inputFile%.inp}"
${FLUKA}/flutil/rfluka -e ${FLUKAexe} -N0 -M5 ${inputFile%.inp}

# end of job
echo " ...ending job at `date`."
