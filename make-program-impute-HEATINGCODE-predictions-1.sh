CACHE=../data/v6/output/program_impute-cache.serialized
#rm $CACHE
lua program_impute.lua \
    --cache \
    --train hasHEATING.CODE isTrain \
    --test hasHEATING.CODE isTest \
    --target HEATING.CODE \
    --hpset 1 \
    --output ../data/v6/output/program_impute_HEATINGCODE_predictions_1.sh

