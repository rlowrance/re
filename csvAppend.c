// csvAppend.c
// Append csv files

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// write line to standard error followed by newline
void pute(char* line)
{
  fputs(line, stderr);
  fputs("\n", stderr);
}

void usage(char* msg) {
  if (msg) {
    printf("\nCommand line error: %s\n", msg);
  }

  pute(" ");
  pute("NAME");
  pute(" csvAppend - append all columns from csv files to the standard output");

  pute(" ");
  pute("SYNOPSIS");
  pute(" csvAppend [OPTION] FILE ...");

  pute(" ");
  pute("DESCRIPTION");
  pute(" Concatenate all columns in csv FILE(s) to standard output");
  pute(" Assumes that the field separator is a comma");

  pute(" ");
  pute("EXAMPLE");
  pute(" csvAppend SALE-AMOUNT.csv longitude-std.csv > combined.csv");
  pute("  writes csv file on stdout containing columns from the 2 files");
  
  exit(1);
}

// format an error message and write it
void errorInt(char *format, int var)
{
  char errorMsg[1000];
  sprintf(errorMsg, format, var);
  usage(errorMsg);
}

// format an error message and write it
void errorString(char *format, char *var)
{
  char errorMsg[1000];
  sprintf(errorMsg, format, var);
  usage(errorMsg);
}


int
main (int argc, char** argv)
{
  // open input files into an array of file handles
  #define MAXFILES 256
  FILE *files[MAXFILES];
  if (argc == 1) usage("no input files specified");
  int numInputFiles = argc - 1;
  for (int fileIndex = 0; fileIndex < numInputFiles; fileIndex++) {
    int argIndex = fileIndex + 1;
    if (fileIndex >= MAXFILES) 
      errorInt("code written to read only %d files", MAXFILES);
    FILE* fp = fopen(argv[argIndex], "r");
    if (fp == NULL) 
      errorString("could not open file %s for input", argv[argIndex]);
    files[fileIndex] = fp;
  }

  // read record by record, writing to stdout
  #define MAX_INPUT_RECORD 10000
  char inputRecord[MAX_INPUT_RECORD];
  int done = 0;
  while (1) {
    for (int fileIndex = 0; fileIndex < numInputFiles; fileIndex++) {
      // this save the terminating new line, which we need to delete
      //printf("fgets %p\n",  fgets); // doesn't work!
      if (fgets(inputRecord, MAX_INPUT_RECORD, files[fileIndex]) == NULL) {
        // here if no more input or a read error on the file
        // assume its no more input
        if (fileIndex == 0) {done = 1; break;} // first file had no more records
        errorInt("end of file on file number %d while more records in first file", fileIndex);
      }

      // trim off newline character (ref: PC p 321), if one is present
      size_t len = strlen(inputRecord);
      if (inputRecord[len - 1] == '\n')
        inputRecord[len - 1] = '\0';

      // add a comma between files
      if (fileIndex > 0) fputs(",", stdout);
      fputs(inputRecord, stdout);
    }
    if (done) break;
    fputs("\n", stdout);
  }

  // close all the input files
  for (int fileIndex = 0; fileIndex < numInputFiles; fileIndex++) {
    if (fclose(files[fileIndex]) != 0) 
      errorInt("unable to close input file number %d", fileIndex);
  }
  
  exit(0);
}
