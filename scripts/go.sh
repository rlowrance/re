# run CreateEstimate for a piece
# cd scripts
# ./go.sh PIECE_NUMBER

./CreateEstimates.sh --algo=knn --dataDir=../../data/ --k=24 --obs=1A --pieces=100 --action=$1
