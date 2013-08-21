# hptest-1a-cat.sh
# concatenate hptest result files into one big file that is sorted
# input files: search-knn-1A-20000101-20091231-*.txt
# output file: search-knn-1A-20000101-20091231-merged.txt

# example
#  cd scripts
#  ./hptest-1a-cat.sh

BASE=search-knn-1A-20000101-20091231
MERGED=${BASE}-merged.txt

cd ../data/generated-v4/obs1A/analysis/
cat ${BASE}-*.txt > ${MERGED}
sort --numeric-sort --output=${MERGED} ${MERGED}
cat ${MERGED}

