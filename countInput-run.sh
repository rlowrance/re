# run countInput map-reduce streaming job

# terminate after first line that fails
set -e

# set control variables
INPUT_FILE="parcels-HEATING.CODE-known-val.pairs"
JOB_NAME="countInput"
HPC_ID="rel292"

# build other variables
USER_DIR="/user/$USER"
SRC="$HOME/re"
SRC=$PWD
MAPPER="${SRC}/${JOB_NAME}-map.lua"
REDUCER="${SRC}/${JOB_NAME}-reduce.lua"

# input and output
# NOTES: $INPUT_FILE/$JOB_NAME as the output directory does not work because
# there is already a file $INPUT_FILE and there cannot be a directory with 
# the same name
INPUT_PATH=$USER_DIR/$INPUT_FILE
OUTPUT_DIR=$INPUT_FILE.$JOB_NAME
LOCAL_OUTPUT_DIR=$HOME/map-reduce-output/$OUTPUT_DIR

# system default streaming jar
HADOOP_HOME=/usr/lib/hadoop
STREAMING="hadoop-streaming-1.0.3.16.jar"

# use version 1.1.2, not default 1.0.3
# also set $HADOOP_HOME
#module load hadoop/1.1.2
#echo HADOOP_HOME=$HADOOP_HOME
#which hadoop
#STREAMING="hadoop-streaming-1.1.2.jar"

# delete output from previous run
# NOTE: these command must be commented out when the script is first run, as
# the delete command fails if the directory does not exist
# and the mkdir fails if the directory already exists
echo deleting $OUTPUT_DIR
hadoop fs -rmr $OUTPUT_DIR

# create output directory
#echo creating output directory $OUTPUT_DIR
#hadoop fs -mkdir ${OUTPUT_DIR}

# create output directory using streaming interface
echo
echo
echo creating output dirctory using streaming interface
echo mapper=$MAPPER
echo reducer=$REDUCER
echo input path=$INPUT_PATH
echo output dir=$OUTPUT_DIR
hadoop jar $HADOOP_HOME/contrib/streaming/$STREAMING \
 -file *.lua \
 -mapper $MAPPER \
 -reducer $REDUCER \
 -input $INPUT_PATH \
 -output $OUTPUT_DIR

# copy output file to home directory
FROM=$USER/$OUTPUT_DIR
FROM=$OUTPUT_DIR
TO=$HOME/map-reduce-output/$OUTPUT_DIR
echo copy output from $FROM 
echo copy output to $TO
if [ -a ~/map-reduce-output/$OUTPUT_DIR ] 
then
  # output directory exists, so delete it
  cd ~/map-reduce-output; rm -rf -- $OUTPUT_DIR # delete $TO directory
fi
mkdir -p $TO  # copyToLocal wants the directory to already exist
hadoop fs -copyToLocal $FROM $HOME/map-reduce-output/

# list output dir
echo OUTPUT DIRECTORY
ls $TO

# print main output file
echo FIRST OUTPUT FILE part-00000
cat $TO/part-00000
