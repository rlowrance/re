// createEstimates.c
// create either the Laufer estimates or the Matrix Completion Estimates

// Files read:

// Filew written:


#define VERSION_MAJOR 0
#define VERSION_MINOR 1
#define PROGRAM_NAME "knnEstimates.c"

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
#include "daysPastEpoch.h"
#include "halt.h"
#include "Log.h"
#include "Random.h"
#include "SetDouble.h"

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
  u("Create estimates, both for the Laufer comparison and for matrix completion");
  u(" ");
  u("Usage example:");
  u(" cd BUILD_DIRECTORY");
  u(" ./createEstimates PARAMS");
  u("where PARAMS are required:");
  u("--algo ALGO  for now, just knn");
  u("--obs  OBS   for now, just 1A");
  u("--radius INT");
  u("--which WHICH one of {laufer, mc}");
  u(" ");
  u("Files written:");
  u(" ANALYSIS/EXPERIMENT/estimates.csv with fields apn,date,radius,estimate");
  u(" ANALYSIS/EXPERIMENT/log.txt");
  u(" ");
  u("Files read:");
  u(" FEATURES/apn.csv");
  u(" FEATURES/SALE-AMOUNT-log.csv");
  u(" FEATURES/features.csv  the day column is recomputed and replaced used dates.csv");
  u(" FEATURES/dates.csv");
  u(" ");
  
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// process command line
////////////////////////////////////////////////////////////////////////////////

struct paramsStruct {
  char     *algo;  
  char     *obs;   
  unsigned  radius;
  char     *which;
};

static void 
parseCommandLine(int argc, char **argv, struct paramsStruct *paramsP) 
{
  // initialize params to illegal values or default values
  paramsP->algo   = NULL;
  paramsP->obs    = NULL;
  paramsP->radius = 0;
  paramsP->which  = NULL;

  // define the command line paramters
  struct option longOptions[] = {
    {"version", optional_argument, NULL, 'v'},  // a GNU standard long option
    {"help",    optional_argument, NULL, 'h'},  // a GNU standard long option
    {"algo",    required_argument, NULL, 'a'},
    {"obs",     required_argument, NULL, 'o'},
    {"radius",  required_argument, NULL, 'r'},
    {"which",   required_argument, NULL, 'w'},
    {0, 0, 0, 0},                               // mark end of long options defs
  };
  while (1) {
    int optionIndex = 0;
    // no short options
    int c = getopt_long(argc, argv, "", longOptions, &optionIndex);
    if (c == -1) break;  // detect end of options
    char *endPtr;
    long valueLong;
    const int base = 10;
    switch (c) {
    case 'v': // version 
      fprintf(stderr, "Version %u.%u compiled %s at %s\n",
              VERSION_MAJOR, VERSION_MINOR, __DATE__, __TIME__);
      break;
    case 'h': // help
      usage(NULL);
      break;
    case 'a': // --algo knn
      if (!strcmp(optarg, "knn")) usage("ALGO must be knn");
      strcpy(paramsP->algo, optarg);
      break;
    case 'o': // --obs OBS
      // value is in char * optarg
      if (!strcmp(optarg, "1A")) usage("OBS must be 1A");
      strcpy(paramsP->obs, optarg);
      break;
    case 'r': // --radius INT
      valueLong = strtol(optarg, &endPtr, base);
      if (*endPtr != '\0')  usage("INT must be an integer");
      if (valueLong <= 0)   usage("INT must be positive");
      paramsP->radius = (unsigned) valueLong;
      break;
    case 'w': // --which WHICH
      if (!strcmp(optarg, "laufer")) usage("WHICH must be laufer"); 
      strcpy(paramsP->which, optarg);
      break;
    case '?': // getopt_long already printed error message
      break;
    default:
      fprintf(stderr, "getopt_long returned unexpected value");
      abort();
    }
  }

  // check if required parameters were supplied
  if (paramsP->algo   == NULL) usage("--algo is required");
  if (paramsP->obs    == NULL) usage("--obs is required");
  if (paramsP->radius == 0)    usage("--radius is required");
  if (paramsP->which  == NULL) usage("--which is required");

  // check that no extra parameters were supplied
  if (optind < argc)
    usage("extra arguments on command line");
}


////////////////////////////////////////////////////////////////////////////////
// feadFeatures
////////////////////////////////////////////////////////////////////////////////

// return pointer to 2D array of feature values from disk
static double *readFeatures(unsigned   nObservations, 
			    unsigned   nDimensions,
			    char     **headerP) 
{
  double *featuresP = malloc(sizeof(double) * nObservations * nDimensions);
  if (!featuresP) 
    halt("unable to allocate features: %u x %u\n", nObservations, nDimensions);
  const unsigned expectHeader = 1;
  char *headerBuffer = 
    Csv_readDoubles("features.csv", expectHeader, nObservations, nDimensions, 
                    featuresP);
  *headerP = headerBuffer;  // caller should free the buffer
  return featuresP;
}

////////////////////////////////////////////////////////////////////////////////
// readCsvNoHeader
////////////////////////////////////////////////////////////////////////////////

static double * readCsvNoHeader(unsigned nObservations, char *fileName)
{
  double *dataP = malloc(sizeof(double) * nObservations);
  if (!dataP)
    halt("unable to allocate data: %u\n", nObservations);
  const unsigned expectHeader = 1;
  char * dataHeader = 
    Csv_readDoubles(fileName, expectHeader, nObservations, 1, dataP);
  free(dataHeader);     // don't use the header
  return dataP;
}

////////////////////////////////////////////////////////////////////////////////
// makeResultsDirectory
////////////////////////////////////////////////////////////////////////////////

// return directory name using non-default parameters
// also create the directory in the file system, if it does not exist
static void
makeResultsDirectory(char                *directoryNameBuffer,
                     size_t               bufLength,
                     struct paramsStruct *paramsP)
{
  char *me = "makeResultsDirectory";

  // create directory name
  const int outputLength = 
    snprintf(directoryNameBuffer, 
             bufLength,
             "../analysis/%s-algo=%s-obs=%s-radius=%d-which=%s",
             PROGRAM_NAME, 
             paramsP->algo,
             paramsP->obs, 
             paramsP->radius,
	     paramsP->which);
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
      fprintf(stderr, "%s: unable to create directory", me);
      perror("");
      exit(1);
    }
  }
  else {
    perror("failure in opendir ");
    exit(1);
  }
}

////////////////////////////////////////////////////////////////////////////////
// columnHeaderEqual
////////////////////////////////////////////////////////////////////////////////

// verify that a column header from a CSV file contains the expected value
static unsigned columnHeaderEqual(char *header, unsigned columnIndex, char *expected)
{
  // assume the separator is a comma and no quoting of fields is done
  for (unsigned skippedCommas = 0; skippedCommas == columnIndex - 1; skippedCommas++) {
    while (1) {
      if (*header == ',') break;
      header++;
    }
  }

  header++; // skip past last ,
  while (*header == ' ') 
    header++;  // skip white space

  while (expected != '\0') {
    if (*expected != *header)
      return 0; // false, as column header differs from expected
    expected++;
    header++;
  }
  
  return 1; // true
}

////////////////////////////////////////////////////////////////////////////////
// convertDatesToDays
////////////////////////////////////////////////////////////////////////////////

static   double *convertDatesToDays(unsigned nObservations, double *dates)
{
  double *days = malloc(sizeof(double) * nObservations);
  assert(days);
  for (unsigned i = 0; i < nObservations; i++) {
    days[i] = daysPastEpoch(dates[i]);
  }
  return days;
}

////////////////////////////////////////////////////////////////////////////////
// standardize
////////////////////////////////////////////////////////////////////////////////

static double * standardize(unsigned n, double *numbers, double mean, double stdv)
{
  double *results = malloc(sizeof(double) * n);
  assert(results);
  for (unsigned i = 0; i < n; i++) {
    results[i] = (numbers[i] - mean) / stdv;
  }
  return results;
}

////////////////////////////////////////////////////////////////////////////////
// replaceDay
////////////////////////////////////////////////////////////////////////////////

static void replaceDay(unsigned nObservations, unsigned nFeatures,
		       double *features, double* days,
		       unsigned dayStdColumn)
{
  for (unsigned i = 0; i < nObservations; i++) {
    *(features + i * nFeatures + dayStdColumn) = *(days + i);
  }
}

////////////////////////////////////////////////////////////////////////////////
// determineMeanStd
////////////////////////////////////////////////////////////////////////////////

static void determineMeanStdv(unsigned n, double *numbers, double *meanP, double *stdvP)
{
  assert(n > 0);
  assert(numbers);
  assert(meanP);
  assert(stdvP);

  double sum;
  for (unsigned i = 0; i < n; i++) {
    sum += numbers[i];
  }
  
  double mean = sum / n;

  double sumSquaredDiff = 0;
  for (unsigned i = 0; i < n; i++) {
    const double diff = numbers[i] - mean;
    sumSquaredDiff += diff * diff;
  }

  double stdv = sqrt(sumSquaredDiff / n);

  *meanP = mean;
  *stdvP = stdv;
}

////////////////////////////////////////////////////////////////////////////////
// createLaufer
////////////////////////////////////////////////////////////////////////////////

static void createLaufer(unsigned nObservations, 
                         unsigned nFeatures,
			 double *apns, 
                         double *dates, 
                         double *features, 
                         double *prices,
			 Log_T log, 
                         FILE *resultFile)
{
  const unsigned trace = 1;
  const char *me = "createLaufer";

  fprintf(resultFile, "apn,date,radius,estimate\n");
  
  SetDouble_T apnsEstimated = SetDouble_new(200000);
  assert(apnsEstimated);

  for (unsigned apnIndex; apnIndex < nObservations; apnIndex++) {
    double apn = apns[apnIndex];
    if (SetDouble_contains(apnsEstimated, apn)) {
      if (trace) 
        fprintf(stderr, "%s: apn %f already seen\n", me, apn);
      continue;
    }
    if (trace)
      fprintf(stderr, "%s: create estimate for apn %f\n", me, apn);
    SetDouble_insert(apnsEstimated, apn);
    // TODO: actually create and write the estimate
  }

}

////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////


int
main (int argc, char** argv)
{
  // const char trace = 0;
  // const unsigned debug = 0;
  const char *me = "main";

  // parse and validate the command line options
  struct paramsStruct params;
  parseCommandLine(argc, argv, &params);

  // create results directory in ANALYSIS directory
  // permissions are read, write for the owner
  char resultsDirectoryName[256] = "";
  makeResultsDirectory(resultsDirectoryName, 
                       sizeof(resultsDirectoryName), 
                       &params);

  // start logging
  char logFilePath[256] = "";
  {
    const int outputLength =  snprintf(logFilePath, 
                                       sizeof(logFilePath), 
                                       "%s/run.log", 
                                       resultsDirectoryName);
    if (outputLength > (int) sizeof(logFilePath)) {
      fprintf(stderr, "%s: logFilePath too small", me);
      exit(1);
    }
  }
  Log_T log = Log_new(logFilePath, stderr);

  // log the command line parameters
  LOG(log,"started log file %s\n", logFilePath);

  LOG(log,"params: algo=%s\n",          params.algo);
  LOG(log,"      : obs=%s\n",           params.obs); 
  LOG(log,"      : radius=%d\n",        params.radius);
  LOG(log,"      : which=%s\n",         params.which);
  
  // check the command line parameters
  assert(strcmp(params.algo, "knn") == 0); 
  assert(strcmp(params.obs, "1A") == 0);
 
  // read the input files
  const unsigned nObservations = 217376;  // adjust of OBS != 1A
  const unsigned nFeatures = 55;

  double *apns = readCsvNoHeader(nObservations, "aps.csv");
  double *dates = readCsvNoHeader(nObservations, "date.csv");
  char   *featuresHeaderP;
  double *features = readFeatures(nObservations, 
				  nFeatures,
				  &featuresHeaderP);
  double *prices = readCsvNoHeader(nObservations, "SALE-AMOUNT-log.csv");

  // convert dates to days past the epoch
  unsigned dayStdColumn = 5; // the 6th column contains the standardized day value
  assert(columnHeaderEqual(featuresHeaderP, dayStdColumn, "day-std"));  
  double *days = convertDatesToDays(nObservations, dates);
  free(dates);
  double mean;
  double stdv;
  determineMeanStdv(nObservations, days, &mean, &stdv);
  double *daysStd = standardize(nObservations, days, mean, stdv);
  replaceDay(nObservations, nFeatures, features, daysStd, dayStdColumn);
  free(days);
  free(daysStd);


  // generate one set of estimates
  FILE *resultFile;
  {
    char resultFilePath[256];
    const int outputLength = 
      snprintf(resultFilePath,
               sizeof(resultFilePath),
               "%s/estimates-laufer.csv",
               resultsDirectoryName);
    if (outputLength > (int) sizeof(resultFilePath)) {
      fprintf(stderr, "%s: resultFilePath too small", me);
      exit(1);
    }
    LOG(log, " result file path: %s\n", resultFilePath);
    resultFile = fopen(resultFilePath, "w");
  }
  assert(resultFile);

  if (strcmp(params.which, "laufer"))
    createLaufer(nObservations, nFeatures, 
		 apns, dates, features, prices,
		 log,
		 resultFile);
  else
    assert(NULL != "logic error");

  // OLD CODE BELOW THIS LINE
#if 0
  double **pricesHatP = NULL;
  if (params.useCache)
    pricesHatP = readCache(nObservations, params.obs, log, kMax);

  // determine estimated prices for any missing entries in the cache
  // this operation could be fast or very slow
  // MAYBE: write out cache periodically 
  const unsigned cacheMutated = completeCache(nObservations, 
                                              pricesHatP, 
                                              params.obs, 
                                              log, 
                                              kMax, 
                                              pricesP, 
                                              debug);

  if (params.useCache && cacheMutated)
    writeCache(nObservations, pricesHatP, params.obs, log, kMax);


  // select which set of estimates to create
  if (paramsP->whichIsLaufer)
    createEstimatesLaufer(nObservations, nFeatures,
			  features, dates, prices);
  else
    assert(false); // should never get here

  // pricesHatP[i][k] is
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
  bestK(0.01, nObservations, pricesHatP, pricesP, log, kMax);

  // write CSV header 
  fprintf(resultFile, "k,rmse\n");
  unsigned kArgMin = 0;
  double lowestRMSE = DBL_MAX;
  for (unsigned hpK = 0; hpK < kMax; hpK++) {

    // determine rmse for this k
    const double rmse = determineRmse(nObservations, pricesHatP, pricesP, hpK);

    // check if we have a new best k
    LOG(log, "hpK %u rmse %f\n", hpK + 1, rmse);
    fprintf(resultFile, "%u,%f\n", hpK + 1, rmse);
    if (rmse < lowestRMSE) {
      lowestRMSE = rmse;
      kArgMin = hpK;
    }
  }

#endif
  // 
  LOG(log, "%s\n", "finished");

  exit(0);
}


