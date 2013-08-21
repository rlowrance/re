// Log-test.c

#include <assert.h>

#include "Log.h"

void test(FILE* auxillary) {
  Log_T log = Log_new("Log-test-testlog.txt", auxillary);
  assert(log);
  Log_printf(log, "auxillary is %p\n", auxillary);
  Log_printf(log, "should be 123: %d\n", 123);
  Log_printf(log, "about to free log\n");
  // the following statement cannot be made to work in standard compliant C
  //LOG(log, "time stamped message no params"); 

  // below is something that works
  LOG(log, "%s\n", "time stamped message with no params");
  LOG(log, "time stamped message with 456: %d\n", 456);
  Log_free(&log);
  assert(log == NULL);
}

int main(int argc, char **argv) {
  test(stderr);
  test(NULL);
  printf("Finished Log-test\n");
  return 0;
}
