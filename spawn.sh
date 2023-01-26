#!/bin/bash

caseDir=C_Ni
origDir=.
inputFile=XPRcolli.inp
jobFile=job_FLUKA.sh
nPrims=1500000
seedMin=11
seedMax=20
# what to do
lPrepare=false
lSubmit=false
lStop=true
lClean=false
# hand-made queueing system
lQueue=true
spoolingPath=/mnt/DATA/homeMadeBatchSys/queueing

currDir=$PWD
# use "." as floating-point separator
export LC_NUMERIC="en_US.UTF-8"

if ${lPrepare} ; then
    # prepare study dir
    echo " preparing jobs of study ${caseDir} ..."
    if [ -d ${caseDir} ] ; then
        echo " ...study folder ${caseDir} already exists! updating files..."
    else
        mkdir ${caseDir}
    fi
    # copy files
    cd ${origDir}
    cp ${inputFile} ${jobFile} ${currDir}/${caseDir}
    cd - > /dev/null 2>&1
    # final steps of preparation (a folder per seed)
    cd ${caseDir}
    for ((iSeed=${seedMin}; iSeed<=${seedMax}; iSeed++ )) ; do 
        echo " ...preparing seed ${iSeed}..."
        dirNum=`printf "run_%05i" "${iSeed}"`
        if [ -d ${dirNum} ] ; then
            echo " ...folder ${dirNum} already exists: recreating it!"
            rm -rf ${dirNum}
        fi
        mkdir ${dirNum}
        cp *.* ${dirNum}
        # random seed
        sed -i "s/^RANDOMIZ.*/RANDOMIZ         1.0`printf "%10.1f" "${iSeed}"`/g" ${dirNum}/${inputFile}
        # number of primaries
        sed -i "s/^START.*/START     `printf "%10.1f" "${nPrims}"`/g" ${dirNum}/${inputFile}
    done
    cd - > /dev/null 2>&1
fi

if ${lSubmit} ; then
    echo " submitting jobs of study ${caseDir} ..."
    for ((iSeed=${seedMin}; iSeed<=${seedMax}; iSeed++ )) ; do
        echo " ...submitting seed ${iSeed}..."
        dirNum=`printf "run_%05i" "${iSeed}"`
        if ${lQueue} ; then
            currJobFile=job_${caseDir}_${dirNum}_`date "+%Y-%m-%d_%H-%M-%S"`.sh
            cat > ${currJobFile} <<EOF
#!/bin/bash
cd ${PWD}/${caseDir}/${dirNum}
./${jobFile} > ${jobFile}.log 2>&1
EOF
            chmod +x ${currJobFile}
            mv ${currJobFile} ${spoolingPath}
        else
            cd ${caseDir}/${dirNum}
            ./${jobFile} > ${jobFile}.log 2>&1 &
            cd - > /dev/null 2>&1
        fi
    done
fi

if ${lStop} ; then
    # gently stop FLUKA simulations
    echo " gently stopping all running jobs of study ${caseDir} ..."
    if [ ! -d ${caseDir} ] ; then
        echo " ...study folder ${caseDir} does not exists! is it spelled correctly?"
        exit 1
    fi
    # touch rfluka.stop in all the fluka_* folders
    cd ${caseDir}
    for ((iSeed=${seedMin}; iSeed<=${seedMax}; iSeed++ )) ; do
        dirNum=`printf "run_%05i" "${iSeed}"`
        flukaFolders=`\ls -1d ${dirNum}/fluka*/`
        if [[ "${flukaFolders}" == "" ]] ; then
            echo " ...no FLUKA runs to stop for seed ${iSeed}!"
        else
            flukaFolders=( ${flukaFolders} )
            if [ ${#flukaFolders[@]} -gt 1 ] ; then
                echo " ...stopping ${#flukaFolders[@]} (possible) runs!"
            fi
            for flukaFolder in ${flukaFolders[@]} ; do
                echo " ...stopping run in folder ${flukaFolder} ..."
                touch ${flukaFolder}/rfluka.stop
            done
        fi
    done
    cd - > /dev/null 2>&1
fi

if ${lClean} ; then
    echo " cleaning folder ${caseDir} ..."
    echo " ...removing binary files in run folders..."
    find ${caseDir} -name "${inputFile%.inp}???_fort.??" -print -delete
    echo " ...gzipping FLKA .out/.err/.log"
    for tmpExt in out err log ; do
        find ${caseDir} -name "${inputFile%.inp}???.${tmpExt}" -print -exec gzip {} \;
    done
fi
