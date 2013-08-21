# rsync-dropbox-to-access-all.sh
# copy files in Dropbox/nyu-thesis-project to access server

HOME=/home/roy
#HOME=/Users/rel

DIR1=nyu-thesis-project/data/v6/
DIR2=nyu-thesis-project/src.git/

rsync -r --progress --times $HOME/Dropbox/$DIR1 $ACCESS:$DIR1
rsync -r --progress --times $HOME/Dropbox/$DIR2 $ACCESS:$DIR2

#FROM_THESIS=$HOME/Dropbox/nyu-thesis-project/
#TO_THESIS=nyu-thesis-project/

#rsync -r --progress --times $FROM_THESIS    $ACCESS:$TO_THESIS

# rsync options of interest
# final slash on name means copy entire directory
# -r recursive
# -n dry run (don't transer)
# --progress show progress
# --times    adjust time stamps on copy to equal those on local

