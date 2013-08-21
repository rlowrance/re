// visitTestTransactions.c
// apply a function to each transaction

#include <stdio.h>
#include <time.h>

#include "Log.h"
#include "visitTestTransactions.h"

void visitTestTransactions(Log_T log,
			   unsigned numTransactions,
			   double dates[numTransactions], 
			   int (*visit)(void *data, unsigned transactionIndex), 
			   void *data)
{
  time_t startTime = time(NULL);
  unsigned numVisited = 0;
  for (unsigned transactionIndex = 0; transactionIndex < numTransactions; transactionIndex++) {
    double year = dates[transactionIndex] / 10000.0;
    if (2000.0 <= year && year <= 2009.0) {
      // maybe determine and write nearest 256 neighbors
      if (visit(data, transactionIndex)) {
        // here if transactionIndex was in the shard

        // keep track of wall clock time
        numVisited++;
        double elapsedTime = difftime(time(NULL), startTime);
        const unsigned reportingFrequency = 100;
        if (log != NULL && (numVisited % reportingFrequency) == 0) {
            LOG(log,
                "transactionIndex %u of %u "
                "after %f wall clock %f visited %u avg wall clock %f\n",
                transactionIndex, numTransactions, 
                elapsedTime, numVisited, elapsedTime / numVisited);
        }
      }
    } // end code to keep track of time if transactionIndex in shard 
  } // loop over transactionIndex
}
