# hpsearch-1a-all.sh
# Search for hyperparameter k 
#   algo=knn
#   obs=1A

CLASSPATH=../src.git/java/bin
EXECUTABLE=com.roylowrance.thesis.HpSearch

java -cp $CLASSPATH $EXECUTABLE --dataDir=../data/ --algo=knn --obs=1A --kGrid=[1,2,4,8,12,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,64,96,128] --testDateFirst=20000101 --testDateLast=20091231


