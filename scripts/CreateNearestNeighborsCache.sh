# CreateNearestNeighborsCache.sh
# example:
#  cd scripts
#  CreateNearestNeighbors --dataDir=../data/ --obs=2R --action=1
#  CreateNearestNeighbors --dataDir=../data/ --obs=2R --action=2
#  ...
#  CreateNearestNeighbors --dataDir=../data/ --obs=2R --action=merge



HEAPSIZE=6G
CLASSPATH=../src.git/java/bin
EXECUTABLE=com.roylowrance.thesis.CreateNearestNeighborsCache

# pass all command line arguments to executable
java -Xms$HEAPSIZE -cp $CLASSPATH $EXECUTABLE $*
