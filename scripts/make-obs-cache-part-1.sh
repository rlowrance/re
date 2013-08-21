# make part 1 of the observation cache
# part 1 is pieces 1, 2, 3, 4
function run {
java -cp ../src/java/bin com.roylowrance.thesis.KNearestNeighbors --obs=$1 --action=$2
}

run 1A 1
run 1A 2
run 1A 3
run 1A 4

#run-java KNearestNeighbors --obs=$1 --action=1
#run-java KNearestNeighbors --obs=$1 --action=2
#run-java KNearestNeighbors --obs=$1 --action=3
#run-java KNearestNeighbors --obs=$1 --action=4

