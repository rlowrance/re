# merge 16 cache pieces to make a whole
# example:
#  ./make-obs-cache 1A
#  makes 
function run {
java -cp ../src/java/bin com.roylowrance.thesis.KNearestNeighbors --obs=$1 --action=merge
}

run $1



