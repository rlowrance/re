// getline.c
// Reliably read a line of input

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#include "getline.h"

// read line of input from specified FILE into an malloc-allocated buffer
// return address of that buffer or NULL if (EOF or an IO error)
// replace any final newline character with a string terminator ('\0')
// ref: KC p 171
char *getline(FILE* file, unsigned maxBufferSize)
{
  char *linePtr = malloc(maxBufferSize + 1);
  if (linePtr == NULL) return NULL;
  // read line of text
  // replace newline with \0
  int c = EOF;
  unsigned int i = 0;
  while(i < maxBufferSize && (c = getc(file)) != '\n' && c != EOF)
    linePtr[i++] = (char) c;
  linePtr[i] = '\0';
  
  // if EOF before any characters read, release the buffer
  if (c == EOF && i == 0) {
    free(linePtr);
    return NULL;
  }

  // release any unused portion of buffer
  linePtr = realloc(linePtr, i + 1);  // i is the string length
  return linePtr;
}
