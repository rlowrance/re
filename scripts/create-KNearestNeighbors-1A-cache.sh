# Create the cache pieces for KNearestNeighbors obs 1A

# To create piece N, run:
# create-KNearestNeighbors-1A-cache --action=N

# To merge the pieces, run:
# create-KNearestNeighbors-1A-cache --action=merge


# Create files 
# <project>/data/generated-v4/obs1A/caches/SHA.KNearestNeighbors-piece-N

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

java -cp ${CLASSPATH} ${PGM} --obs=1A $1

