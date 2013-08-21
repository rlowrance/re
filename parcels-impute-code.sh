# run torch parcels-impute-code.sh
CODE=HEATING.CODE

MPERYEAR=30
K=10
LAMBDA=0.001

SLICE=1
OF=100

DATA=../data/v6/output
KNOWN=$DATA/parcels-$CODE-known-train.pairs
STDIN=$DATA/parcels-$CODE-known-val.pairs
STDOUT=$DATA/parcels-impute-code-$CODE-known-val-imputed-$SLICE-$OF.pairs

ARG1=" --mPerYear $MPERYEAR"
ARG2=" --k $K"
ARG3=" --lambda $LAMBDA"
ARG4=" --known $KNOWN"
ARG5=" --slice $SLICE"
ARG6=" --of $OF"
ARG7=" < $STDIN"
ARG8=" > $STDOUT"
ARGS="$ARG1 $ARG2 $ARG3 $ARG4 $ARG5 $ARG6 $ARG7 $ARG8"

echo ARGS=$ARGS
torch parcels-impute-code.lua $ARGS

