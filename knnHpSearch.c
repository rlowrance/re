// knnHpSearch.c
// determine RMSE on actual transactions in 2000, 2001, ..., 2009
// write these files:
// - ../analysis/knnHpSearch-OBS-K.txt      K,RMSE
// - ../analysis/knnHPSearch-log-OBS-K.txt  log file
// read these files:
// - features.csv
// - SALE-AMOUNT-log-std.csv
// - dates.csv

#define VERSION_MAJOR 0
#define VERSION_MINOR 1

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <getopt.h>

#include "Csv.h"
#include "halt.h"
#include "Knn.h"
#include "KnnCache.h"
#include "Log.h"
#include "visitTestTransactions.h"

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
  u("Determine RMSE for given K value. Usage:");
  u("  cd FEATURES && knnHpSearch parms > output/file");
  u("where");
  u("  FEATURES is a directory containing the input files");
  u("  FEATURES/features.csv is a file contain features");
  u("  FEATURES/dates.csv is a file containing dates");
  u("  FEATURES/SALE-AMOUNT-log-std.csv is a file containing sale prices");
  u("  FEATURES/knnCache.txt is a file contains a KnnCache");
  u(" ");
  u("Params:");
  u("");
  u(" --obs OBS   Observation set id; must be 1A for now");
  u(" --k K       Number of neighbors");

  u(" ");
  u("DESCRIPTION");
  u(" For every test transaction in 2000, 2001, ..., 2009, determine error using K");
  u(" Calculate RMSE using these transaction errors");
  u(" Write results to ../ANALYSIS/knnHpSearch-OBS-K.txt");

  u(" ");
  u("EXAMPLE");
  u(" cd obs1/features");
  u(" knnHpSearch --obs 1A --k 23");
  u("  write RMSE for k == 23");
  
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// process command line
////////////////////////////////////////////////////////////////////////////////

struct paramsStruct {
  char     obs[3];  // ex: "1A\0"
  unsigned k;
};

static void parseCommandLine(int argc, char **argv, struct paramsStruct *paramsP) {
  // initialize params to illegal values
  paramsP->obs[0] = ' ';
  paramsP->k = 0;
  struct option longOptions[] = {
    {"version", optional_argument, NULL, 'v'},  // a GNU standard long option
    {"help", optional_argument, NULL, 'h'},     // a GNU standard long option
    {"obs", required_argument, NULL, 'o'},
    {"k", required_argument, NULL, 'k'},
    {0, 0, 0, 0},                               // make end of long options defs
  };
  while (1) {
    int optionIndex = 0;
    int c = getopt_long(argc, argv, "", longOptions, &optionIndex); // no short options
    if (c == -1) break;  // detect end of options
    switch (c) {
    case 'v': // version 
      fprintf(stderr, "Version %u.%u compiled %s at %s\n",
              VERSION_MAJOR, VERSION_MINOR, __DATE__, __TIME__);
      break;
    case 'h': // help
      usage(NULL);
      break;
    case 'o': // obs
      // value is in char * optarg
      if (!strlen(optarg) == 2) usage("OBS must be 2 characters");
      if (strcmp(optarg, "1A")) usage("OBS must be 1A");
      strcpy(paramsP->obs, optarg);
      break;
    case 'k': // k
      {
        unsigned value;   // nested block needed to declare variables
        if (sscanf(optarg, "%u", &value) != 1) usage("K must be an unsigned positive int");
        if (value <= 0) usage("K is not positive");
        paramsP->k = value;
      }
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
  if (paramsP->k == 0)
    usage("--k is required");
  // check that no extra parameters were supplied
  if (optind < argc)
    usage("extra arguments on command line");
}

////////////////////////////////////////////////////////////////////////////////
// determineRMSE
////////////////////////////////////////////////////////////////////////////////

struct upValues {
  unsigned   numObservations;
  unsigned   numDimensions;
  unsigned   numNeighbors;
  unsigned   k;
  double    *featuresP;  // 2D array of size numObservations x numDimensions
  double    *pricesLogStdP;
  double     sumSquaredErrors;
  KnnCache_T cache;
  unsigned   numTransactionsVisited;
};

static int determineRMSE(void *dataP, unsigned transactionIndex) {
  const int trace = 0;
  struct upValues *uvP =  dataP;

  if (trace)
    fprintf(stderr, 
            "determineRMSE\n" 
            " numObservations  %u\n" 
            " numDimensions    %u\n" 
            " numNeighbors     %u\n" 
            " k                %u\n" 
            " featuresP        %p\n" 
            " pricesLogStdP    %p\n" 
            " sumSquaredErrors %f\n"
            " cache            %p\n"
            " queryIndex       %u\n", 
            uvP->numObservations,
            uvP->numDimensions,
            uvP->numNeighbors,
            uvP->k,
            (void*)uvP->featuresP,
            (void*)uvP->pricesLogStdP,
            uvP->sumSquaredErrors,
            (void*)uvP->cache,
            transactionIndex);

  assert(transactionIndex < uvP->numObservations);

  double estimate = Knn_reestimate_queryIndex(uvP->numObservations,
                                              uvP->numDimensions,
                                              uvP->featuresP,
                                              uvP->pricesLogStdP,
                                              uvP->k,
                                              transactionIndex,
                                              uvP->numNeighbors,
                                              uvP->cache);
  double actual = uvP->pricesLogStdP[transactionIndex];
  double error = actual - estimate;
  double squaredError = error * error;
  uvP->sumSquaredErrors += squaredError;
  uvP->numTransactionsVisited += 1;
  if (trace)
    fprintf(stderr, "determineRMSE: estimate %f actual %f error %f\n",
            estimate, actual, error);

  return 1; // 1 ==> the transaction was used
}


////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////

int
main (int argc, char** argv)
{
  const int trace = 1;
  const int debug = 0;

  // parse and validate the command line options
  struct paramsStruct params;
  parseCommandLine(argc, argv, &params);

  // print the options
  fprintf(stderr, "command line parameters\n");
  fprintf(stderr, "--obs: %s\n", params.obs);
  fprintf(stderr, "--k: %u\n", params.k);

  // start logging
  char logFilePath[128];
  snprintf(logFilePath, sizeof(logFilePath), "../analysis/knnHpSearch-obs%c%c-k%u.txt", 
	   params.obs[0], params.obs[1], params.k);
  Log_T log = Log_new(logFilePath, stderr);
  LOG(log,"started log file %s\n", logFilePath);
  LOG(log,"params: obs=%s k=%u\n", params.obs, params.k); 

  if (strcmp(params.obs, "1A") == 0) {
    // read the features
    // - allocate storage
    const unsigned numObservations = 217376;
    const unsigned numDimensions = 55; 
    const unsigned numNeighbors = 256;
    const unsigned numCacheEntries = 72455; 
    const unsigned expectHeader = 1;

    // read features
    double *featuresP = malloc(sizeof(double) * numObservations * numDimensions);
    if (!featuresP) 
      halt("unable to allocate features: %d x %d\n", numObservations, numDimensions);
    char * featuresHeader = 
      Csv_readDoubles("features.csv", expectHeader, numObservations, numDimensions, featuresP);
    free(featuresHeader);  //don't use the header

    // read dates
    double *datesP = malloc(sizeof(double) * numObservations);
    if (!datesP)
      halt("unable to allocate dates: %d\n", numObservations);
    char * datesHeader = 
      Csv_readDoubles("date.csv", expectHeader, numObservations, 1, datesP);
    free(datesHeader);     // don't use the header

    // - read prices
    double *pricesLogStdP = malloc(sizeof(double) * numObservations);
    if (!pricesLogStdP)
      halt("unable to allocate prices: %d\n", numObservations);
    char *pricesHeader =
      Csv_readDoubles("SALE-AMOUNT-log-std.csv", 
                      expectHeader, numObservations,1, pricesLogStdP);
    free(pricesHeader);

    // read cache
    double *cacheDiskP = malloc(sizeof(unsigned) * numObservations * (numNeighbors + 1));
    if (!cacheDiskP)
      halt("unable to allocate cache: %u x %u\n", numObservations, numNeighbors + 1);
    char *cacheDiskHeader = 
      Csv_readDoubles("knnCache.txt", 0, numCacheEntries, numNeighbors + 1, cacheDiskP);
    assert(cacheDiskHeader == NULL);  // no header in the csv cache file

    if (debug) { // print first row from file
      fprintf(stderr, "main: first row from knnCache.txt\n");
      for (unsigned i = 0; i < numNeighbors + 1; i++)
        fprintf(stderr, " row[%u] %f\n", i, cacheDiskP[i]);
    }
    
    // convert cache entries from disk to KnnCache_T
    const unsigned specialIndex = 0;
    KnnCache_T knnCache = KnnCache_new(numObservations);
    for (unsigned cacheEntryIndex = 0; cacheEntryIndex < numCacheEntries; cacheEntryIndex++) {
      // convert the double read from the file to unsigned values
      unsigned indices[numNeighbors];
      for (unsigned neighborIndex = 0; neighborIndex < numNeighbors; neighborIndex++) {
        indices[neighborIndex] = 
          (unsigned) *(cacheDiskP + cacheEntryIndex * numNeighbors + neighborIndex + 1);
        if (0 && debug && cacheEntryIndex == 0 )
          LOG(log, "cacheEntryIndex %u indices[%u]=%u %f\n",
              cacheEntryIndex, neighborIndex, indices[neighborIndex],
              *(cacheDiskP + cacheEntryIndex * numNeighbors + neighborIndex + 1));
      }
      if (trace && debug && cacheEntryIndex == specialIndex) {
        for (unsigned i = 0; i < numNeighbors; i++)
          fprintf(stderr, " indices[%u] %u\n", i, indices[i]);
      }
      unsigned key = (unsigned) cacheDiskP[cacheEntryIndex * (numNeighbors + 1)];
      if (debug && key == 2)
        fprintf(stderr, "main: key %u indices[0] %u\n", key, indices[0]);
      KnnCache_set(knnCache, key, numNeighbors, indices);
    }
    if (debug) {
      unsigned *neighborIndicesP = KnnCache_get(knnCache, 2U);
      assert(neighborIndicesP);
      fprintf(stderr, "prices[%u] %f price[neighborIndicesP[0]] %f\n",
              2U, pricesLogStdP[2], pricesLogStdP[neighborIndicesP[0]]);
    }


    free(cacheDiskP); // no longer needed as all info is in the cache
     


    // determine RMSE for 
    struct upValues uv;
    uv.numObservations = numObservations;
    uv.numDimensions = numDimensions;
    uv.featuresP =  featuresP;
    uv.pricesLogStdP = pricesLogStdP;
    uv.k = params.k;
    uv.sumSquaredErrors = 0.0;
    uv.numNeighbors = numNeighbors;
    uv.cache = knnCache;
    uv.numTransactionsVisited = 0;
    
    static int logVisitTimes = 0;
    visitTestTransactions(logVisitTimes ? log : NULL, 
                          numObservations, 
                          datesP, 
                          determineRMSE, 
                          &uv);
    double rmse = sqrt(uv.sumSquaredErrors / uv.numTransactionsVisited);
    LOG(log, "sumSquaredErrors %f\n", uv.sumSquaredErrors);
    LOG(log, "numTransactionsVisited %u\n", uv.numTransactionsVisited);
    LOG(log, "rmse %f\n", rmse);
    // write stdout
    fprintf(stdout, "%03u,%f\n", uv.k, rmse);
  }

  else
    halt("params.obs value");

  LOG(log, "%s\n", "finished");
  exit(0);


}


