#!/bin/bash

inputFile=treat_line_exp.inp
FLUKArepoPath=/home/amereghe/Desktop/Flash_Therapy/FLUKA_repo
FLUKAexe=${FLUKArepoPath}/Routines/fluka.exe
export FLUPRO=/usr/local/FLUKA_INFN/2020.0.5
export FLUKA=${FLUPRO}
export FLUFOR=gfortran

# start job
echo " starting job at `date`..."

#  run
echo "running command: ${FLUKA}/flutil/rfluka -e ${FLUKAexe} -N0 -M5 ${inputFile%.inp}"
${FLUKA}/flutil/rfluka -e ${FLUKAexe} -N0 -M5 ${inputFile%.inp}

# end of job
echo " ...ending job at `date`."
cd - > /dev/null 2>&1
