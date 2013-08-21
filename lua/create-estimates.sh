# create-estimates.sh
# Create a bunch of estimates for the radiuses specified on the command line
for radius in $@
do
    echo $radius
    torch create-estimates.lua -algo knn -obs 1A -sample 0.1 -radius $radius
done
