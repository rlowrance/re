# CreateEstimates-piece.sh N
# create piece N of 100 pieces
# usage
#  ssh compute server
#  cd .../scripts/
#  CreateEstimates-piece.sh N

./CreateEstimates.sh --algo=knn --dataDir=../../data/ --k=24 --obs=1A --pieces=100 --action=$1
