OUTPUT=../data/v6/output
FILEBASE=parcels-sfr-geocoded-info
FACTORS=""
luajit program_csv_to_ser_NamedMatrix.lua \
    --input $OUTPUT/$FILEBASE.csv \
    --output $OUTPUT/$FILEBASE.serialized-NamedMatrix \
    --tensorType Byte \
    --factors $FACTORS
    
