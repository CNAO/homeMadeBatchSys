#!/bin/bash

export FLUPRO=/usr/local/FLUKA/INFN/2021.2.9
export FLUKA=${FLUPRO}
export FLUFOR=gfortran
FLUKAexe=${FLUPRO}/flukahp
inputFile=FLUKAbench.inp
NN=0
MM=5

# start job
echo " starting job at `date` in folder $PWD..."

#  run
echo "running command: ${FLUKA}/flutil/rfluka -e ${FLUKAexe} -N${NN} -M${MM} ${inputFile%.inp}"
${FLUKA}/flutil/rfluka -e ${FLUKAexe} -N${NN} -M${MM} ${inputFile%.inp}

# end of job
echo " ...ending job at `date`."
