# homeMadeBatchSys
This repo collects settings and scripts of a very simple, home-made batch system.
Nota Bene: the system is supposed to run on a linux machine!

The system is not designed for very large CPU farms; on the contrary, it is meant to simply automatically submit jobs on a multi-core/multi-thread CPU.
The system can be checked out and made running very easily.
If this system does not suite your needs, please check more popular batch systems - e.g. [htcondor](https://research.cs.wisc.edu/htcondor/)

The system is based on a crontab job, checking the status of the CPUs on a regular basis, and a simple script to find new jobs, submit them (if it is the case) and archive files of finished jobs.

```
# Example of crontab job, forcing the use of 5 CPUs/threads for crunching jobs
7,17,27,37,47,57 *  *   *   *     cd /home/amereghe/homeMadeBatchSys ; ./submit.sh 5 2>&1 >> submit.sh.log

# The same example, where the script auto-detects the number of available CPUs and allocate them but 1 for crunching jobs
7,17,27,37,47,57 *  *   *   *     cd /home/amereghe/homeMadeBatchSys ; ./submit.sh 2>&1 >> submit.sh.log
```

## How to submit
### Preparation
For every job that the user would like to submit, two files must be created:
* the ''job file'', i.e. the `bash` script describing the actual simulation. The file contains all the commands and environtment variable declarations necessary to carry out the simulation. The script can be run by the user live in the local folder (''run folder'') as a single command (e.g. for testing). The user can take inspiration from the `job_FLUKA.sh` example in the `templates` folder;
* the ''batch job file'', i.e. the actual job submitted to the queueing system. It is a short `bash` script which sets the working path to the run folder and runs the job file.

It is important that:
* every batch job file has a unique name - e.g. `job_myCase_with_this_parameter_and_that_parameter_2022-11-09.sh`;
* both the job file and the batch job file are executables -- in linux, you can make a file executable via the command `chmod`;
* the batch job file must `cd` into the run folder, such that all the files written by the simulation (with the only exception of the job log, see later) can be found there.

Having two job files may appear like a useless overhead to the preparation phase of the simulation; nevertheless, it is convenient to separate the actual simulation description from what is required by the batch system to properly run the job.

### Actual submission
In order to submit a job, it is sufficient to copy the batch job file in the `queueing` folder.
When resources will become available, the job will start: the job script will be moved to the parent folder and run by the system with the owner credentials.
All the text generated by the job script onto `STDOUT` or `STDERR` will be re-directed in the `<job_script_name>.log` file of the job.

### End of job
Once the job will be over, the job script and the `.log` will be moved to the `finished` folder.

## Repo structure
```
homeMadeBatchSys/
  |_ finished/             folder containing all finished jobs
  |_ queueing/             folder containing all queueing jobs
  |_ README.md
  |_ spawn.sh
  |_ submit.sh
  |_ templates/
      |_ job_FLUKA.sh*     template job file for FLUKA
      |_ job.sh*           generic template job file
```

