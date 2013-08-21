# create the idx files in directory <project>/data/generated-v4/Obs2R/idxs/
HOME=/home/roy/
PROJECT=${HOME}Dropbox/nyu-thesis-project/

SRC=${PROJECT}src-repp-repo.git/src/local-weighted-regression-2/src/
WORKSPACE=${HOME}Dropbox/eclipse-workspace/

THESIS_BIN=${SRC}java/bin/
UTIL_BIN=${WORKSPACE}util/bin/
EBLEARN_BIN=${WORKSPACE}eblearn/bin/
CLASSPATH=${THESIS_BIN}:${UTIL_BIN}:${EBLEARN_BIN}

THESIS_PACKAGE=com.roylowrance.nyu.thesis.

echo CLASSPATH=${CLASSPATH}
echo THESIS_PACKAGE=${THESIS_PACKAGE}

# needs 6G of heap space
java -cp ${CLASSPATH} \
     -Xms6G \
     ${THESIS_PACKAGE}CreateIdxs \
     --obs=2R