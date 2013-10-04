#!/bin/sh

source  $MODULESHOME/init/sh
module purge
module load  hadoop/1.2.1

# run countInput map-reduce job
ID="rel292"
HOME="/home/${ID}"
USER="/user/${ID}"
SRC="${HOME}/re"
BASE="countInput"
MAPPER="${SRC}/${BASE}-map.lua"
REDUCER="${SRC}/${BASE}-reduce.lua"
INPUT="parcels-HEATING.CODE-known-val.pairs"
OUTPUT="${INPUT}.${BASE}.output"

#MAPPER=/tmp/zzz/countInput-map.lua
#REDUCER=/tmp/zzz/countInput-reduce.lua

# delete output from previous run
#hfs -rmr ${OUTPUT}
hadoop fs -rmr ${OUTPUT}
# create output
hadoop fs -rmr ${OUTPUT}
#stream \
hadoop jar /share/apps/hadoop/1.2.1/contrib/streaming/hadoop-streaming-1.2.1.jar \
    -input ${INPUT} \
    -output ${OUTPUT} \
    -mapper ${MAPPER} \
    -reducer ${REDUCER} \
    -file ${MAPPER} \
    -file ${REDUCER}


