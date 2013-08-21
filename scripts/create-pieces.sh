# Create pieces of a nearest-neighbor cache

# Example: To create piece 21 through 87 of obs 1A:
#   scripts
#   create-pieces.sh 1A 21 87

# Create files 
# <project>/data/generated-v4/obsOBS/caches/SHA.KNearestNeighbors-piece-N

for ((piece=$2; piece<=$3; piece++))
do
    ./CreateNearestNeighborsCache.sh --dataDir=../data/ --obs=$1 --action=$piece

done


