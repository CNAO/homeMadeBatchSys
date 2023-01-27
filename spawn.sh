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
lStop=false
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
       -C  clean:   to remove <inputFile>*fort.* files and gzip all
       	   	      <inputFile>*.out/.err/.log
                    available options:
                    -c <caseDir>   (mandatory)
		    -i <inputFile> (mandatory)

		    example: /mnt/DATA/homeMadeBatchSys/spawn.sh -C -c P_W -i XPRcolli.inp

       -H  help:    to print this help

       	   	    example: /mnt/DATA/homeMadeBatchSys/spawn.sh -H

       -P  prepare: to set up study folder, i.e. it creates the study folder,
                      with a ``master copy'' of the <inputFile> and <jobFile>,
                      and all the run_????? directories, each different from the
                      others by the seed.
                    this action can be used also to add statistics to an
                      existing study case;
                    available options:
                    -c <caseDir>   (mandatory)
		    -i <inputFile> (mandatory)
		    -j <jobFile>   (optional)
		    -m <seedMin>   (optional)
		    -n <seedMax>   (optional)
		    -o <origDir>   (optional)
		    -p <nPrims>    (mandatory)

       -S  submit:  to submit jobs;
                    available options:
                    -c <caseDir>   (mandatory)
		    -m <seedMin>   (optional)
		    -n <seedMax>   (optional)

       -T  stop:    to gently stop jobs currently running, i.e. giving the
                      possibility to collect results, by touching rfluka.stop
                      in the fluka_* folders;
                    available options:
                    -c <caseDir>   (mandatory)
		    -m <seedMin>   (optional)
		    -n <seedMax>   (optional)


       options:

       -c <caseDir>        sub-folder containing the study case
       	  		   --> NO defaults!

       -i <inputFile>      FLUKA .inp file (with extenstion)
       	  		   --> NO defaults!

       -j <jobFile>        file describing the job to be run
       	  		   --> default: ${jobFile};

       -m <seedMin>
       	  		   --> default: ${seedMin};

       -n <seedMax>
       	  		   --> default: ${seedMax};

       -o <origDir>        folder where the master files are stored
       	  		   --> NO defaults!

       -p <nPrims>         number of primaries
       	  		   --> NO defaults!

EOF
}

# ==============================================================================
# OPTIONs
# ==============================================================================

# get options
while getopts  ":Cc:Hi:j:m:n:o:Pp:ST" opt ; do
  case $opt in
    C)
      lClean=true
      ;;
    c)
      caseDir=$OPTARG
      ;;
    H)
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
    T)
      lStop=true
      ;;
    \?)
      die "Invalid option: -$OPTARG"
      ;;
    :)
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done
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
# if ${lSubmit} ; then
# fi
if ${lClean} ; then
    # mandatory options are there
    if [ -z "${inputFile}" ] ; then die ".inp file NOT declared!" ; fi
fi
# if ${lStop} ; then
# fi
# common options
# - they are there
if [ -z "${caseDir}" ] ; then die "case NOT declared!" ; fi
# - they are meaningful
if [ ! -d ${caseDir} ] ; then die "folder with original files does NOT exist!" ; fi

# ==============================================================================
# DO THINGs
# ==============================================================================

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
    echo " ...removing ran* files in run folders..."
    find ${caseDir} -name "ran${inputFile%.inp}???" -print -delete
fi
