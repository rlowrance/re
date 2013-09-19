# run map-reduce job using the Hadoop streaming interface
# ARGS
#  $1 : path to input file in the Hadoop file system
#  $2 : string, name of the map-reduce job
#       the mapper is  ./JOB_NAME-map.lua
#       the reducer is ./JOB_NAME-reduce.lua
#  $3 : string, user ID for the hpc logon
#       $UID on Babar is not the same as your original user Id when
#       you did ssh USER_ID@hpy.nyu.edu
# USAGE
# 1. Change to the directory where the commands are.
# 2. Execute ./map-reduce.sh path/to/input job-name
#
# Notes:
# - The output directory is $1.$2-ouput: the concatenation of the 
#   path to the input file, a dot, the name of the job, and "-output". This
#   convention is intended to make the output directory name unique.
# - The content of the output directory is copied to the local file system
#   as directory $HOME/map-reduce-output/<output directory name>. The 
#   idea is to avoid writing to the directory containing the commands, 
#   as that is likely to be a source code directory.
#
# Copyright Roy E Lowrance 2013
# The license is the GNU GPL Version 3.0

# terminate after first line that fails
set -e

# simulate args passed on command line
INPUT_FILE=$1
JOB_NAME=$2
HPC_USER_ID=$3
echo input file = $1
echo job name = $2
echo hpc user id = $3

# build other variables
USER="/user/${HPC_USER_ID}"
MAPPER=$PWD/${JOB_NAME}-map.lua
REDUCER=$PWD/${JOB_NAME}-reduce.lua
echo user=$USER
echo mapper=$MAPPER
echo reducer=$REDUCER


# input and output
INPUT_PATH=$USER/$INPUT_FILE
OUTPUT_DIR=$INPUT_FILE.$JOB_NAME
LOCAL_OUTPUT_DIR=$HOME/map-reduce-output/$OUTPUT_DIR

# system default streaming jar
HADOOP_HOME=/usr/lib/hadoop
STREAMING="hadoop-streaming-1.0.3.16.jar"

# delete output from previous run
# NOTE: these command must be commented out when the script is first run, as
# the delete command fails if the directory does not exist
# and the mkdir fails if the directory already exists
echo deleting $OUTPUT_DIR
hadoop fs -rmr ${OUTPUT_DIR}

# create output directory
#echo creating output directory $OUTPUT_DIR
#hadoop fs -mkdir ${OUTPUT_DIR}

# create output directory using streaming interface
echo creating output dirctory using streaming interface
echo mapper=$MAPPER
echo reducer=$REDUCER
echo input path=$INPUT_PATH
echo output dir=${OUTPUT_DIR}
hadoop jar $HADOOP_HOME/contrib/streaming/$STREAMING \
 -file ${MAPPER} -mapper ${MAPPER} \
 -file ${REDUCER} -reducer ${REDUCER} \
 -input ${INPUT_PATH} \
 -output ${OUTPUT_DIR}

# copy output file to home directory
FROM=$USER/$OUTPUT_DIR
TO=$HOME/map-reduce-output/$OUTPUT_DIR
echo copy from $FROM to $TO
mkdir -p $TO
hadoop fs -copyToLocal $FROM $TO

