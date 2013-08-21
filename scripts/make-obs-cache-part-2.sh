# make part 2 of the observation cache
# part 2 is pieces 5,6,7,8
function run {
java -cp ../src/java/bin com.roylowrance.thesis.KNearestNeighbors --obs=$1 --action=$2
}

run 1A 5
run 1A 6
run 1A 7
run 1A 8

#run-java KNearestNeighbors --obs=$1 --action=1
#run-java KNearestNeighbors --obs=$1 --action=2
#run-java KNearestNeighbors --obs=$1 --action=3
#run-java KNearestNeighbors --obs=$1 --action=4

