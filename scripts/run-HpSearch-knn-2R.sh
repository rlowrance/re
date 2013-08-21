# Run HpSearch --algo=knnExact --obs=2R --kGrid=GKRID
# Create files <project>/data/generated-v4/obs2R/analysis/HpSearch-knn-2R.*
KGRID=[10]

HOME=/home/roy/
PROJECT=${HOME}Dropbox/nyu-thesis-project/

#SRC=${HOME}eclipse-workspace/thesis3/src/
WORKSPACE=${HOME}Dropbox/eclipse-workspace/

# establish classpath
THESIS_BIN=${WORKSPACE}thesis3/bin/
UTIL_BIN=${WORKSPACE}util/bin/
EBLEARN_BIN=${WORKSPACE}eblearn/bin/
CLASSPATH=${THESIS_BIN}:${UTIL_BIN}:${EBLEARN_BIN}

THESIS_PACKAGE=com.roylowrance.thesis.

echo CLASSPATH=${CLASSPATH}
echo THESIS_PACKAGE=${THESIS_PACKAGE}

java -cp ${CLASSPATH} \
     ${THESIS_PACKAGE}HpSearch \
     --algo=knnExact --obs=2R --kGrid=${KGRID}