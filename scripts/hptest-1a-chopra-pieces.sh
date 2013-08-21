# hptest-1a-chopra-pieces.sh
# Test some hyper parameters k for algo knn
# Use Sumit Chopra's test period

# example to run for k = 20,21, ..., 29
#  cd scripts
#  ./hptest-1a-pieces.sh 20 21 22 23 24 25 26 27 28 29

ALGO=--algo=knn
DATADIR=--dataDir=../data/
DATE1=--testDateFirst=20041126
DATE2=--testDateLast=20041231
OBS=--obs=1A

echo $ALGO $DATADIR $DATE1 $DATE2 $OBS


for K in $@
do
  ./HpTest.sh $ALGO $DATADIR $DATE1 $DATE2 $OBS --k=$K
done