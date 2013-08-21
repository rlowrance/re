// Csv.h
#ifndef CSV_H
#define CSV_H

char *Csv_readDoubles(char *filePath, 
                      unsigned expectHeader,
                      unsigned numRows, 
                      unsigned numCols, 
                      double * array); // array[numRows][numCols]

#endif
