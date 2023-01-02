#!/bin/bash

# FLUKA env var must be defined!

scorings=( RESNUCLE USRBIN USRBDX USRTRACK )
inpFile=XPRcolli.inp
where="run_*"

for myScor in ${scorings[@]} ; do
    case ${myScor}  in
        RESNUCLE)
            extension="rnc"
            exeMerge="usrsuw"
            myCol=3
            ;;
        USRBDX)
            extension="bnx"
            exeMerge="usxsuw"
            myCol=4
            ;;
        USRBIN)
            extension="bnn"
            exeMerge="usbsuw"
            myCol=4
            ;;
        USRTRACK)
            extension="trk"
            exeMerge="ustsuw"
            myCol=4
            ;;
        USRYIELD)
            extension="yie"
            exeMerge="usysuw"
            myCol=4
            ;;
        *)
            echo "...don't know how to process ${myScor} detectors! skipping..."
            continue
    esac
    echo "checking presence of ${myScor} cards in ${inpFile} file..."
    units=`grep ${myScor} ${inpFile}  | grep -v -e DCYSCORE -e AUXSCORE | awk -v myCol=${myCol} '{un=-\$myCol; if (20<un && un<100) {print (un)}}' | sort -g | uniq`
    if [[ "${units}" == "" ]] ; then
        echo "...no cards found!"
        continue
    else
        units=( ${units} )
        echo "...found ${#units[@]} ${myScor} cards: processing..."
        for myUnit in ${units[@]} ; do
            echo " merging ${myScor} on unit ${myUnit} ..."
            ls -1 ${where}/*${myUnit} > ${myUnit}.txt
            echo "" >> ${myUnit}.txt
            echo "${inpFile%.inp}_${myUnit}.${extension}" >> ${myUnit}.txt
            ${FLUKA}/flutil/${exeMerge} < ${myUnit}.txt > ${myUnit}.log 2>&1
            rm ${myUnit}.*            
        done
    fi
done
