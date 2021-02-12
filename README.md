# homeMadeBatchSys
This is the repo of a very simple, home-made batch system.
It is not supposed to scale up significantly in throughput; the system is supposed to be checked out and made running in the easiest way.
If you want something more serious, please check more popular batch systems - e.g. [htcondor](https://research.cs.wisc.edu/htcondor/)
It is supposed to collect very basic settings and scripts to allow for a job queueing system.
Nota Bene: the system is supposed to run on a linux machine!

The system is based on a crontab job, checking the status of the CPUs on a regular basis, and simple scripts to find new jobs, submitting them (if it is the case) and archiving files of finished jobs.
