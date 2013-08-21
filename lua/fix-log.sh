# fix-log.sh
# remove the csvWrite lines from a log file
# usage;
#  fix-log.sh inFilePath outFilePath

DATA_DIR=/home/roy/Dropbox/nyu-thesis-project/data
FEATURES_DIR=$DATA_DIR/generated-v4/obs1A/analysis
SUBJECT_DIR=$FEATURES_DIR/create-estimates,algo=knn,obs=1A,radius=$1,sample=0.01

echo $SUBJECT_DIR

torch log-remove-write-csv.lua $SUBJECT_DIR/log.txt $SUBJECT_DIR/log-truncated.txt
