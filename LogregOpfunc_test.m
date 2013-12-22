% expected values for worked example 1 in LogregOpfunc_test.lua

% scores come from the output for the program
scores = [[-5 8 0] ; [-7 10 0]]

expscores = exp(scores)
rowsums = sum(expscores, 2)
row1Probabilities = expscores(1,:) / rowsums(1)
row2Probabilities = expscores(2,:) / rowsums(2)

