# run HpSTest
# example:
#  cd scripts
#  HpTest.sh PARM1 ...

CLASSPATH=../src.git/java/bin
EXECUTABLE=com.roylowrance.thesis.HpTest
HEAPSIZE=3G

java -Xms$HEAPSIZE -Xmx$HEAPSIZE -cp $CLASSPATH $EXECUTABLE $@