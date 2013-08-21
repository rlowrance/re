# copy all thesis data project files from $NYU home to a compute server
# run from $NYU:<thesis-project>/scripts
# usage:
#  cd scripts
#  ./rsync-access-to-compute-server.sh banque

rsync -r --progress ../../data/ $1:/scratch/lowrance/nyu-thesis-project/data/

# To recursively remove directories and all files
# rm -rf /path/to/directory
# rm -r /path/to/directory
