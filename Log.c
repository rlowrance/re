// Log.c
// log to file and optionally one other stream

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "Log.h"

#define T Log_T

////////////////////////////////////////////////////////////////////////////////
// fail
////////////////////////////////////////////////////////////////////////////////

static void fail(char * msg) {
  fprintf(stderr, "%s\n", msg);
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// Log-new
////////////////////////////////////////////////////////////////////////////////

static FILE* originalFile = NULL;

// return pointer to struct Log_T
T Log_new(char *path, FILE *also) 
{
  const unsigned debug = 0;
  // allocate self
  T self = malloc(sizeof(struct T));
  if (!self) fail("Log_new: unable to allocate memory");

  // initialize self field not set just below
  self->also = also;

  // open the log file
  FILE *file = fopen(path, "w"); // erase file if already exists
  if (file == NULL) {
    perror("Log_new: unable to open log file ");
    exit(1);
  }

  self->file = file;
  if (debug) {
    originalFile = file;
    fprintf(stderr, "Log_new: self->file %p\n", (void *) self->file);
  }
  return self;
}


////////////////////////////////////////////////////////////////////////////////
// Log_free: close underlying file and free memory
////////////////////////////////////////////////////////////////////////////////

void Log_free(T *selfP) 
{
  assert(selfP);
  assert(*selfP);

  // close the main file
  T self = *selfP;
  if (fclose(self->file) != 0) fail("Log_free: unable to close log file");

  // free self
  free(self);

  // set argument to NULL pointer
  *selfP = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// Log_printf
////////////////////////////////////////////////////////////////////////////////

void Log_printf(T self, const char *format, ...) {
  // check arguments
  assert(self);
  assert(format);
  
  // print to log file
  va_list argptr;
  va_start(argptr, format);
  vfprintf(self->file, format, argptr);

  // maybe print to auxillary file
  if (self->also) {
    va_start(argptr, format);
    vfprintf(self->also,format, argptr);
  }
}

////////////////////////////////////////////////////////////////////////////////
// Log_printfFunctionLineTime
////////////////////////////////////////////////////////////////////////////////

// see PC p. 458
void Log_printfFunctionLineTime(T self,
				const char *functionName, 
                                unsigned lineNum,
				const char *format, 
                                ...) 
{
  const unsigned debug = 0;

  // check arguments
  assert(self);
  assert(functionName);
  assert(format);

  if (debug)
    assert(originalFile == self->file);

  // print time stamp, function, line num
  time_t timestamp = time(NULL);
  fprintf(self->file, "%.8s %s (line %u): ",
	  ctime(&timestamp)+11, functionName, lineNum);
  if (self->also)
    fprintf(self->also, "%.8s %s (line %u): ",
	    ctime(&timestamp)+11, functionName, lineNum);

  // print rest of message to log file
  va_list argptr;
  va_start(argptr, format);
  assert(self->file);
  if (debug) {
    fprintf(stderr, "Log_printFunctionLineTime: self->file %p\n", 
            (void *) self->file);
    // write to file directly
    fprintf(self->file, "test record\n");
  }
  vfprintf(self->file, format, argptr);  // Seg fault here, no such file

  // print to auxillary file
  if (self->also) {
    va_list argptr;
    va_start(argptr, format);
    vfprintf(self->also, format, argptr);
  }
}

