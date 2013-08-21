# make-softlinks-to-torch7-demos.sh
# run from lua directory

FROM_DIR=~/Dropbox/torch7-demos/logistic-regression

ln -s $FROM_DIR/Csv.lua Csv.lua
ln -s $FROM_DIR/LogisticRegression.lua LogisticRegression.lua
ln -s $FROM_DIR/Trainer.lua Trainer.lua
ln -s $FROM_DIR/Validations.lua Validations.lua
