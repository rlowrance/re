# unison-dropbox-access.sh
# run unison to synchronize the entire thesis directory
# JUST DO data/v5, lualibs, and srg.git

# uncomment line below to do all
unison ~/Dropbox/nyu-thesis-project ssh://$ACCESS/nyu-thesis-project

#PROJECT=~/Dropbox/nyu-thesis-project
#V5=$PROJECT/data/v5
#echo V5=$V5
#unison $V5 ssh://$ACCESS/$V5
