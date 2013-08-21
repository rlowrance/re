# make piece of the nearest neighbors cache
# example:
#  ./make-obs-cache 1A N

function run {
java -cp ../src.git/java/bin com.roylowrance.thesis.CreateNearestNeighborsCache --dataDir=$1 --obs=$2 --action=$3
}

run $1 $2 $3



