# knnCacheMergeShards.sh
# merge 100 shards into 1 big file knnCache.txt
# usage:
#  cd features
#  ../../../../src.git/knnCacheMergeShards.sh

cat shard-1.txt shard-2.txt shard-3.txt shard-4.txt shard-5.txt shard-6.txt shard-7.txt shard-8.txt shard-9.txt shard-10.txt \
 shard-11.txt shard-12.txt shard-13.txt shard-14.txt shard-15.txt shard-16.txt shard-17.txt shard-18.txt shard-19.txt shard-20.txt \
 shard-21.txt shard-22.txt shard-23.txt shard-24.txt shard-25.txt shard-26.txt shard-27.txt shard-28.txt shard-29.txt shard-30.txt \
 shard-31.txt shard-32.txt shard-33.txt shard-34.txt shard-35.txt shard-36.txt shard-37.txt shard-38.txt shard-39.txt shard-40.txt \
 shard-41.txt shard-42.txt shard-43.txt shard-44.txt shard-45.txt shard-46.txt shard-47.txt shard-48.txt shard-49.txt shard-50.txt \
 shard-51.txt shard-52.txt shard-53.txt shard-54.txt shard-55.txt shard-56.txt shard-57.txt shard-58.txt shard-59.txt shard-60.txt \
 shard-61.txt shard-62.txt shard-63.txt shard-64.txt shard-65.txt shard-66.txt shard-67.txt shard-68.txt shard-69.txt shard-70.txt \
 shard-71.txt shard-72.txt shard-73.txt shard-74.txt shard-75.txt shard-76.txt shard-77.txt shard-78.txt shard-79.txt shard-80.txt \
 shard-81.txt shard-82.txt shard-83.txt shard-84.txt shard-85.txt shard-86.txt shard-87.txt shard-88.txt shard-89.txt shard-90.txt \
 shard-91.txt shard-92.txt shard-93.txt shard-94.txt shard-95.txt shard-96.txt shard-97.txt shard-98.txt shard-99.txt shard-100.txt \
 > knnCache.txt

