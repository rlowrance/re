# copy selected thesis project files from Dropbox to $NYU access
# run from <thesis-project>/scripts
# What is copied:
# - all files in directory <project>/data/generated-v4/obs1A
# - all files in directory <project>/data/generated-v4/obs1A/features
# - all files in directory <project>/data/generated-v4/obs2R
# - all files in directory <project>/data/generated-v4/obs2R/features
# - all files in directory <project>/src.git

FROM_THESIS=/home/roy/Dropbox/nyu-thesis-project/
TO_THESIS=nyu-thesis-project/

SRC=src.git/
OBS1A=data/generated-v4/obs1A/
OBS2R=data/generated-v4/obs2R/

# rsync options of interest
# final slash on name means copy entire directory
# -r recursive
# -n dry run (don't transer)
# --progress show progress
# --times    adjust time stamps on copy to equal those on local

# copy source directory (which contains java executables)
rsync -r --progress --times $FROM_THESIS$SRC    $ACCESS:$TO_THESIS$SRC
rsync -r --progress --times /home/roy/Dropbox/kernel-smoothers/ $ACCESS:kernel-smoothers/

# copy 1A directory certain files
#rsync -r --progress --times $FROM_THESIS$OBS1A/*  $ACCESS:$TO_THESIS$OBS1A
rsync -r --progress --times $FROM_THESIS$OBS1A/features  $ACCESS:$TO_THESIS$OBS1A

# copy 2R directory
#rsync -r --progress --times $FROM_THESIS$OBS2R/*  $ACCESS:$TO_THESIS$OBS2R
rsync -r --progress --times $FROM_THESIS$OBS2R/features  $ACCESS:$TO_THESIS$OBS2R

# copy torch7
rsync -r --progress --times /home/roy/Dropbox/torch7 $ACCESS:

# To recursively remove directories and all files (or use FileZilla's GUI)
# rm -rf /path/to/directory
# rm -r /path/to/directory
