# kill hadoop job
# usage hkill JOBNUMBER
# where
#  JOBNUMBER is the 4 digit number after the last in the Hadoop job
#  tracking URL
# EXAMPLE:
# Haoop prints
# Tracking URL: http://babar.local:50030/jobdetails.jsp?jobid=job_12345678_1234
# Then the JOBNUMBER is 1234
JOBNUMBER=$1

HADOOP=/usr/lib/hadoop/libexec/bin/hadoop
COMMAND=job
OPTIONS=-Dmapred.job.tracker=babar.local:54311
JOBPREFIX=job_201306211141_   # this will change from time to tome
$HADOOP $COMMAND $OPTIONS -kill $JOBPREVIX$JOBNUMBER

