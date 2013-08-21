# complete-matrix.sh
# usage: complete-matrix.sh COL RANK LEARNING_RATE LEARNING_RATE_DECAY 

torch complete-matrix.lua -algo knn -col $1 -lambda 0.001 -learningRate $3 -learningRateDecay $4 -obs 1A -radius 76 -rank $2 -timeLbfgs 600 -timeSgd 60 -which complete -yearFirst 1984
