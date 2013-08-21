# knnCacheCreateShard.sh
# create a range of knn cache shards
# usage: Create shard 1, 2, ..., 20
#  cd features
#  ../../../../src.git/knnCacheCreateShard.sh 1 20

for ((x = $1; x <= $2; x += 1))
do
    ../../../../build-linux-64/knnCacheCreateShard --obs 1A --shard $x > shard-$x.txt
done

