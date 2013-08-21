# compare-estimates.sh
# run compare-estimates.lua with typical parameters + supplied parameters
torch -i compare-estimates.lua -algo knn -base estimates -k 24 -obs 1A -pieces 100 $@
