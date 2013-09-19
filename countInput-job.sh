# run countInput map-reduce job
ID="rel292"
HOME="/home/${ID}"
USER="/user/${ID}"
SRC="${HOME}/re"
BASE="countInput"
MAPPER="${SRC}/${BASE}-map.lua"
REDUCER="${SRC}/${BASE}-reduce.lua"
OUTPUT="${USER}/${BASE}-output"
# delete output from previous run
#hfs -rmr ${OUTPUT}
hadoop fs -rmr ${OUTPUT}
# create output
hadoop fs -rmr ${OUTPUT}
#stream \
hadoop jar /usr/lib/hadoop/contrib/streaming/hadoop-streaming-1.0.3.16.jar \
 -file ${MAPPER} -mapper ${MAPPER} \
 -file ${REDUCER} -reducer ${REDUCER} \
 -input ${USER}/parcels-HEATING.CODE-known-val.pairs \
 -output ${OUTPUT}

