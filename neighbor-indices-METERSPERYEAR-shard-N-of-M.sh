# neighbor-indices-METERSPERYEAR-shard-N-of-M.sh
# invoke
# <scriptname> METERSPERYEAR NSHARDS STARTN ENDN
# run the main program on shard STARTN, shard STARTN+1, ..., shard ENDN
metersPerYear=$1
nShards=$2
for ((shard=$3; shard <= $4; shard++))
do
 clArgs="--metersPerYear $metersPerYear --nShards $nShards --shard $shard"
 echo $clArgs
 torch neighbor-indices-METERSPERYEAR-shard-N-of-M.lua $clArgs
done
