// glibSpecializations.h
// headers for glibSpecialization.c

// ArrayD overview
#if 0
// creating
ArrayD *a = arrayDNew();
arrayDUnref(ArrayD *a);

// mutating
/arrayDAppend(ArrayD *a, double value);

// inquiring
double value =  arrayDIndex(const ArrayD *a, guint index);
guint size =  arrayDSize(const ArrayD *a);
arrayDPrint(const ArrayD *a);

// unit testing
arrayDUnitTest();
#endif

// ArrayS overview
#if 0
// creating
ArrayS *a = arraySNew();
arraySUnref(ArrayS *a);

// mutating
arraySAppend(ArrayS *a, const char *value);

// inquiring
char * value = arraySIndex(const ArrayS *a, guint index);
guint size = arraySSize(const ArrayS *a);

// unit testing
arraySUnitTest();
#endif

// HashDD overview
#if 0
// creating
HashDD *h = hashDDNew();
hashDDUnref(HashDD *h)

// mutating
hashDDInsert(HashDD *h, double key, double value);

// inquiring
HashDDLookup result = hashDDLookup(const hashDD *h, double key);
if (result.found) use(result.value)

// iterating
HashDDIter iter;
hashDDIterInit(const hashDD *h, &iter);
double key;
double value;
while (hashDDIterNext(iter, &key, &value) use(key,value);

// unit testing
       hashDDUnitTest();
#endif

#ifndef GLIBSPECIALIZATIONS_H
#define GLIBSPECIALIZATION_H

#include <glib.h>

////////////////////////////////////////////////////////////////////////////////
// ArrayD: array of doubles
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GArray *gArray;
} ArrayD;

ArrayD* arrayDNew();
void    arrayDUnref(ArrayD *a);

void    arrayDAppend(ArrayD *a, double value);
double  arrayDIndex(const ArrayD *a, guint index);
guint   arrayDSize(const ArrayD *a);

void    arrayDPrint(const ArrayD *a);

void    arrayDUnitTest();

////////////////////////////////////////////////////////////////////////////////
// ArrayS: array of c strings
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GArray *gArray;
} ArrayS;

ArrayS* arraySNew();
void    arraySUnref(ArrayS* a);

void    arraySAppend(ArrayS* a, const char *value);
char*   arraySIndex(const ArrayS* a, guint index);
guint   arraySSize(const ArrayS *a);

void    arraySUnitTest();

////////////////////////////////////////////////////////////////////////////////
// HashDD: hash table with key = double, value = double
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GHashTable *gHashTable;
} HashDD;

typedef struct {
  unsigned found;
  double   value;
} HashDDLookup;

typedef GHashTableIter HashDDIter;

HashDD*       hashDDNew();
void          hashDDUnref(HashDD *h);

void          hashDDInsert(HashDD* h, double key, double value);
HashDDLookup  hashDDLookup(const HashDD *h, double key);

void          hashDDIterInit(const HashDD *h, HashDDIter *iter);
gboolean      hashDDIterNext(HashDDIter *iter, 
                                    double *key, 
                                    double *value);

void          hashDDUnitTest(); // unit test


#endif
