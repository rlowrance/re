# copy all thesis project files from $NYU home to current directory
# run from $NYU:<thesis-project>/scripts
# usage:
#  ssh OTHER_SERVER
#  cd /scratch/lowrance
#  /home/lowrance/nyu-thesis-project/scripts/rsync-from-home.sh


FROM_BASE=/home/lowrance/nyu-thesis-project/
TO_BASE=../

echo from base is $FROM_BASE
echo to base   is $TO_BASE

JAVA=src.git/java/
OBS1A=data/generated-v4/obs1A/
OBS2R=data/generated-v4/obs2R/
SCRIPTS=scripts/

# rsync options of interest
# final slash on name means copy entire directory
# -r recursive
# -n dry run (don't transer)
# --progress show progress

rsync -r --progress $FROM_BASE$SCRIPTS $TO_BASE$SCRIPTS
rsync -r --progress $FROM_BASE$JAVA    $TO_BASE$JAVA
rsync -r --progress $FROM_BASE$OBS1A   $TO_BASE$OBS1A
rsync -r --progress $FROM_BASE$OBS2R   $TO_BASE$OBS2R

# To recursively remove directories and all files
# rm -rf /path/to/directory
# rm -r /path/to/directory
