# test csvAppend
# test by append 3 files and checking first known good result
../build-linux-64/csvAppend csvAppend-test-file1.csv csvAppend-test-file2.csv csvAppend-test-file3.csv > csvAppend-test-delete-me.csv
diff csvAppend-test-delete-me.csv csvAppend-test-expected-file.csv
# above prints nothing if the files are the same
rm csvAppend-test-delete-me.csv

