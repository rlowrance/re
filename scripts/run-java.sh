# run a java program
# example
#  cd <project>/scripts/
#  run-java.sh KNearestNeighbors --obs=1A --action=N
#  run-java.sh KNearestNeighbors --obs=1A --action=merge

# establish the class path

CLASSPATH=../src/java/bin

# establish package

PACKAGE=com.roylowrance.thesis.

echo CLASSPATH=$CLASSPATH
echo executable=${PACKAGE}$1

# run the java program
java -cp ${CLASSPATH} ${PACKAGE}$1 $2 $3 $4 $5 $6 $7 $8 $9


