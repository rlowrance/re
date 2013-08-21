# Run program KNearestNeighbors $1 $2
# example:
#  ./KNearestNeigbhors.sh --obs=1A --action=1

# directories
HOME=/home/roy/
PROJECT=${HOME}Dropbox/nyu-thesis-project/
WORKSPACE=${HOME}Dropbox/eclipse-workspace/

# establish classpath
THESIS_BIN=${WORKSPACE}thesis3/bin/
UTIL_BIN=${WORKSPACE}util/bin/
TENSOR_BIN=${WORKSPACE}tensor/bin

CLASSPATH=${THESIS_BIN}:${UTIL_BIN}:${TENSOR_BIN}

# name of package
THESIS_PACKAGE=com.roylowrance.thesis

echo CLASSPATH=${CLASSPATH}
echo THESIS_PACKAGE=${THESIS_PACKAGE}

PGM=${THESIS_PACKAGE}.KNearestNeighbors

java -cp ${CLASSPATH} ${PGM} $1 $2

