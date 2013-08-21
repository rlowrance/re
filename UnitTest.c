// UnitTest.c
// implementation of UnitTest.h

#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "UnitTest.h"

unsigned UnitTest_failed;
unsigned UnitTest_OK;

void UnitTest_report() {
  fprintf(stderr, "Unit test report\n");
  fprintf(stderr, " Attempted %u tests\n", UnitTest_OK + UnitTest_failed);
  fprintf(stderr, " Passed %u of them\n", UnitTest_OK);
  fprintf(stderr, " Failed %u of them\n", UnitTest_failed);
  if (UnitTest_failed > 0)
    exit(EXIT_FAILURE);
  else
    exit(EXIT_SUCCESS);
}

void UnitTest_expect_eq_char(char actual,
			     char expected,
			     const char* functionName,
			     unsigned    lineNumber)
{
  if (actual == expected) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expect_eq_char failed in function %s line %u\n", 
	  functionName, lineNumber);
  fprintf(stderr, " expected=%c\n", expected);
  fprintf(stderr, " actual=%c\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_eq_double(double      expected, 
                               double      actual,
                               double      within,
                               const char* functionName, 
                               unsigned    lineNumber) {
  if (fabs(expected - actual) <= within) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, 
          "expect_eq_double failed in function %s at line %u\n",
          functionName,
          lineNumber);
  fprintf(stderr, " expected=%f\n", expected);
  fprintf(stderr, " actual=%f\n", actual);
  fprintf(stderr, " within=%f\n", within);
  UnitTest_failed++;
}

void UnitTest_expect_eq_int16(int16_t expected,
			      int16_t actual,
			      const char *functionName,
			      unsigned    lineNumber) 
{
  if (actual == expected) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expected_eq_int16 failed in function %s line %u\n",
	  functionName, lineNumber);
  fprintf(stderr, " expected=%u\n", expected);
  fprintf(stderr, " actual=%u\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_eq_pointer(const void *expected,
				const void *actual,
				const char *functionName,
				unsigned    lineNumber)
{
  if (actual == expected) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expect_eq_pointer failed in function %s line %u\n", 
	  functionName, lineNumber);
  fprintf(stderr, " expected=%p\n", expected);
  fprintf(stderr, " actual=%p\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_eq_str(const char *expected,
                            const char *actual,
                            const char *functionName,
                            unsigned    lineNumber)
{
  assert(actual);
  assert(expected);
  if (strcmp(actual, expected) == 0) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expect_eq_str failed in function %s line %u\n", 
	  functionName, lineNumber);
  fprintf(stderr, " expected=%s\n", expected);
  fprintf(stderr, " actual=%s\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_eq_uint8(uint8_t expected,
			      uint8_t actual,
			      const char *functionName,
			      unsigned    lineNumber) 
{
  if (actual == expected) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expected_eq_uint8 failed in function %s line %u\n",
	  functionName, lineNumber);
  fprintf(stderr, " expected=%u\n", expected);
  fprintf(stderr, " actual=%u\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_eq_uint32(uint32_t    expected,
			       uint32_t    actual,
			       const char *functionName,
			       unsigned    lineNumber) 
{
  if (actual == expected) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expected_eq_uint32 failed in function %s line %u\n",
	  functionName, lineNumber);
  fprintf(stderr, " expected=%u\n", expected);
  fprintf(stderr, " actual=%u\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_eq_uint64(uint64_t    expected,
			       uint64_t    actual,
			       const char *functionName,
			       unsigned    lineNumber) 
{
  if (actual == expected) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expected_eq_uint64 failed in function %s line %u\n",
	  functionName, lineNumber);
  fprintf(stderr, " expected=%lu\n", expected);
  fprintf(stderr, " actual=%lu\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_eq_unsigned(unsigned    expected, 
                                 unsigned    actual,
                                 const char* functionName, 
                                 unsigned    lineNumber) {
  if (expected == actual) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expect_eq_unsigned failed in function %s at line %u\n",
	  functionName, lineNumber);
  fprintf(stderr, " expected=%u\n", expected);
  fprintf(stderr, " actual=%u\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_fail(const char* message,
                          const char* functionName,
                          unsigned    lineNumber) {
  fprintf(stderr, 
          "expect_fail in function %s at line %u\n",
          functionName,
          lineNumber);
  fprintf(stderr, " message=%s\n", message);
  UnitTest_failed++;
}

void UnitTest_expect_ne_double(double      expected, 
                               double      actual,
                               const char* functionName, 
                               unsigned    lineNumber) {
  if (expected != actual) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, 
          "expect_ne_double failed in function %s at line %u\n",
          functionName,
          lineNumber);
  fprintf(stderr, " expected=%f\n", expected);
  fprintf(stderr, " actual=%f\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_ne_pointer(const void *expected, 
                                const void *actual,
                                const char *functionName, 
                                unsigned    lineNumber) {
  if (expected != actual) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, 
          "expect_ne_pointer failed in function %s at line %u\n",
          functionName,
          lineNumber);
  fprintf(stderr, " expected=%p\n", expected);
  fprintf(stderr, " actual=%p\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_ne_uint64(uint64_t    expected, 
                               uint64_t    actual,
                               const char* functionName, 
                               unsigned    lineNumber) {
  if (expected != actual) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, 
          "expect_ne_double failed in function %s at line %u\n",
          functionName,
          lineNumber);
  fprintf(stderr, " expected=%lu\n", expected);
  fprintf(stderr, " actual=%lu\n", actual);
  UnitTest_failed++;
}


void UnitTest_expect_not_null(void       *actual,
			      const char *functionName,
			      unsigned    lineNumber)
{
  if (actual != NULL) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expect_not_null failed in function %s line %u\n", 
	  functionName, lineNumber);
  fprintf(stderr, " actual=%p\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_null(const void *actual,
			  const char *functionName,
			  unsigned    lineNumber)
{
  if (actual == NULL) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expect_null failed in function %s line %u\n", 
	  functionName, lineNumber);
  fprintf(stderr, " actual=%p\n", actual);
  UnitTest_failed++;
}

void UnitTest_expect_true(int             actual,
			  const char     *functionName,
			  unsigned        lineNumber)
{
  if (actual) {
    UnitTest_OK++;
    return;
  }

  fprintf(stderr, "expect_true condition was %d in function %s line %u\n",
	  actual, functionName, lineNumber);
  UnitTest_failed++;
}
