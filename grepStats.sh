#!/bin/bash

myCase=$1
myUnit=1E6
stats=`grep -h 'Total number of primaries run' ${myCase}/run_*/*.out | awk -v unit=${myUnit}  '{tot=tot+$6}END{print (tot/unit)}'`

echo "stats for ${myCase}: ${stats} x${myUnit}"
