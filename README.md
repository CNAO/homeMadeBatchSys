# homeMadeBatchSys
This is the repo of a very simple, home-made batch system.
It is supposed to collect very basic settings and scripts to allow for a job queueing system.
Nota Bene: the system is supposed to run on a linux machine!

The system is not supposed to scale up significantly in throughput, but it is supposed to be checked out and made running in the easiest way possible on personal computers/laptops.
If this system does not suite your needs, please check more popular batch systems - e.g. [htcondor](https://research.cs.wisc.edu/htcondor/)

The system is based on a crontab job, checking the status of the CPUs on a regular basis, and simple scripts to find new jobs, submitting them (if it is the case) and archiving files of finished jobs.

# Example of crontab job
```  7,17,27,37,47,57 *  *   *   *     cd /home/amereghe/homeMadeBatchSys ; ./submit.sh 2>&1 >> submit.sh.log
```