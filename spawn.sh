#!/bin/bash

caseDir=""
origDir=.
inputFile=""
jobFile=job_FLUKA.sh
nPrims=""
seedMin=1
seedMax=10
# what to do
lPrepare=false
lSubmit=false
lClean=false
# hand-made queueing system
lQueue=true
spoolingPath=/mnt/DATA/homeMadeBatchSys/queueing
# log file
logFile=.`basename $0`.log

currDir=$PWD
# use "." as floating-point separator
export LC_NUMERIC="en_US.UTF-8"

# log terminal line command
echo "`date +"[%Y-%m-%d %H:%M:%S]"` $0 $*" >> ${logFile}

# =================================================================================
# FUNCTIONs
# =================================================================================

die() {
  echo >&2 "$1"
  exit $E_BADARGS
}

how_to_use() {
       script_name=`basename $0`
cat <<EOF
       ${script_name} [actions] [options]
       Script for performing repetitive operations on parallel jobs.
       For the time being, only for FLUKA simulations.
       Multiple parallel jobs of a single case or group of jobs (cycles) 
       can be handled: the single case is located in a dedicated folder, 
       and each parallel job is contained in a dedicated subfolder 
       (with its own I/O files), e.g.:
            ./scraper/
              |_ run_0001/
              |_ run_0002/
              |_ run_0003/
       
       actions:
       -C  clean
       -P  prepare (set up folders)
       -S  submit jobs

       options:

       -c <caseDir>        sub-folder containing the study case
       	  		   --> NO defaults!

       -h                  print this help

       -i <inputFile>      FLUKA .inp file (with extenstion)
       	  		   --> NO defaults!

       -j <job_file>       file describing the job to be run
       	  		   --> default: ${jobFile};

       -m <min_seed>
       	  		   --> default: ${seedMin};

       -n <max_seed>
       	  		   --> default: ${seedMax};

       -o <orig_folder>    folder where the master files are stored
       	  		   --> NO defaults!

       -p <nPrims>         number of primaries
       	  		   --> NO defaults!

EOF
}

# =================================================================================
# OPTIONs
# =================================================================================

# get options
while getopts  ":Cc:hi:j:m:n:o:Pp:S" opt ; do
  case $opt in
    C)
      lClean=true
      ;;
    c)
      caseDir=$OPTARG
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
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
# check options
if ${lPrepare} ; then
    # mandatory options are there
    if [ -z "${caseDir}" ] ; then die "case NOT declared!" ; fi
    if [ -z "${inputFile}" ] ; then die ".inp file NOT declared!" ; fi
    if [ -z "${nPrims}" ] ; then die "number of primary particles NOT declared!" ; fi
    if [ -z "${origDir}" ] ; then die "folder with original files NOT declared!" ; fi
    # mandatory options are meaningful
    if [ ! -f ${inputFile} ] ; then die ".inp file does NOT exist!" ; fi
    if [ ! -f ${jobFile} ] ; then die "job file does NOT exist!" ; fi
    if [ ! -d ${origDir} ] ; then die "folder with original files does NOT exist!" ; fi
fi
if ${lSubmit} ; then
    # mandatory options are there
    if [ -z "${caseDir}" ] ; then die "case NOT declared!" ; fi
    # mandatory options are meaningful
    if [ ! -d ${caseDir} ] ; then die "folder with original files does NOT exist!" ; fi
fi
if ${lClean} ; then
    # mandatory options are there
    if [ -z "${caseDir}" ] ; then die "case NOT declared!" ; fi
    if [ -z "${inputFile}" ] ; then die ".inp file NOT declared!" ; fi
    # mandatory options are meaningful
    if [ ! -d ${caseDir} ] ; then die "folder with original files does NOT exist!" ; fi
fi


# =================================================================================
# DO THINGs
# =================================================================================

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

if ${lClean} ; then
    echo " cleaning folder ${caseDir} ..."
    echo " ...removing binary files in run folders..."
    find ${caseDir} -name "${inputFile%.inp}???_fort.??" -print -delete
    echo " ...gzipping FLKA .out/.err/.log"
    for tmpExt in out err log ; do
        find ${caseDir} -name "${inputFile%.inp}???.${tmpExt}" -print -exec gzip {} \;
    done
fi
