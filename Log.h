// Log.h

#ifndef LOG_H
#define LOG_H

#include <stdio.h>

#define T Log_T

typedef struct T *T;

struct Log_T {
  FILE *file;
  FILE *also;
};

extern T    Log_new(char *path, FILE *also);

// close underlying file and free memory; set *logP to NULL
extern void Log_free(T *logP);  

extern void Log_printf(T log, const char *format, ...);  

extern void Log_printfFunctionLineTime(T log, 
				       const char *functionName, 
                                       unsigned lineNum, 
				       const char * format, ...);

#define LOG(log, format, ...) \
  Log_printfFunctionLineTime(log, __func__, __LINE__, format, __VA_ARGS__)

// User can invoke this macro in own LOG macro
#define LOGGER(log, format, ...)\
  Log_printfFunctionLineTime(log, __func__, __LINE__, format, __VA_ARGS__)

#undef T
#endif

