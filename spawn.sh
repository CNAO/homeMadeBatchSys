#!/bin/bash

caseDir=BP164mm_parallel_0p000_0p000
origDir=FLUKA_repo
inputFile=treat_line_exp.inp
jobFile=job.sh
analScript=analysis.sh
nPrims=200000
seedMin=1
seedMax=5
# what to do
lPrepare=false
lSubmit=false
lAnalise=true
lClean=false
# hand-made queueing system
lQueue=true
spoolingPath=/home/amereghe/homeMadeBatchSys/queueing

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
    cp ${inputFile} ${jobFile} ${analScript} ${currDir}/${caseDir}
    cd - > /dev/null 2>&1
    cd ${caseDir}
    # final steps of preparation (a folder per seed)
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
            currJobFile=AMQ_`date "+%Y-%m-%d_%H-%M-%S"`_${caseDir}_${dirNum}.sh
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

if ${lAnalise} ; then
    echo " analysing ${caseDir}..."
    if [ -d ${caseDir}/analysis ] ; then
        echo " folder ${caseDir}/analysis already exists! recreating it..."
        rm -rf ${caseDir}/analysis
    fi
    mkdir -p ${caseDir}/analysis
    [ -e ${caseDir}/analysis/${analScript} ] || mv ${caseDir}/${analScript} ${caseDir}/analysis
    cd ${caseDir}/analysis
    ./${analScript}  2>&1 | tee -a analysis.log
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
