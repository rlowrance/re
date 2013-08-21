// daysPastEpoch.c
// determine days past an epoch, the first day in year 1900

// This code is a port of daysPastEpoch.lua to c

#include <assert.h>
#include <math.h>
#include <stdio.h>

#include "daysPastEpoch.h"

static unsigned isLeapYear(unsigned year)
{
  if ((year % 100) == 0) {
    if ((year % 400) == 0)
      return 0;
    else
      return 1;
  }
  else if ((year % 4) == 0)
    return 1;
  else
    return 0;
}

static void check(double expected, double date)
{
  double actual = daysPastEpoch(date);
  if (expected == actual) return;
  fprintf(stderr, "unit test of daysPastEpoch failed\n");
  fprintf(stderr, "expected = %f\n", expected);
  fprintf(stderr, "actual   = %f\n", actual);
  assert(expected == actual);  // to get the stack walkback
}

static void unitTest()
{
  check(  0, 19000101);
  check(  1, 19000102);
  check( 31, 19000201);
  check( 60, 19000301);
  check(365, 19001231);
  check(366, 19010101);

}

double daysPastEpoch(double date)
{
  static unsigned unitTested = 0;
  if (!unitTested) {
    unitTest();
    unitTested = 1;
  }

  assert(date > 19000000);
  double year = floor(date / 10000);
  double month = floor(date / 100 - year * 100);
  double day   = floor(date - year * 10000 - month * 100);

  const double firstYear = 1900;
  double yearDays = 0;
  for (unsigned yearNumber = firstYear; yearNumber < year - 1; yearNumber++) {
    yearDays += 365 + isLeapYear(yearNumber);
  }

  static double daysPerMonth[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  double monthDays = 0;
  for (unsigned monthNumber = 1; monthNumber < month; monthNumber++) {
    monthDays += daysPerMonth[monthNumber];
  }

  double leapDay = 0;
  if (isLeapYear((long)year) && month > 2)
    leapDay = 1;

  return yearDays + monthDays + leapDay + day - 1;
}

