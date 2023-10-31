#!/bin/bash

# A.Mereghetti, 2022-11-28
# this is a template batch job file

RunFolder=$HOME

# start batch job
echo " starting job at `date`..."
cd ${RunFolder}

# --------------------------------------
# actual simulation job
echo " ...running in $PWD as $USER ..." 
for ((ii=1;ii<=1200;ii++)); do
    echo "Hello world! ${ii}"
    sleep 1
done
# --------------------------------------

# end of batch job
cd - > /dev/null 2>&1
echo " ...ending job at `date`."
