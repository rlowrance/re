// knnHpSearch2.c
// find best hyperparameter K for knn algo

// Algorithm used:
// 1. Read the prices.
// 2. Read the cached estimated prices for each test transactions.
// 3. Complete the cache by adding any missing transactions.
//    a. Determine which transactions are in the test set.
//    b. For each possible test transaction
//       1) If the estimated prices are in the cache, skip it.
//       2) Otherwise, determine the indices of its nearest neighbors.
//       3) for each k = 1, 2, ..., kMax
//          a) Determine estimated price using k nearest neighbor indices
//          b) Save this estimated price in the cache
// 4. Write out the cache (to be read the next time).
// 5. For each possible hyperpameter value k
//    a. Determine rmse for test transactions using k nearest neighbors.
//    b. Save the k for the lowest rmse
// 6. The best value for k is the last k saved.

#define VERSION_MAJOR 0
#define VERSION_MINOR 3
#define PROGRAM_NAME "knnHpSearch2"

// C headers
#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>
#include <math.h>

// GNU headers
#include <dirent.h>
#include <getopt.h>
#include <sys/stat.h>

// project headers
#include "Csv.h"
#include "halt.h"
#include "Log.h"
#include "Random.h"

////////////////////////////////////////////////////////////////////////////////
// report user errors
////////////////////////////////////////////////////////////////////////////////

// write line to standard error followed by newline
static void u(char* line)
{
  fputs(line, stderr);
  fputs("\n", stderr);
}

static void usage(char* msg) {
  if (msg) {
    printf("\nCommand line error: %s\n", msg);
  }

  u("");
  u("Determine k value to minimize RMSE on known transactions. Usage:");
  u("  cd FEATURES && knnHpSearch2 PARAMS");
  u("where");
  u("  FEATURES is a directory containing the input files");
  u("  FEATURES/features.csv is a file contain features");
  u("  FEATURES/dates.csv is a file containing dates");
  u("  FEATURES/SALE-AMOUNT-log.csv is a file containing log(sale prices)");
  u("  FEATURES/knnHpSearch2-obsOBSCache.txt is a file contains a KnnCache");
  u("  PARAMS are the command line parameters");
  u(" ");

  u("PARAMS:");
  u(" --obs OBS   Observation set id; must be 1A or 2R for now");
  u(" --cache     Write and read estimated prices to " 
                    "FEATURES/knnHpSearch2-obsOBS-cache.txt");
  u(" ");

  u("DESCRIPTION");
  u(" For every test transaction in 2000, 2001, ..., 2009, "
    "determine error using");
  u(" k=1, 2, ..., 100");
  u(" Calculate RMSE using these transaction errors");
  u(" Determine k that minimizes the RMSE");
  u(" Write results to  ../analysis/knnHpSearch2-obsOBS.k-rmse.csv");
  u(" Write log file to ../analysis/knnHpSearch2-obsOBS.log");
  u(" Write cache file to knnHpSearch2-obsOBS-cache.txt");
  u(" ");

  u("EXAMPLE");
  u(" cd obs1/features");
  u(" knnHpSearch2 --obs 1A");
  
  exit(1);
} // end usage

////////////////////////////////////////////////////////////////////////////////
// process command line
////////////////////////////////////////////////////////////////////////////////

struct paramsStruct {
  char     obs[3];  // ex: "1A\0"
  char     useCache;  // true iff --cache was supplied
};

static void 
parseCommandLine(int argc, char **argv, struct paramsStruct *paramsP) 
{
  // initialize params to illegal values or default values
  paramsP->obs[0] = ' ';
  paramsP->useCache = 0;

  // define the command line paramters
  struct option longOptions[] = {
    {"version", optional_argument, NULL, 'v'},  // a GNU standard long option
    {"help", optional_argument, NULL, 'h'},     // a GNU standard long option
    {"obs", required_argument, NULL, 'o'},
    {"cache", no_argument, NULL, 'c'},
    {0, 0, 0, 0},                               // makk end of long options defs
  };
  while (1) {
    int optionIndex = 0;
    // no short options
    int c = getopt_long(argc, argv, "", longOptions, &optionIndex);
    if (c == -1) break;  // detect end of options
    switch (c) {
    case 'v': // version 
      fprintf(stderr, "Version %u.%u compiled %s at %s\n",
              VERSION_MAJOR, VERSION_MINOR, __DATE__, __TIME__);
      break;
    case 'h': // help
      usage(NULL);
      break;
    case 'o': // --obs OBS
      // value is in char * optarg
      if (!strlen(optarg) == 2) usage("OBS must be 2 characters");

      // strcmp returns s1 compared to s2, hence negative, 0, or positive int
      if (strcmp(optarg, "1A") != 0 &&
          strcmp(optarg, "2R") != 0) 
        usage("OBS must be 1A or 2R");
      strcpy(paramsP->obs, optarg);
      break;
    case 'c': // --cache
      paramsP->useCache = 1;
      break;
    case '?': // getopt_long already printed error message
      break;
    default:
      fprintf(stderr, "getopt_long returned unexcepted value");
      abort();
    }
  }

  // check if required parameters were supplied
  if (paramsP->obs[0] == ' ')
    usage("--obs is required");

  // check that no extra parameters were supplied
  if (optind < argc)
    usage("extra arguments on command line");
} // end parseCommandLine


////////////////////////////////////////////////////////////////////////////////
// feadFeatures
////////////////////////////////////////////////////////////////////////////////

// return pointer to 2D array of feature values from disk
static double *readFeatures(unsigned nObservations, unsigned nDimensions) 
{
  double *featuresP = malloc(sizeof(double) * nObservations * nDimensions);
  if (!featuresP) 
    halt("unable to allocate features: %u x %u\n", nObservations, nDimensions);
  const unsigned expectHeader = 1;
  char * featuresHeader = 
    Csv_readDoubles("features.csv", expectHeader, nObservations, nDimensions, 
                    featuresP);
  free(featuresHeader);  //don't use the header
  return featuresP;
}

////////////////////////////////////////////////////////////////////////////////
// readDates
////////////////////////////////////////////////////////////////////////////////

// return pointer to 1D array of dates from disk
static double *readDates(unsigned nObservations) {
  double *datesP = malloc(sizeof(double) * nObservations);
  if (!datesP)
    halt("unable to allocate dates: %u\n", nObservations);
  const unsigned expectHeader = 1;
  char * datesHeader = 
    Csv_readDoubles("date.csv", expectHeader, nObservations, 1, datesP);
  free(datesHeader);     // don't use the header
  return datesP;
}

////////////////////////////////////////////////////////////////////////////////
// readPrices
////////////////////////////////////////////////////////////////////////////////

// return pointer to 1D array of prices from disk
static double *readPrices(unsigned nObservations) {
  double *pricesLogStdP = malloc(sizeof(double) * nObservations);
  if (!pricesLogStdP)
    halt("unable to allocate prices: %u\n", nObservations);
  const unsigned expectHeader = 1;
  char *pricesHeader =
    Csv_readDoubles("SALE-AMOUNT-log.csv", 
                    expectHeader, nObservations,1, pricesLogStdP);
  free(pricesHeader);   // don't use the header
  return pricesLogStdP;
}

////////////////////////////////////////////////////////////////////////////////
// determineTestSet
////////////////////////////////////////////////////////////////////////////////

// return pointer to 1D array of chars, 1 iff the date is in the test set
static char *
determineTestSet(unsigned nObservations, 
                 double dates[nObservations], 
                 unsigned nTestSet)
{
  //const unsigned trace = 0;

  // allocate results array
  char *isTestSetP = malloc(sizeof(char) * nObservations);
  if (!isTestSetP)
    halt("unable to allocate isTestP: %u\n", nObservations);

  // check that we found the right number of test indices
  // the right number is in parameter nTestSet
  unsigned numTestsFound = 0;  // number of test indices found so far

  // check each date to see if in test set
  for (unsigned i = 0; i < nObservations; i++) {
    // date is coded YYYYMMDD
    double year = dates[i] / 10000.0;
    if (2000.0 <= year && year < 2010.0) {
      isTestSetP[i] = 1;
      //assert(numTestsFound < nTestSet);
      numTestsFound++;
    }
    else {
      isTestSetP[i] = 0;
    }
  }

  const unsigned countOK = numTestsFound == nTestSet;
  if (!countOK) 
    fprintf(stderr, 
            "determineTestSet: numTestsFound %u expected%u\n",
            numTestsFound, nTestSet);
  assert(countOK);

  return isTestSetP;
} // determineTestSet

////////////////////////////////////////////////////////////////////////////////
// determineEstimates
////////////////////////////////////////////////////////////////////////////////

// return array of kMax estimated prices using the the actual prices 
// and neighbors
// The estimate is the average price of the k nearest neighbors
static double *
determineEstimates (unsigned  kMax,
		    double    pricesP[kMax],
		    unsigned  neighborsP[kMax])
{
  static unsigned trace = 0;
  
  //determine sum of prices for each k
  double *sumPricesP = malloc(sizeof(double *) * kMax);
  double sumSoFar = 0.0;
  for (unsigned k = 0; k < kMax; k++) {
    double nextPrice = pricesP[neighborsP[k]];
    if (trace)
      fprintf(stderr, 
              "determineEstimates: k %u, neighbor index %u next prices %f\n",
	      k, neighborsP[k], nextPrice);
    sumSoFar += nextPrice;
    sumPricesP[k] = sumSoFar;
    if (trace)
      fprintf(stderr, "determineEstimates: sumPricesP[%u] = %f\n",
              k, sumPricesP[k]);
  }
  // now sumPricesP[k] = price[1] + price[2] + ... + price[k]

  //determine average for each k
  //resuse the memory
  for (unsigned k = 0; k < kMax; k++) {
    sumPricesP[k] = sumPricesP[k] / (k + 1);
    if (trace)
      fprintf(stderr, "determineEstimates: avgPrice[%u] = %f\n",
              k, sumPricesP[k]);
  }

  return sumPricesP;  // return average prices array
}

////////////////////////////////////////////////////////////////////////////////
// determineNeighbors 
////////////////////////////////////////////////////////////////////////////////

struct distanceIndex {
  double distance;
  unsigned index;
};

//////////////////// sortCompareFunction

static int 
sortCompareFunction(const void *a, const void *b)
{
  const int trace = 0;
  struct distanceIndex *diAPtr = (struct distanceIndex *) a;
  struct distanceIndex *diBPtr = (struct distanceIndex *) b;
  double distanceA = diAPtr -> distance;
  double distanceB = diBPtr -> distance;
  int result;
  if (distanceA < distanceB) result =  -1;
  else if (distanceA > distanceB) result = +1;
  else result =  0;
  if (trace) printf("sortCompareFunction: distances A %f B %f result %d\n",
		    distanceA, distanceB, result);
  return result;
}

//////////////////// distance

static double 
distance(unsigned nObservations, unsigned nDimensions, double* featuresP,
         unsigned indexA, unsigned indexB)
{
  const unsigned trace = 0;
  assert(indexA < nObservations);
  assert(indexB < nObservations);
  double sumSquaredDeltas = 0.0;
  for (unsigned dimIndex = 0; dimIndex < nDimensions; dimIndex++) {
    double a = *(featuresP + indexA * nDimensions + dimIndex);
    double b = *(featuresP + indexB * nDimensions + dimIndex);
    if (trace)
      fprintf(stderr, "dimIndex %u indexA %u a %f indexB %u b %f\n",
              dimIndex, indexA, a, indexB, b);
    double delta = a - b;
    sumSquaredDeltas += delta * delta;
  }
  return sqrt(sumSquaredDeltas);
}

//////////////////// determineNeighbors

// return malloc'd array of indices of nearest kMax neighbors to obsIndex
static unsigned *
determineNeighbors(unsigned  nObservations, 
                   unsigned  nDimensions, 
                   double   *featuresP,
                   unsigned  obsIndex,
                   unsigned  kMax)
{
  const unsigned trace = 0;

  // NOTE: An earlief version allocated di on the stack, but
  // for obs 2R, nObservations was so large that a seg fault resulted
  struct distanceIndex *diP = 
    malloc(sizeof(struct distanceIndex) * nObservations);
  assert(diP);
  // earlier version:
  // struct distanceIndex di[nObservations];

  for (unsigned otherIndex = 0; otherIndex < nObservations; otherIndex++) {
    double dist = (otherIndex == obsIndex) ? DBL_MAX : distance(nObservations,
                                                                nDimensions,
                                                                featuresP,
                                                                otherIndex,
                                                                obsIndex);
    struct distanceIndex *p = diP + otherIndex;
    (*p).distance = dist;
    (*p).index = otherIndex;
    if (trace && otherIndex < 10)
      fprintf(stderr, "di distance %f di index %u\n", 
              (*p).distance, (*p).index);
  }

  qsort(diP, 
        nObservations, 
        sizeof(struct distanceIndex), 
        sortCompareFunction);

  // check that di is sorted
  if (trace) {
    for (unsigned i = 0; i < nObservations - 1; i++) {
      struct distanceIndex *pI = diP + i;
      struct distanceIndex *pIPlus1 = diP + i + 1;
      if ((*pI).distance <= (*pIPlus1).distance)
        continue;
      fprintf(stderr, "di[%u].distance %f di[%u].distance %f\n",
              i, (*pI).distance, i+1, (*pIPlus1).distance);
      assert((*pI).distance <= (*pIPlus1).distance);
    }
  }

  unsigned *neighborsP = malloc(sizeof(unsigned) * kMax);
  assert(neighborsP);
  for (unsigned neighborIndex = 0; neighborIndex < kMax; neighborIndex++) {
    struct distanceIndex *p = diP + neighborIndex;
    neighborsP[neighborIndex] = (*p).index;
    assert(neighborsP[neighborIndex] < nObservations);
    if (0 && trace)
      fprintf(stderr, 
              "neighborIndex[%u]=%u\n", 
              neighborIndex, *(neighborsP + neighborIndex));
  }

  // if tracing, print first neighbor vs. obsIndex
  if (trace) {
    fprintf(stderr, "determineNeighbors: obsIndex %u\n", obsIndex);
    for (unsigned compare = 0; compare < 4; compare++) {
      unsigned neighborIndex = *(neighborsP + compare);
      fprintf(stderr, 
              " obsIndex vs neighbor %u index %u feature differences\n", 
              compare, neighborIndex);
      for (unsigned dimIndex = 0; dimIndex < nDimensions; dimIndex++) {
        const double a = *(featuresP + neighborIndex * nDimensions + dimIndex);
        const double b = *(featuresP + obsIndex * nDimensions + dimIndex);
        if (a == b) 
          continue;
        fprintf(stderr,
                "  dim %u neighbor feature %f obsIndex feature %f\n",
                dimIndex, a, b);
      }
      struct distanceIndex *p = diP + compare;
      fprintf(stderr, "  distance=%f\n", (*p).distance);
    }
  }

  free(diP);
  
  return neighborsP;
}

////////////////////////////////////////////////////////////////////////////////
// completeCache
////////////////////////////////////////////////////////////////////////////////

// return 1 if cache was mutated; 0 otherwise
static unsigned completeCache(unsigned nObservations,
                              unsigned nDimensions,
                              unsigned nTestSet,
                              double **pricesHatP,
                              char obs[2],
                              Log_T log,
                              unsigned kMax,
                              double *pricesP,
                              unsigned debug)
{
  const unsigned trace = 0; 
  const unsigned debug2 = 0;

  unsigned cacheMutated = 0;

  //const unsigned reportFrequency = 100;
  LOG(log, "buildCache: nObservations %u\n", nObservations);
  LOG(log, "buildCache: nDimensions %u\n", nDimensions);
  LOG(log, "buildCache: kMax %u\n", kMax);
  LOG(log, "buildCache: nTestSet %u\n", nTestSet);


  double *featuresP = readFeatures(nObservations, nDimensions);
  double *datesP   = readDates(nObservations);


  char *inTestSetP = determineTestSet(nObservations, datesP, nTestSet);
  free(datesP);
  if (trace) {
    fprintf(stderr, "head(inTestSet:");
    for (unsigned i = 0; i < 10; i++)
      fprintf(stderr, " %u ", inTestSetP[i]);
    fprintf(stderr, "\n");
  }
  
  // determine all the estimated prices
  // a vector of pointers to vectors of doubles
  unsigned nObservationsEstimated = 0;
  for (unsigned obsIndex = 0; obsIndex < nObservations; obsIndex++) {
    const unsigned reportingFrequency = 1000;
    if ((obsIndex % reportingFrequency) == 0)
      fprintf(stderr,
              "completeCache: obsIndex %u nObservations %u\n",
              obsIndex, nObservations);
    if (!inTestSetP[obsIndex]) {
      pricesHatP[obsIndex] = NULL;
      continue; // observation is not in test set
    }

    if (pricesHatP[obsIndex] != NULL)
      continue; // already have determined estimates for this test observation

    cacheMutated = 1;
    // determine kMax nearest neighbor indices for obsIndex
    nObservationsEstimated++;
    if (debug2 && nObservationsEstimated > 3)
      break;
    unsigned *queryNeighborsP = determineNeighbors(nObservations, 
                                                   nDimensions, 
                                                   featuresP, 
						   obsIndex, 
                                                   kMax);
    if (trace) {
      fprintf(stderr,
              "obsIndex %u\nneighborIndices",
              obsIndex);
      for (unsigned n = 0; n < kMax; n++) {
        fprintf(stderr, " %u", queryNeighborsP[n]);
      }
      fprintf(stderr, "\n");
      fprintf(stderr, "actual price %f\n", pricesP[obsIndex]);
    }

    // determine estimate prices for k=1, 2, ..., kMax for obsIndex
    double *queryEstimatesP = determineEstimates(kMax, 
                                                 pricesP, 
                                                 queryNeighborsP);
    if (trace) {
      fprintf(stderr, "obsIndex %u\nestimated prices", obsIndex);
      for (unsigned n = 0; n < kMax; n++)
	fprintf(stderr, " %f", queryEstimatesP[n]);
      fprintf(stderr, "\n");
    }
    pricesHatP[obsIndex] = queryEstimatesP;
    //if (debug) halt("check first computation");
    free(queryNeighborsP);
  }

  return cacheMutated;
}

////////////////////////////////////////////////////////////////////////////////
// openCache
////////////////////////////////////////////////////////////////////////////////

// return FILE* or NULL if the cache file does not exist in the mode specified
static FILE *openCacheFile(char obs[2], Log_T log, char* mode)
{
  // create path to cache file
  char cacheFilePath[128];
  int outputLength = snprintf(cacheFilePath,
                              sizeof(cacheFilePath),
                              "knnHpSearch2-obs%c%c-cache.txt",
                              obs[0], obs[1]);
  assert(outputLength < (int)sizeof(cacheFilePath));

  LOG(log, "opening cache file %s\n mode %s\n", cacheFilePath, mode);
  FILE *cacheFile = fopen(cacheFilePath, mode); 
  if (cacheFile == NULL)
    LOG(log, "%s\n", "cache file did not open");

  return cacheFile;
}

////////////////////////////////////////////////////////////////////////////////
// readCache
////////////////////////////////////////////////////////////////////////////////

// return incomplete matrix of estimated prices from cache file
// check integrity of the cache
// allocate the cache
// allow the cache file to be empty
static double **readCache(unsigned nObservations,
                          char obs[2],
                          Log_T log,
                          unsigned kMax,
                          double **estimatedPricesP)
{
  const unsigned debug = 0;

  FILE *cacheFile = openCacheFile(obs, log, "r"); // read from beginning
  if (cacheFile == NULL) {
    // return empty cache as the file does not exist
    return estimatedPricesP;
  }

  unsigned nRecords;
  assert(fscanf(cacheFile, "%u", &nRecords) == 1);

  unsigned fileKMax;
  assert(fscanf(cacheFile, "%u", &fileKMax) == 1);
  LOG(log, "readCache file nRecord %u kMax %u\n", nRecords, fileKMax);
  assert(fileKMax == kMax);

  // read each record in the file and build the cache
  // <obsIndex> <estPrice_1> <estPrice_2> ... <estPrice_kMax>
  // intialize each priceHat row to NULL
  unsigned lastObsIndex = 0;
  unsigned cacheRecordsRead = 0;
  while (1) {
    unsigned obsIndex;
    if (fscanf(cacheFile, "%u", &obsIndex) != 1)
      break;  // out of data
    assert(obsIndex < nObservations);

    // obsIndex is in increasing order
    if (lastObsIndex != 0)
      assert(obsIndex > lastObsIndex);
    lastObsIndex = obsIndex;

    if (debug)
      fprintf(stderr, "\n%u", obsIndex);

    // read the price estimates for the observation
    double *estimatesP = malloc(sizeof(double) * kMax);
    assert(estimatesP);
    for (unsigned k = 0; k < kMax; k++) {
      double estimate;
      if (fscanf(cacheFile, "%lf", &estimate) == 1) {
        estimatesP[k] = estimate;
        if (debug)
          fprintf(stderr, " %f", estimate);
      }
      else {
        // report the problem with the input file structure
        for (unsigned kk = 0; kk < k; kk++)
          fprintf(stderr," estimate[%u]=%f\n", kk, estimatesP[kk]);
        LOG(log, "readCache: eof at obsIndex %d estimate %f k %u\n",
            obsIndex, estimate, k);
        halt("unexpected EOF in cache file");
      }
    }

    // save the price estimates
    estimatedPricesP[obsIndex] = estimatesP;
    cacheRecordsRead++;
  }
  
  LOG(log, "read %u data records from the cache\n", cacheRecordsRead);

  // close the cache file
  assert(fclose(cacheFile) == 0);
 
  return estimatedPricesP;
}

////////////////////////////////////////////////////////////////////////////////
// writeCache
////////////////////////////////////////////////////////////////////////////////

static void writeCache(unsigned nObservations,
                       double **estimatedPricesP,
                       char obs[2],
                       Log_T log,
                       unsigned kMax)
{
  const unsigned debug = 0;

  FILE *cacheFile = openCacheFile(obs, log, "w"); // erase after opening

  // determine number of records that will be written
  unsigned recordsToWrite = 0;
  for (unsigned obsIndex = 0; obsIndex < nObservations; obsIndex++) {
    if (estimatedPricesP[obsIndex] == NULL)
      continue;
    recordsToWrite++;
  }

  // write 2 header records to cache file 
  fprintf(cacheFile, "%d\n", recordsToWrite);
  fprintf(cacheFile, "%d\n", kMax);

  // write the records
  unsigned recordsWritten = 0;
  for (unsigned obsIndex = 0; obsIndex < nObservations; obsIndex++) {
    if (estimatedPricesP[obsIndex] == NULL)
      continue;
    fprintf(cacheFile, "%d", obsIndex);
    for (unsigned k = 0; k < kMax; k++) {
      fprintf(cacheFile, " %f", estimatedPricesP[obsIndex][k]);
    }

    fprintf(cacheFile, "\n");
    recordsWritten++;
    if (debug)
      break;
  }
  // close the cache file
  if (debug)
    fprintf(stderr, "writeCache: log %p recordsWritten %u\n", 
            (void*) log, recordsWritten);
  LOG(log, "wrote %u data records to the cache\n", recordsWritten);
 
  assert(fclose(cacheFile) == 0);
  LOG(log, "%s\n", "cache file closed successfully");
}

////////////////////////////////////////////////////////////////////////////////
// bestK
////////////////////////////////////////////////////////////////////////////////

// log best value of K for random sample of observations
static void bestK(double   fraction, unsigned nObservations, 
                  double  *estimatedPricesP[nObservations], 
                  double   prices[nObservations],
                  Log_T    log,
                  unsigned kMax)
{
  const unsigned trace = 0;

  // histogram of observed bestK values in the random sample
  unsigned countOfK[kMax];
  for (unsigned k = 0; k < kMax; k++)
    countOfK[k] = 0;

  for (unsigned obsIndex = 0; obsIndex < nObservations; obsIndex++) {
    // only examine test transactions (those with an estimated price)
    if (estimatedPricesP[obsIndex] == NULL)
      continue;
    
    // select samples at random
    if (Random_uniform(0, 1) < fraction)
      continue;

    // find best K for this transaction
    double lowestError = DBL_MAX;
    unsigned bestK = kMax;
    for (unsigned k = 0; k <= kMax; k++) {
      double estimate = estimatedPricesP[obsIndex][k];
      double actual = prices[obsIndex];
      double error = actual - estimate;
      if (error < lowestError) {
        lowestError = error;
        bestK = k;
      }
    }
    
    // log and count bestK values
    if (trace)
      LOG(log, "obsIndex %u bestK %u\n", obsIndex, bestK + 1);
    countOfK[bestK]++;
  }

  // log historgram of best k values
  LOG(log, "histogram of best k values based on %f sample\n", fraction);
  for (unsigned k = 0; k < kMax; k++) {
    if (countOfK[k] == 0)
      continue;
    LOG(log, " countOf[%u] = %u\n", k+1, countOfK[k]);
  }
}

////////////////////////////////////////////////////////////////////////////////
// determineRmse
////////////////////////////////////////////////////////////////////////////////

// return RMSE for given hyperparameter k
static double determineRmse(unsigned nObservations, 
                            double *estimatedPricesP[nObservations],
                            double pricesP[nObservations],
                            unsigned hpK)
{
  const unsigned trace = 0;
  const unsigned debug = 0;

  // determine sum of squared errors for the test transactions and hpK
  double sumSquaredErrors = 0;
  unsigned nTestTransactions = 0;
  for (unsigned obsIndex = 0; obsIndex < nObservations; obsIndex++) {
    if (estimatedPricesP[obsIndex] == NULL)
      continue; // not in test set

    // for k = 0, 1, ..., hpK
    for (unsigned k = 0; k <= hpK; k++) { 
      const double estimate = estimatedPricesP[obsIndex][k];
      const double actual = pricesP[obsIndex];
      const double error = actual - estimate;
      sumSquaredErrors += error * error;
      nTestTransactions++;
      if (trace && debug)
	fprintf(stderr,
		"k %u obsIndex %u estimate %f actual %f\n"
                " error %f sumSquaredErrors %f\n",
		k, obsIndex, estimate, actual, error, sumSquaredErrors);
    }
  }

  // determine RMSE
  const double rmse = sqrt(sumSquaredErrors / nTestTransactions);
  if (trace)
    fprintf(stderr, 
            "determineRmse: rmse %f nTestTransactions %u\n", 
            rmse, nTestTransactions);

  return rmse;
}

////////////////////////////////////////////////////////////////////////////////
// makeResultsDirectory
////////////////////////////////////////////////////////////////////////////////

// return directory name using non-default parameters
// also create the directory in the file system, if it does not exist
static void
makeResultsDirectory(char                *directoryNameBuffer,
                     unsigned             bufLength,
                     struct paramsStruct *paramsP)
{
  char * me = "makeResultsDirectory";

  // create directory name
  const int outputLength = 
    snprintf(directoryNameBuffer, 
             bufLength,
             "../analysis/%s-cache%d-obs%c%c",
             PROGRAM_NAME, 
             paramsP->useCache,
             paramsP->obs[0], 
             paramsP->obs[1]);
  if (outputLength > (int) bufLength) {
    fprintf(stderr, "%s: buffer too small", me);
    exit(1);
  }

  // check if the directory already exists
  DIR *dir = opendir(directoryNameBuffer);
  if (dir != NULL) {
    // directory exists already, so close it
    closedir(dir);
    return;
  }

  // make the directory itself, if it didn't exist on the opendir call
  if (errno == ENOENT) {
    // permissions are read, write, execute for owner
    if (mkdir(directoryNameBuffer, S_IRWXU) != 0) {
      fprintf(stderr, "%s: unable to create directory=%s", 
              me, directoryNameBuffer);
      perror("");
      exit(1);
    }
  }
  else {
    perror("failure in opendir ");
    exit(1);
  }
} // end makeResultsDirectory

////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////

int
main (int argc, char** argv)
{
  // const char trace = 0;
  const unsigned debug = 0;
  const char *me = "main";

  const unsigned kMax = debug ? 10 : 256;

  // parse and validate the command line options
  struct paramsStruct params;
  parseCommandLine(argc, argv, &params);

  // create results directory in ANALYSIS directory
  // permissions are read, write for the owner
  char directoryName[256] = "";
  makeResultsDirectory(directoryName, 
                       sizeof(directoryName), 
                       &params);

  // start logging
  char logFilePath[256] = "";
  {
    const int outputLength =  snprintf(logFilePath, 
                                       sizeof(logFilePath), 
                                       "%s/run.log", 
                                       directoryName);
    if (outputLength > (int) sizeof(logFilePath)) {
      fprintf(stderr, "%s: logFilePath too small", me);
      exit(1);
    }
  }
  Log_T log = Log_new(logFilePath, stderr);

  // log the command line parameters
  LOG(log,"started log file %s\n", logFilePath);
  LOG(log,"params: obs=%s\n", params.obs); 
  LOG(log,"      : useCache=%s\n", params.useCache ? "yes" : "no");
  

  // Set number of observations to 
  // For now, just handle obs set 1A and 2R
  unsigned nObservations;
  unsigned nDimensions;
  unsigned nTestSet;
  if (strcmp(params.obs, "1A") == 0) {
    nObservations =  217376;
    nDimensions = 55;
    nTestSet = 77154;
  }
  else if (strcmp(params.obs, "2R") == 0) {
    nObservations = 1513786;
    nDimensions = 18;
    nTestSet = 556866;
  }
  else
    assert(0); // cannot happend

  double *actualPricesP = readPrices(nObservations);

  // allocate the 2D cache and initialize it
  // estimatedPricesP[i] = address of vector of estimated prices for obs i
    double ** estimatedPricesP = malloc(sizeof(double *) * nObservations);
  assert(estimatedPricesP);
  for (unsigned obsIndex = 0; obsIndex < nObservations; obsIndex++) {
      estimatedPricesP[obsIndex] = NULL;
  }


  if (params.useCache)
    estimatedPricesP =
      readCache(nObservations, params.obs, log, kMax, estimatedPricesP);

  // determine estimated prices for any missing entries in the cache
  // this operation could be fast or very slow
  // MAYBE: write out cache periodically 
  const unsigned cacheMutated = completeCache(nObservations, 
                                              nDimensions,
                                              nTestSet,
                                              estimatedPricesP, 
                                              params.obs, 
                                              log, 
                                              kMax, 
                                              actualPricesP, 
                                              debug);

  if (params.useCache && cacheMutated)
    writeCache(nObservations, estimatedPricesP, params.obs, log, kMax);


  // estimatedPricesP[i][k] is
  // the estimate priced of transaction indexed i for k nearest neighbors

  // for each value of k, determine RMSE overall all the test transactions
  // determine kArgMin, the k providing the lowest RMSE
  // write CSV containing <k, rmse> values
  char resultFilePath[256];
  {
    const int outputLength = 
      snprintf(resultFilePath,
               sizeof(resultFilePath),
               "%s/k-rmse.csv",
               directoryName);
    if (outputLength > (int) sizeof(resultFilePath)) {
      fprintf(stderr, "%s: resultFilePath too small", me);
      exit(1);
    }
    LOG(log, " result file path: %s\n", resultFilePath);
  }
  FILE *resultFile = fopen(resultFilePath, "w");
  assert(resultFile);

  // log best k for random sample of test observations
  bestK(0.01, nObservations, estimatedPricesP, actualPricesP, log, kMax);

  // write CSV header 
  fprintf(resultFile, "k,rmse\n");
  unsigned kArgMin = 0;
  double lowestRMSE = DBL_MAX;
  for (unsigned hpK = 0; hpK < kMax; hpK++) {

    // determine rmse for this k
    const double rmse = 
      determineRmse(nObservations, estimatedPricesP, actualPricesP, hpK);

    // check if we have a new best k
    LOG(log, "hpK %u rmse %f\n", hpK + 1, rmse);
    fprintf(resultFile, "%u,%f\n", hpK + 1, rmse);
    if (rmse < lowestRMSE) {
      lowestRMSE = rmse;
      kArgMin = hpK;
    }
  }

  // best k has been determined
  LOG(log, "kArgMin %u lowestRMSE %f\n", kArgMin + 1, lowestRMSE);
  LOG(log, "%s\n", "finished");

  exit(0);
}


