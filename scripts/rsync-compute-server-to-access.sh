# copy cache files form compute server to access
# usage:
#  ssh $ACCESS
#  cd scripts
#  ./rsync-compute-server-to-access.sh lowrance@banquo.cims.nyu.edu

FROM=/scratch/lowrance/nyu-thesis-project/data/generated-v4/
TO=../data/generated-v4/

rsync -r --progress  $1:$FROM $TO

# To recursively remove directories and all files
# rm -rf /path/to/directory
# rm -r /path/to/directory
