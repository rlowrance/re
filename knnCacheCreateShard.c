// knnCacheCreateShard.c
// filter to features csv file and write a shard containing a portion of a cache
// The cache the nearest 256 neighbor indices

// Command Line Interface
// --version
// --help
// 


#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include <getopt.h>

#include "Csv.h"
#include "halt.h"
#include "Knn.h"
#include "Log.h"
#include "visitTestTransactions.h"

////////////////////////////////////////////////////////////////////////////////
// report user errors
////////////////////////////////////////////////////////////////////////////////

// write line to standard error followed by newline
void u(char* line)
{
  fputs(line, stderr);
  fputs("\n", stderr);
}

void usage(char* msg) {
  if (msg) {
    printf("\nCommand line error: %s\n", msg);
  }

  u("");
  u("Read features.csv and write a shard of a knn cache to stdout. Usage:");
  u("  cd FEATURES && knnCacheCreateShard params > output/file");
  u("where");
  u("  FEATURES is a directory containing the input file features.csv");
  u("  features.csv is a file in CSV format that contains a header");
  u("     all features are used, the header is ignored but required");
  u(" ");
  u("Params:");
  u("");
  u(" --obs OBS   Observation set id; must be 1A for now");
  u(" --shared N  Number of shard to create; must be in 1, 2, ..., 100");

  u(" ");
  u("DESCRIPTION");
  u(" For every test transaction in SHARD, determine distance to all other features");
  u(" Write output file with the indices of the nearest 256 neighbors.");
  u(" The test transactions are those in years 2000, ..., 2009");
  u(" Run knnCacheMergeShards to merge the 100 shard files into one big cache file");

  u(" ");
  u("EXAMPLE");
  u(" cd obs1/features");
  u(" knnCacheCreateShard --obs 1A --shard 23 > shard-23.txt");
  u("  Creates shard 23");
  
  exit(1);
}

// format an userError message and write it
void userErrorInt(char *format, int var)
{
  char userErrorMsg[1000];
  sprintf(userErrorMsg, format, var);
  usage(userErrorMsg);
}

void userErrorIntIntInt(char *format, int var1, int var2, int var3)
{
  char userErrorMsg[1000];
  sprintf(userErrorMsg, format, var1, var2, var3);
  usage(userErrorMsg);
}

// format an userError message and write it
void userErrorString(char *format, char *var)
{
  char userErrorMsg[1000];
  sprintf(userErrorMsg, format, var);
  usage(userErrorMsg);
}

////////////////////////////////////////////////////////////////////////////////
// command line processing
////////////////////////////////////////////////////////////////////////////////

struct optionsStruct {
  char obs[3];  // ex: "1A" followed by '\0'
  unsigned shard;
};


// read command line options and set values in options
// ref: http://www.gnu.org/software/libc/manual/html_node/Getopt-Long-Options.html#Getopt-Long-Options
void parseCommandLine(int argc, char **argv, struct optionsStruct *optionsP) {
  struct option longOptions[] = {
    {"version", optional_argument, NULL, 'v'},  // a GNU standard long option
    {"help", optional_argument, NULL, 'h'},     // a GNU standard long option
    {"obs", required_argument, NULL, 'o'},
    {"shard", required_argument, NULL, 's'},
    {0, 0, 0, 0},                               // make end of long options defs
  };
  while (1) {
    int optionIndex = 0;
    int c = getopt_long(argc, argv, "", longOptions, &optionIndex); // no short options
    if (c == -1) break;  // detect end of options
    switch (c) {
    case 'v': // version 
      fprintf(stderr, "version 1");
      break;
    case 'h': // help
      usage(NULL);
      break;
    case 'o': // obs
      // value is in char * optarg
      if (!strlen(optarg) == 2) usage("OBS must be 2 characters");
      if (strcmp(optarg, "1A")) usage("OBS must be 1A");
      strcpy(optionsP->obs, optarg);
      break;
    case 's': // shard
      {
        unsigned value;   // nested block needed to declare variables
        if (sscanf(optarg, "%u", &value) != 1) usage("SHARD must be an unsigned int");
        optionsP->shard = value;
      }
      break;
    case '?': // getopt_long already printed error message
      break;
    default:
      fprintf(stderr, "getopt_long returned unexcepted value");
      abort();
    }
  }
  if (optind < argc)
    usage("extra arguments on command line");
}

void
parseCommandLineOLD(int argc, char **argv, struct optionsStruct *optionsP)
{
  const int trace = 1;

  // set un-allowed values for required options to enable later checking that
  // they were supplied
  strcpy(optionsP -> obs, "  ");
  optionsP -> shard = 0;
  
  // read each option
  int index = 1;
  while (index < argc) {
    if (trace) fprintf(stderr, "option arg[index] %s\n", argv[index]);

    if (strcmp(argv[index], "--obs") == 0) {
      if (!strlen(argv[index]) == 2)
        usage("OBS must be 2 characters");
      index++;
      if (index > argc) usage("missing option value for --obs");
      strcpy(optionsP -> obs, argv[index]);
      if (trace) fprintf(stderr, "options.obs %s\n", optionsP -> obs);
      if (strcmp(optionsP -> obs, "1A"))
        usage("OBS not 1A");
      index++;
    }

    else if (strcmp(argv[index], "--shard") == 0) {
      index++;
      if (index > argc) usage("missing option value for --shard");
      unsigned value;
      if (argv[index] == 0 || sscanf(argv[index], "%u", &value) != 1)
        usage("SHARD is not an unsigned integer");
      optionsP -> shard = value;
      if (trace) fprintf(stderr, "options.shard %u\n", optionsP -> shard);
      if (optionsP -> shard < 1 || optionsP -> shard > 100)
        usage("SHARD not integer between 1 and 100");
      index++;
    }
    
    else
      userErrorString("unknown option %s", argv[index]);
  }


  // check that required options were actually supplied
  if (strcmp(optionsP -> obs, "  ") == 0) usage("--obs option not supplied");
  if (optionsP -> shard == 0)             usage("--shard option not supplied");
  
}

////////////////////////////////////////////////////////////////////////////////
// compute the 256 nearest neighbors to the query point in the features array
////////////////////////////////////////////////////////////////////////////////

// max shard size is 1% of the max number of test transactions
// the max number of test transaction is bounded above by 1.3 million
#define NUMBER_SHARDS 100

struct upValues {
  unsigned numObservations;
  unsigned numDimensions;
  unsigned shardCounter;
  unsigned desiredShard;
  double *featuresP;  // 2D array of size numObservations x numDimensions
  // access the element at i,j via
  // *(featuresP + i * numDimensions + j)
  // ref: http://www.dfstermole.net/OAC/harray2.html
};


// Determine nearest neighbors, if the queryIndex is in the shard
// If in shard, write nearest neighbor indices and queryIndex to stdout
// Return 1 if in shard, 0 if not in shard
// timing notes:
// One run (without writing to stdout) takes 0.11 CPU secs on isolde
// Must run this code 220,000 / 5 * 2 = 88,000 times
// This will take 88,000 * 0.11 = 9,680 CPU seconds = 161 CPU minutes = 2.7 CPU hours.
int compute256NearestNeighbors(void *argDataP, unsigned queryIndex)
{
  //const int debug = 0;        // if true, print debugging output to stderr
  const int cpuTime = 0;      // if true, print elapsed CPU time to stderr
  const int writeOutput = 1;  // if true, write the nearest neighbor indices to stdout
  clock_t startClocks = clock();
  
  struct upValues *dataP = (void*) argDataP;
  // determine if the queryIndex is in this shard
  dataP->shardCounter++;
  if (dataP->shardCounter > NUMBER_SHARDS) dataP ->shardCounter = 1;
  if (dataP->shardCounter != dataP ->desiredShard)
    return 0;  // we are not creating the shard numbered dataP ->sharedCounter

  // determine indices of nearest 256 neighbors
  const unsigned numNeighbors = 256;
  unsigned indicesP[numNeighbors];
  Knn_nearest_indices(dataP->numObservations,
                      dataP->numDimensions,
                      dataP->featuresP,
                      numNeighbors,
                      indicesP,
                      queryIndex);

  // write indices of nearest 256 neighbors to stdout
  if (writeOutput) {
    fprintf(stdout, "%i,", queryIndex);
    for (unsigned neighborIndex = 0; neighborIndex < numNeighbors; neighborIndex++) {
      if (neighborIndex != numNeighbors - 1)
	fprintf(stdout, "%i,", indicesP[neighborIndex]);
      else
	fprintf(stdout, "%i\n", indicesP[neighborIndex]);
    }
  }
  if (cpuTime) fprintf(stderr, 
                       "Found 256 nearest neighbors among %u in %f CPU secs\n",
                       dataP->numObservations,
		       (double)(clock() - startClocks)/ CLOCKS_PER_SEC);
  return 1; // say was in shard
}


////////////////////////////////////////////////////////////////////////////////
// main program
////////////////////////////////////////////////////////////////////////////////


int
main (int argc, char** argv)
{
  //const int trace = 1;

  // parse and validate the command line options
  struct optionsStruct options;
  parseCommandLine(argc, argv, &options);

  // print the options
  fprintf(stderr, "command line options\n");
  fprintf(stderr, "--obs: %s\n", options.obs);
  fprintf(stderr, "--shard: %u\n", options.shard);

  // start logging
  char logFilePath[128];
  snprintf(logFilePath, 
           sizeof(logFilePath), 
           "knnCacheCreateShard-obs%c%c-shard%u.txt", 
	   options.obs[0], options.obs[1], options.shard);
  Log_T log = Log_new(logFilePath, stderr);
  LOG(log,"started log file %s\n", logFilePath);
  LOG(log,"options: obs=%s shard=%u\n", options.obs, options.shard); 

  if (strcmp(options.obs, "1A") == 0) {
    // read the features
    // - allocate storage
    const unsigned numObservations = 217376;
    const unsigned numDimensions = 55; 
    double *featuresP = 
      malloc(numObservations * numDimensions * sizeof(double));
    if (!featuresP) 
      halt("unable to allocate features: %d x %d\n", 
           numObservations, numDimensions);

    // - read header and data; discard header
    static const unsigned expectHeader = 1;
    // ignore the header on the features file (creates a memory leak)
    char * featuresHeader = 
      Csv_readDoubles("features.csv", expectHeader,
                      numObservations, numDimensions, featuresP);
    free(featuresHeader);

    // read the dates
    // - allocate storage
    double *datesP = malloc(numObservations * sizeof(double));
    
    // - read header and data; discard header
    char * datesHeader = 
      Csv_readDoubles("date.csv", expectHeader, numObservations, 1, datesP);
    free(datesHeader);

    // determine nearest 256 neighbors and write to stdout
    struct upValues data;
    data.numObservations = numObservations;
    data.numDimensions = numDimensions;
    data.shardCounter = 0;
    data.desiredShard = options.shard;
    data.featuresP =  featuresP;
    visitTestTransactions(log, numObservations, datesP, compute256NearestNeighbors, &data);
  }

  else
    halt("options.obs value");

  LOG(log, "%s\n", "finished");
  exit(0);


}
