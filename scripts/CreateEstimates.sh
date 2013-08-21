# run CreateEstimates
# example:
#  cd scripts
#  ./CreateEstimate.sh PARM1 ...

CLASSPATH=../java/bin
EXECUTABLE=com.roylowrance.thesis.CreateEstimates
# GC overhead limit exceeded for heap size 2G, 3G, 4G when using cache
# test done in new version that does not use cache
# 2G
HEAPSIZE=1G

echo CLASSPATH  $CLASSPATH
echo EXECUTABLE $EXECUTABLE
echo HEAPSIZE   $HEAPSIZE

java -Xms$HEAPSIZE -Xmx$HEAPSIZE -cp $CLASSPATH $EXECUTABLE $@