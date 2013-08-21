# run HpSearch with java profiling turned on
# example:
#  HpSearch $1 $2 $3 $4

CLASSPATH=../src.git/java/bin
EXECUTABLE=com.roylowrance.thesis.HpSearch

java -Xprof -cp $CLASSPATH $EXECUTABLE $@