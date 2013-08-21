// visitTestTransactions.h

#include "Log.h"

void visitTestTransactions(Log_T log,                        // if NULL, don't write to log
			   unsigned numTransactions,
			   double dates[numTransactions], 
			   int (*visit)(void *data, unsigned transactionIndex), 
			   void *data);
