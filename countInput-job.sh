# run countInput map-reduce streaming job
INPUT_FILE="parcels-HEATING.CODE-known-val.pairs"
JOB_NAME="countInput"
USER_ID="rel292"
./map-reduce.sh $INPUT_FILE $JOB_NAME $USER_ID

