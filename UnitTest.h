// UnitTest.h
// unit test framework
// inspired by Google's C++ unit test framework
// ref: http://code.google.com/p/googletest/wiki/Primer

// all APIs in stem alphabetic order
// EXPECT_EQ_CHAR
// EXPECT_EQ_DOUBLE
// EXPECT_EQ_INT16
// EXPECT_EQ_POINTER
// EXPECT_EQ_STR
// EXPECT_EQ_UINT8
// EXPECT_EQ_UINT32
// EXPECT_EQ_UINT64
// EXPECT_FAIL
// EXPECT_EQ_UNSIGNED
// EXPECT_NE_DOUBLE
// EXPECT_NE_POINTER
// EXPECT_NE_UINT64
// EXPECT_NOT_NULL
// EXPECT_NULL
// EXPECT_TRUE

#ifndef UNITTEST_H
#define UNITTEST_H

#include <stdint.h>

// the assert_* routines stop at the first error
// the expect_* routines detect and error and keep testing


extern unsigned UnitTest_failed;
extern unsigned UnitTest_OK;

void UnitTest_report(void);  // write to stderr

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_char(char        expected,
			     char        actual,
			     const char *functionName,
			     unsigned    lineNumber);

#define EXPECT_EQ_CHAR(expected, actual) \
  UnitTest_expect_eq_char((expected), (actual), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_double(double      expected, 
                               double      actual,
                               double      within,
                               const char* functionName, 
                               unsigned    lineNumber);


#define EXPECT_EQ_DOUBLE(expected, actual, within) \
  UnitTest_expect_eq_double((expected), (actual), (within), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_int16(int16_t     expected,
			      int16_t     actual,
			      const char *functionName,
			      unsigned    lineNumber);

#define EXPECT_EQ_INT16(expected, actual) \
  UnitTest_expect_eq_int16((expected), (actual), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_pointer(const void *expected,
				const void *actual,
				const char *functionName,
				unsigned    lineNumber);

#define EXPECT_EQ_POINTER(expected, actual) \
  UnitTest_expect_eq_pointer((expected), (actual), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_str(const char *expected,
                            const char *actual,
                            const char *functionName,
                            unsigned    lineNumber);
#define EXPECT_EQ_STR(expected, actual) \
  UnitTest_expect_eq_str((expected), (actual), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_uint8(uint8_t     expected,
			      uint8_t     actual,
			      const char *functionName,
			      unsigned    lineNumber);

#define EXPECT_EQ_UINT8(expected, actual) \
  UnitTest_expect_eq_uint8((expected), (actual), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_uint32(uint32_t    expected,
			       uint32_t    actual,
			       const char *functionName,
			       unsigned    lineNumber);

#define EXPECT_EQ_UINT32(expected, actual) \
  UnitTest_expect_eq_uint32((expected), (actual), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_uint64(uint64_t    expected,
			       uint64_t    actual,
			       const char *functionName,
			       unsigned    lineNumber);

#define EXPECT_EQ_UINT64(expected, actual) \
  UnitTest_expect_eq_uint64((expected), (actual), __func__, __LINE__)


////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_eq_unsigned(unsigned    expected, 
				 unsigned    actual,
				 const char* functionName, 
				 unsigned    lineNumber);


#define EXPECT_EQ_UNSIGNED(expected, actual) \
  UnitTest_expect_eq_unsigned((expected), (actual), __func__, __LINE__)

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_ne_double(double      expected, 
                               double      actual,
                               const char* functionName, 
                               unsigned    lineNumber);


#define EXPECT_NE_DOUBLE(expected, actual) \
  UnitTest_expect_ne_double((expected), (actual), __func__, __LINE__)


////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_ne_pointer(const void *expected,
                                 const void *actual,
                                 const char *functionName,
                                 unsigned    lineNumber);

#define EXPECT_NE_POINTER(expected, actual) \
  UnitTest_expect_ne_pointer((expected), (actual), __func__, __LINE__);

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_ne_uint64(uint64_t      expected, 
			       uint64_t      actual,
			       const char* functionName, 
			       unsigned    lineNumber);


#define EXPECT_NE_UINT64(expected, actual)				\
  UnitTest_expect_ne_uint64((expected), (actual), __func__, __LINE__)


////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_fail(const char* message,
                          const char* functionName,
                          unsigned    lineNumber);

#define EXPECT_FAIL(message) \
  UnitTest_expect_fail((message), __func__, __LINE__);

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_not_null(void       *actual,
			      const char *functionName,
			      unsigned    lineNumber);
 
#define EXPECT_NOT_NULL(actual) \
  UnitTest_expect_not_null((actual), __func__, __LINE__);

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_null(const void *actual,
			  const char *functionName,
			  unsigned    lineNumber);
 
#define EXPECT_NULL(actual) \
  UnitTest_expect_null((actual), __func__, __LINE__);
#endif

////////////////////////////////////////////////////////////////////////////////

void UnitTest_expect_true(int         actual,
			  const char *functionName,
			  unsigned    lineNumber);

#define EXPECT_TRUE(actual) \
  UnitTest_expect_true((actual), __func__, __LINE__);
