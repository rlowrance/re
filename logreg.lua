-- logregFit.lua
-- Design notes for Murphy Machine Learning-style logistic regression model

-- API overview
if false then
   model = logregFit(X, y, 'optionName', optionValue, ...)
   -- option name / value pairs include
   -- 'lambda', number or seq : coefficient of L2 reguarlizer
   --   if specify a seq, does cross validation to select best lambda
   -- 'regType', L2    : use L2 regularizer
   -- 'weights', w     : importance of each X,y sample
   -- 'nfolds', n      : if CV, how many folds to use
   -- 'pp', function   : applies preprocessing function to X's
   -- 'nClasses', n    : number of classes in y; y[i] in {1, 2, ..., nClasses}
   -- 'algo', 'gd'     : fit with gradient descent

   -- once model is fitted, you can predict
   yHat, py = logregPredict(model, testX)
   -- yHat is point estimate
   -- py[i] is row of probabilities
end