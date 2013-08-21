# Export CLASSPATH

# Run from src directory


HOME=/home/roy/
PROJECT=${HOME}Dropbox/nyu-thesis-project/
WORKSPACE=${HOME}Dropbox/eclipse-workspace/

# establish classpath
THESIS_BIN=${WORKSPACE}thesis3/bin/
UTIL_BIN=${WORKSPACE}util/bin/
EBLEARN_BIN=${WORKSPACE}eblearn/bin/

CLASSPATH=${THESIS_BIN}:${UTIL_BIN}:${EBLEARN_BIN}

echo CLASSPATH=${CLASSPATH}

export CLASSPATH
