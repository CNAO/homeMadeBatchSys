#!/bin/bash

caseDir=""
inputFile=""
jobFile=job_FLUKA.sh
nPrims=""
myUnStats=1E6
origDir=.
scorings="RESNUCLE,USRBIN,USRBDX,USRTRACK,USRYIELD"
seedMin=0
seedMax=9
wherePST="run_%05i"
whereGM="run_?????"
# what to do
lPrepare=false
lExpand=false
lSubmit=false
lGrepStats=false
lStop=false
lMerge=false
lClean=false
# batch systems:
# - NONE: run to CPU directly
# - HMBS: Home Made Batch System (by amereghe, available on github)
# - HTC: HTCondor
batchSys=HMBS
# - home-made batch system
spoolingPath=`dirname $0`/queueing
# - HTCondor
condorSubFile="condor.sub"
# log file
logFile=.`basename $0`.log
# script version
scriptVer="1.1"

currDir=$PWD
# use "." as floating-point separator
export LC_NUMERIC="en_US.UTF-8"

# log terminal line command
echo "`date +"[%Y-%m-%d %H:%M:%S]"` ==> ver ${scriptVer} <== $0 $*" >> ${logFile}

# ==============================================================================
# FUNCTIONs
# ==============================================================================

die() {
  echo >&2 "$1"
  exit $E_BADARGS
}

how_to_use() {
       script_name=`basename $0`
cat <<EOF

       ${script_name} [actions] [options]

                   ==> Version number ${scriptVer} <==

       Script for performing repetitive operations on parallel jobs, i.e.
         identical simulations different ony by the starting seed.
       For the time being, only for FLUKA simulations.
       Multiple parallel jobs of a single case or group of jobs (cycles) 
         are handled: the study case is located in a dedicated folder
         and each parallel job is contained in a dedicated subfolder 
         (with its own I/O files), e.g.:
            ./C_Cu/
              |_ run_00001/
              |_ run_00002/
              |_ run_00003/
       The script should be called for acting on a single study case at
         a time, no matter the action; the call should be done from the parent
         folder.

       
       actions:
       -C  clean:     to remove <inputFile>*fort.* files and gzip all
       	   	        <inputFile>*.out/.err/.log
                      available options:
                      -c <caseDir>   (mandatory)
		      -i <inputFile> (mandatory)

        example: /mnt/DATA/homeMadeBatchSys/${script_name} -C -c P_W -i XPRcolli.inp

       -E  expand:    to prepare further run clones in the specified study folder;
                      the folder must have been already created by a previous -P
                        action (see -P action);
                      available options:
                      -c <caseDir>   (mandatory)
		      -i <inputFile> (mandatory)
		      -j <jobFile>   (optional)
		      -m <seedMin>   (optional)
		      -n <seedMax>   (optional)
		      -o <origDir>   (optional)
		      -p <nPrims>    (mandatory)

       -G  grep stat: to grep statistics on the jobs already over.
                      available options:
                      -c <caseDir>   (mandatory)
                      -u <myUnStats> (optional)
                      -w <where>     (optional)

       -H  help:      to print this help
                      available also as -h

        example: /mnt/DATA/homeMadeBatchSys/${script_name} -H

       -M  merge:     to merge results saved in binary files.
                      available options:
                      -c <caseDir>   (mandatory)
		      -i <inputFile> (mandatory)
                      -s <scorings>  (optional)
                      -w <where>     (optional)

       -P  prepare:   to set up study folder, i.e. it creates the study folder,
                        with a ``master copy'' of the <inputFile> and <jobFile>,
                        and all the run_????? directories, each different from
                        the others by the seed.
                      to add statistics to an existing study case, please see the
                        -E action;
                      available options:
                      -b <batchSys>  (optional)
                      -c <caseDir>   (mandatory)
		      -i <inputFile> (mandatory)
		      -j <jobFile>   (optional)
		      -m <seedMin>   (optional)
		      -n <seedMax>   (optional)
		      -o <origDir>   (optional)
		      -p <nPrims>    (mandatory)

       -S  submit:    to submit jobs;
                      available options:
                      -b <batchSys>  (optional)
                      -c <caseDir>   (mandatory)
		      -j <jobFile>   (optional)
		      -m <seedMin>   (optional)
		      -n <seedMax>   (optional)
                      -w <where>     (optional)

       -T  stop:      to gently stop jobs currently running, i.e. giving the
                        possibility to collect results, by touching rfluka.stop
                        in the fluka_* folders;
                      available options:
                      -c <caseDir>   (mandatory)
		      -m <seedMin>   (optional)
		      -n <seedMax>   (optional)


       options:

       -b <batchSys>  batch system to be used for crunching jobs
       	  	      --> default: ${batchSys};

       -c <caseDir>   sub-folder containing the study case
       	  	      --> NO defaults!

       -i <inputFile> FLUKA .inp file (with extenstion)
       	  	      --> NO defaults!

       -j <jobFile>   file describing the job to be run
       	  	      --> default: ${jobFile};

       -m <seedMin>
       	  	      --> default: ${seedMin};

       -n <seedMax>
       	  	      --> default: ${seedMax};

       -o <origDir>   folder where the master files are stored
       	  	      --> default: ${origDir};

       -p <nPrims>    number of primaries
       	  	      --> NO defaults!

       -s <scorings>  FLUKA scoring detectors (cards)
       	  	      --> default: ${scorings[@]};

       -u <myUnStats> when grepping statistics, the total number of primaries
                        already done is reported in these units;
                      --> default: ${myUnStats};

       -w <where>     subfolders of the study case
       	  	      --> default for actions P,S,T: ${wherePST};
                          format of subfolder names for regexp substitution
       	  	      --> default for actions G,M: ${whereGM};
                          format of subfolder names for grepping/listing
        NOTA BENE: given the different uses of this option for the actions, it 
                   is recommended to use defaults; otherwise, please consider
                   to perform a single action per script call or to merge all
                   together the options with the same use of this options.
                             
EOF
}

# ==============================================================================
# OPTIONs
# ==============================================================================

# get options
while getopts  ":b:Cc:EGHhi:j:Mm:n:o:Pp:Ss:Tu:w:" opt ; do
  case $opt in
    b)
      batchSys=$OPTARG
      ;;
    C)
      lClean=true
      ;;
    c)
      caseDir=$OPTARG
      ;;
    E)
      lExpand=true
      ;;
    G)
      lGrepStats=true
      ;;
    H)
      how_to_use
      exit
      ;;
    h)
      how_to_use
      exit
      ;;
    i)
      inputFile=$OPTARG
      ;;
    j)
      jobFile=$OPTARG
      ;;
    M)
      lMerge=true
      ;;
    m)
      seedMin=$OPTARG
      ;;
    n)
      seedMax=$OPTARG
      ;;
    o)
      origDir=$OPTARG
      ;;
    P)
      lPrepare=true
      ;;
    p)
      nPrims=$OPTARG
      ;;
    S)
      lSubmit=true
      ;;
    s)
      myScorings=$OPTARG
      if [ "${myScorings}"!="all" ] ; then scorings=${myScorings} ; fi
      ;;
    T)
      lStop=true
      ;;
    u)
      myUnStats=$OPTARG
      ;;
    w)
      wherePST=$OPTARG
      whereGM=$OPTARG
      ;;
    \?)
      die "Invalid option: -$OPTARG"
      ;;
    :)
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done
# common options
# - case dir is defined
if [ -z "${caseDir}" ] ; then die "case NOT declared!" ; fi
# check options
if ${lPrepare} ; then
    # mandatory options are there
    if [ -z "${inputFile}" ] ; then die ".inp file NOT declared!" ; fi
    if [ -z "${nPrims}" ] ; then die "number of primary particles NOT declared!" ; fi
    # mandatory options are meaningful
    if [ ! -f ${inputFile} ] ; then die ".inp file does NOT exist!" ; fi
    if [ ! -f ${jobFile} ] ; then die "job file does NOT exist!" ; fi
    if [ ! -d ${origDir} ] ; then die "folder with original files does NOT exist!" ; fi
fi
if ${lGrepStats} ; then
    if [ -z "${myUnStats}" ] ; then die "no unit for statistics!" ; fi
    if [ ! -d ${caseDir} ] ; then die "case folder does NOT exist!" ; fi
fi
if ${lSubmit} ; then
    if ! ${lPrepare} ; then
        # in case lSubmit AND lPrepare are issued at the same time, do not check
        #    existence of caseDir folder, since it will be created
        if [ ! -d ${caseDir} ] ; then die "case folder does NOT exist!" ; fi
    fi
    if [ -z "${batchSys}" ] ; then die "batch system NOT declared!" ; fi
    if [ "${batchSys}" != "NONE" ] && [ "${batchSys}" != "HMBS" ] && [ "${batchSys}" != "HTC" ] ; then
        die "batch system NOT recognised: ${batchSys}!"
    fi
fi
if ${lMerge} ; then
    # mandatory options are there
    if [ -z "${inputFile}" ] ; then die ".inp file NOT declared!" ; fi
    scorings=(${scorings//,/ })
    if [ ${#scorings[@]} -eq 0 ] ; then die "no scorings specified!" ; fi
    if [ ! -d ${caseDir} ] ; then die "case folder does NOT exist!" ; fi
fi
if ${lClean} ; then
    # mandatory options are there
    if [ -z "${inputFile}" ] ; then die ".inp file NOT declared!" ; fi
    if [ ! -d ${caseDir} ] ; then die "case folder does NOT exist!" ; fi
fi
if ${lStop} ; then
    if [ ! -d ${caseDir} ] ; then die "case folder does NOT exist!" ; fi
    if [ "${batchSys}" == "HTC" ] ; then die "Cannot gently stop simulations on HTCondor!" ; fi
fi
# common options
# - where are defined
if ${lGrepStats} || ${lMerge} ; then
    if [ -z "${whereGM}" ] ; then die "please provide a meaningful -w option!" ; fi
fi

# ==============================================================================
# DO THINGs
# ==============================================================================

if ${lPrepare} ; then
    echo ""
    # prepare study dir
    echo " preparing jobs of study ${caseDir} for batch system ${batchSys} ..."
    if [ -d ${caseDir} ] ; then
        echo " ...study folder ${caseDir} already exists! updating files..."
    else
        mkdir ${caseDir}
    fi
    # copy files
    cd ${origDir}
    cp ${inputFile} ${jobFile} ${currDir}/${caseDir}
    # update number of primaries
    sed -i "s/^START.*/START     `printf "%10.1f" "${nPrims}"`/g" ${currDir}/${caseDir}/${inputFile}
    if [ "${batchSys}" == "HTC" ] ; then
        cp ${condorSubFile} ${caseDir}
        sed -i "s/^executable.*/executable = ${jobFile}/g" ${condorSubFile}
    fi
    cd - > /dev/null 2>&1
fi

if ${lPrepare} || ${lExpand} ; then
    let nJobs=${seedMax}-${seedMin}+1
    echo " creating ${nJobs} job(s) for study ${caseDir} ..."
    # final steps of preparation (a folder per seed)
    cd ${caseDir}
    if [ "${batchSys}" == "HTC" ] ; then
        [ ! -f  HTCjobList.txt ] || rm HTCjobList.txt
    fi
    for ((iSeed=${seedMin}; iSeed<=${seedMax}; iSeed++ )) ; do 
        echo " ...preparing seed ${iSeed}..."
        dirNum=`printf "${wherePST}" "${iSeed}"`
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
        if [ "${batchSys}" == "HMBS" ] ; then
            currJobFile=job_${caseDir}_${dirNum}_`date "+%Y-%m-%d_%H-%M-%S"`.sh
            cat > ${dirNum}/${currJobFile} <<EOF
#!/bin/bash
cd ${PWD}/${caseDir}/${dirNum}
./${jobFile} > ${jobFile}.log 2>&1
EOF
            chmod +x ${dirNum}/${currJobFile}
        elif [ "${batchSys}" == "HTC" ] ; then
            echo ${dirNum} >> HTCjobList.txt
            rm ${dirNum}/${condorSubFile}
        fi
    done
    if [ "${batchSys}" == "HTC" ] ; then
        sed -i "s/^JobBatchName.*/JobBatchName = \"${caseDir}\"/g" ${condorSubFile}
    fi
    cd - > /dev/null 2>&1
fi

if ${lSubmit} ; then
    echo ""
    echo " submitting jobs of study ${caseDir} ..."
    if [ "${batchSys}" == "HTC" ] ; then
        echo " ...submission to HTCondor must proceed with condor_submit command run by the user!"
    else
        for ((iSeed=${seedMin}; iSeed<=${seedMax}; iSeed++ )) ; do
            echo " ...submitting seed ${iSeed}..."
            dirNum=`printf "${wherePST}" "${iSeed}"`
            if [ "${batchSys}" == "HMBS" ] ; then
                currJobFile=`ls -1tr ${caseDir}/${dirNum}/job_${caseDir}_${dirNum}_*.sh | tail -1`
                mv ${currJobFile} ${spoolingPath}
            elif [ "${batchSys}" == "NONE" ] ; then
                cd ${caseDir}/${dirNum}
                ./${jobFile} > ${jobFile}.log 2>&1 &
                cd - > /dev/null 2>&1
            fi
        done
    fi
fi

if ${lGrepStats} ; then
    echo ""
    echo " grepping statistics of jobs already over of study ${caseDir} ..."
    for ext in out out.gz ; do
        jobsDoneList=`ls -lh ${caseDir}/${whereGM}/*.${ext} 2>/dev/null`
        if [ -z "${jobsDoneList}" ] ; then
            echo " ...no files ${caseDir}/${whereGM}/*.${ext}!"
        else
            # calculations
            nJobsDone=`echo "${jobsDoneList}" | wc -l`
            stats=`zgrep -h 'Total number of primaries run' ${caseDir}/${whereGM}/*.${ext} | awk -v unit=${myUnStats}  '{tot=tot+$6}END{print (tot/unit)}'`
            CPUmeanTimes=`zgrep -h 'Average CPU time used to follow a primary particle:'  ${caseDir}/${whereGM}/*.${ext} | awk '{print ($10*1000)}'`
            meanCPUtime=`echo "${CPUmeanTimes}" | awk '{tot=tot+$1}END{print(tot/NR)}'`
            stdCPUtime=`echo "${CPUmeanTimes}" | awk -v mean=${meanCPUtime} '{tot=tot+($1-mean)^2}END{print(sqrt(tot)/NR/mean*100)}'`
            CPUmaxTimes=`zgrep -h 'Maximum CPU time used to follow a primary particle:'  ${caseDir}/${whereGM}/*.${ext} | awk '{print ($10*1000)}' | sort -g`
            shortestOnes=`echo "${CPUmaxTimes}" | head -5`
            longestOnes=`echo "${CPUmaxTimes}" | tail -5`
            # printout
            # echo " ...list of jobs already over:"
            # echo "${jobsDoneList}"
            echo " ...found ${nJobsDone} ${caseDir}/${whereGM}/*.${ext} (jobs done)!"
            echo " ...primaries run so far: ${stats}x${myUnStats}"
            echo " ...mean CPU time [ms]: ${meanCPUtime} +/- ${stdCPUtime} %"
            echo " ...max CPU times [ms] (5 shortest):" ${shortestOnes}
            echo " ...max CPU times [ms] (5 longest):" ${longestOnes}
        fi
    done
    echo ""
    echo " grepping statistics of jobs still running for study ${caseDir} ..."
    jobRunList=`ls -1 ${caseDir}/${whereGM}/fluka_*/*.out 2>/dev/null`
    if [ -z "${jobRunList}" ] ; then
        echo " ...no files ${caseDir}/${whereGM}/fluka_*/*.out!"
    else
        # calculations
        nJobsRun=`echo "${jobRunList}" | wc -l`
        stats=`tail -n2 ${caseDir}/${whereGM}/fluka_*/*.out | grep 1.0000000E+30 | awk -v unit=${myUnStats}  '{tot=tot+$1}END{print (tot/unit)}'`
        CPUmeanTimes=`tail -n2 ${caseDir}/${whereGM}/fluka_*/*.out | grep 1.0000000E+30 | awk '{print ($4*1000)}'`
        meanCPUtime=`echo "${CPUmeanTimes}" | awk '{tot=tot+$1}END{print(tot/NR)}'`
        stdCPUtime=`echo "${CPUmeanTimes}" | awk -v mean=${meanCPUtime} '{tot=tot+($1-mean)^2}END{print(sqrt(tot)/NR/mean*100)}'`
        shortestOnes=`echo "${CPUmeanTimes}" | head -5`
        longestOnes=`echo "${CPUmeanTimes}" | tail -5`
        # printout
        # echo " ...list of jobs still running:"
        # echo "${jobRunList}"
        echo " ...found ${nJobsRun} ${caseDir}/${whereGM}/fluka_*/*.out (jobs still running)!"
        for myFile in ${jobRunList} ; do
            myTStamp=`ls -l ${myFile} | awk '{print ($6,$7,$8)}'`
            myStats=`tail -n2 ${myFile} | grep 1.0000000E+30 | awk -v unit=${myUnStats}  '{print ($1/unit)}'`
            myCPUtime=`tail -n2 ${myFile} | grep 1.0000000E+30 | awk '{print ($4*1000)}'`
            echo " ...file ${myFile} - time stamp: ${myTStamp} - stats: ${myStats}x${myUnStats} - mean CPU time: ${myCPUtime} ms"
        done
        echo " ...primaries run so far: ${stats}x${myUnStats}"
        echo " ...mean CPU time [ms]: ${meanCPUtime} +/- ${stdCPUtime} %"
        echo " ...max CPU times [ms] (5 shortest):" ${shortestOnes}
        echo " ...max CPU times [ms] (5 longest):" ${longestOnes}
    fi
fi

if ${lStop} ; then
    echo ""
    # gently stop FLUKA simulations
    echo " gently stopping all running jobs of study ${caseDir} ..."
    if [ ! -d ${caseDir} ] ; then
        echo " ...study folder ${caseDir} does not exists! is it spelled correctly?"
        exit 1
    fi
    # touch rfluka.stop in all the fluka_* folders
    cd ${caseDir}
    for ((iSeed=${seedMin}; iSeed<=${seedMax}; iSeed++ )) ; do
        dirNum=`printf "${wherePST}" "${iSeed}"`
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

if ${lMerge} ; then
    echo ""
    echo " merging binary result files of study ${caseDir} ..."
    cd ${caseDir}
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
        echo "checking presence of ${myScor} cards in ${inputFile} file..."
        units=`grep ${myScor} ${inputFile} | grep -v -e DCYSCORE -e AUXSCORE | awk -v myCol=${myCol} '{un=-\$myCol; if (20<un && un<100) {print (un)}}' | sort -g | uniq`
        if [[ "${units}" == "" ]] ; then
            echo "...no cards found!"
            continue
        else
            units=( ${units} )
            echo "...found ${#units[@]} ${myScor} cards: processing..."
            for myUnit in ${units[@]} ; do
                echo " merging ${myScor} on unit ${myUnit} ..."
                ls -1 ${whereGM}/*${myUnit} > ${myUnit}.txt
                if [ `wc -l ${myUnit}.txt | awk '{print ($1)}'` -eq 0 ] ; then
                    echo "...no ${whereGM}/*${myUnit} files found! No processing..."
                else
                    echo "" >> ${myUnit}.txt
                    echo "${inputFile%.inp}_${myUnit}.${extension}" >> ${myUnit}.txt
                    ${FLUKA}/flutil/${exeMerge} < ${myUnit}.txt > ${myUnit}.log 2>&1
                fi
                rm ${myUnit}.*            
            done
        fi
    done
    cd - > /dev/null 2>&1
fi

if ${lClean} ; then
    echo ""
    echo " cleaning folder ${caseDir} ..."
    sizeBefore=`du -sh ${caseDir} | awk '{print ($1)}'`
    echo " ...removing fluka_* folders (crashed jobs)..."
    find ${caseDir} -name "fluka_*" -type d -print -exec rm -rf {} \;
    echo " ...removing binary files in run folders..."
    find ${caseDir} -name "${inputFile%.inp}???_fort.??" -print -delete
    echo " ...gzipping FLKA .out/.err/.log"
    for tmpExt in out err log ; do
        find ${caseDir} -name "${inputFile%.inp}???.${tmpExt}" -print -exec gzip {} \;
    done
    echo " ...removing ran* files in run folders..."
    find ${caseDir} -name "ran${inputFile%.inp}???" -print -delete
    sizeAfter=`du -sh ${caseDir} | awk '{print ($1)}'`
    echo "size BEFORE cleaning: ${sizeBefore}"
    echo "size AFTER  cleaning: ${sizeAfter}"
fi

echo ""
echo "...done."
echo ""
