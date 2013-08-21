# Create the cache files for KNearestNeighbors obs 1A

# Create files 
# <project>/data/generated-v4/obs1A/caches/SHA.KNearestNeighbors-piece-N
# <project>/data/generated-v4/obs1A/caches/SHA.KNearestNeighbors-merged

HOME=/home/roy/
PROJECT=${HOME}Dropbox/nyu-thesis-project/
WORKSPACE=${HOME}Dropbox/eclipse-workspace/

# establish classpath
THESIS_BIN=${WORKSPACE}thesis3/bin/
UTIL_BIN=${WORKSPACE}util/bin/
EBLEARN_BIN=${WORKSPACE}eblearn/bin/

CLASSPATH=${THESIS_BIN}:${UTIL_BIN}:${EBLEARN_BIN}

# name of package
THESIS_PACKAGE=com.roylowrance.thesis

echo CLASSPATH=${CLASSPATH}
echo THESIS_PACKAGE=${THESIS_PACKAGE}

PGM=${THESIS_PACKAGE}.KNearestNeighbors

piece() {
 java -cp ${CLASSPATH} ${PGM} --obs=1A --action=$1
}

merge() {
 java -cp ${CLASSPATH} ${PGM} --obs=1A --action=merge
}

merge
