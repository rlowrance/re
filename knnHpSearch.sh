# knnHpSearch.sh
# run knnHpSearch for several k values
# write results to analysis directory
# Usage:
#   cd FEATURES
#   ../../../../src.git/knnHpSearch.sh 1 10 20 30 40 50 60

for x in $@
do
  ../../../../build-linux-64/knnHpSearch --obs 1A --k $x > ../analysis/knnHpSearch-k$x.txt
done
