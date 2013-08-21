# Run HpSearch --algo=kwavg --obs=1A --bandwidthGrid=BANDWIDTH_GRID
# Create files <project>/data/generated-v4/obs2R/analysis/HpSearch-knn-2R.*

BANDWIDTH_GRID=[0.1,0.5,.8,.9,.95,.98,1,1.02,1.05,1.1,1.2,1.5,2,3]

./HpSearch.sh --algo=kwavg --obs=1A --bandwidthGrid=${BANDWIDTH_GRID}