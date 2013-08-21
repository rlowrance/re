# copy selected thesis project files from $NYU access to Dropbox
# run from <thesis-project>/scripts
# example:
#  cd scripts
#  ./rsync-access-to-dropbox.sh

# An alternative to this scripts is to use FileZilla
# since sftp is enabled on ACCESS

# rsync options of interest
# final slash on name means copy entire directory
# -r recursive
# -n dry run (don't transer)
# --progress show progress

FROM_BASE=/home/lowrance/nyu-thesis-project/data/generate-v4/
TO_BASE=/home/roy/Dropbox/nyu-thesis-project/

$OBS1A=obs1A/
$OBS2A=obs2A/

# copy 1A directory
rsync -r --progress $ACCESS:$FROM_BASE$OBS1A $TO_BASE$OBS1A

# copy 2A directory
rsync -r --progress $ACCESS:$FROM_BASE$OBS2A $TO_BASE$OBS2A

# To recursively remove directories and all files
# rm -rf /path/to/directory
# rm -r /path/to/directory
