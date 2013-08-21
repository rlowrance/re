// glibSpecializations.c
// specialize some glib types:
// - arrayD: array of double
// - arrayS: array of string
// - hashDD: hash with key in double and value in double


#include "all-headers.h"



#if 0
////////////////////////////////////////////////////////////////////////////////
// HashIS: hash table with key = int, value = string
////////////////////////////////////////////////////////////////////////////////
  
typedef struct {
  GHashTable *gHashTable;
} HashIS;

typedef struct {
  unsigned  found;
  char     *value;
} HashISLookup;

static HashIS*  hashISNew();
static void     hashISUnref(HashIS *h);

static void     hashISInsert(HashIS *h, gint key, const char* value);
static HashISLookup hashISLookup(const HashIS *h, gint key);

////////////////////////////////////////////////////////////////////////////////
// HashSI: hash table with key = string, value = int
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GHashTable *gHashTable;
} HashSI; 

typedef struct { // value returned by HashSILookup
  unsigned found; // 1 or 0
  gint     value;
} HashSILookup;

static HashSI*      hashSINew(); //key=string value=gint (32 bits, signed)
static void         hashSIUnref(HashSI *h);

static void         hashSIInsert(HashSI *h, const char *key, gint value);
static HashSILookup hashSILookup(const HashSI *h, const char *key);
static void         hashSIPrint(const HashSI *h);
static guint        hashSISize(const HashSI *h);

static void         hashSITest();   // unit test

////////////////////////////////////////////////////////////////////////////////
// SetI: set of gints
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GHashTable *gHashTable;
} SetI;

static SetI*    setINew();
static void     setIUnref(SetI *s);

static void     setIAdd(SetI *s, gint element);
static gboolean setIContains(const SetI *s, gint element);
static SetI*    setICopy(const SetI *s);
static void     setIPrint(const SetI *s);
static gboolean setIRemove(SetI *s, gint element);
static guint    setISize(const SetI *s);

typedef GHashTableIter SetIIter;
static void      setIIterInit(const SetI *s, SetIIter *iter);
static gboolean  setIIterNext(SetIIter *iter, gint *element);

static void      setITest(); // unit test
#endif

////////////////////////////////////////////////////////////////////////////////
// ArrayD
////////////////////////////////////////////////////////////////////////////////

/**
Allocate new array of double
*/
ArrayD * arrayDNew() {
  ArrayD *a = malloc(sizeof(ArrayD));
  assert(a);
  a->gArray = g_array_new(0, // not zero terminated
                          1, // clear elements to zero when allocated
                          sizeof(double)); // element size
  assert(a->gArray);
  return a;
} // arrayDNew

/**
Reduce reference count, possibly freeing
*/
void arrayDUnref(ArrayD *a) {
  assert(a);
  g_array_unref(a->gArray);
  free(a);
} // arraySUnref

/**
Append double value
*/
void arrayDAppend(ArrayD *a, double value) {
  assert(a);
  // the macro call below determines the element size
  g_array_append_val(a->gArray, value);
} // arrayDAppend

/**
Return double value at index
*/
double arrayDIndex(const ArrayD *a, unsigned index) {
  assert(a);
  return g_array_index(a->gArray, double, index);
} // arrayDIndex


/**
Return number of elements in array
*/
guint arrayDSize(const ArrayD *a) {
  assert(a);
  return a->gArray->len;
} // arrayDSize

/**
Print on stdout
*/
void arrayDPrint(const ArrayD *a) {
  assert(a);
  printf("(ArrayD @%p)= ", a);
  for (unsigned i = 0; i < arrayDSize(a); i++) {
    printf(" %g", arrayDIndex(a, i));
  }
  printf("\n");
} // arrayDPrint

/**
Unit tests for ArrayD
*/
void arrayDUnitTest() {
  ArrayD *a = arrayDNew();
  assert(0 == arrayDSize(a));
  
  arrayDAppend(a, 27.0);
  arrayDAppend(a, 59.0);

  assert(2 == arrayDSize(a));

  assert(27.0 == arrayDIndex(a, 0));
  assert(59.0 == arrayDIndex(a, 1));

  arrayDUnref(a);

  // call each function to avoid warnings from the compiler
  if (0) {
    arrayDPrint(a);
    arrayDUnitTest();
  }
} // arrayDUnitTest

////////////////////////////////////////////////////////////////////////////////
// ArrayS
////////////////////////////////////////////////////////////////////////////////

/**
Allocate a new arrayS (array of strings)
*/
ArrayS*     arraySNew() {
  ArrayS *a = malloc(sizeof(ArrayS));
  assert(a);
  a->gArray = g_array_new(0, // not zero terminated
                          1, // clear elements to zero when allocated
                          sizeof(const char*)); // element size
  assert(a->gArray);
  return a;
} // arraySNew

/**
Decrement reference count, possibly freeing storage.
*/
void        arraySUnref(ArrayS* a) {
  assert(a);
  g_array_unref(a->gArray);
  free(a);
} // arraySUnref

/**
Append the string pointer as the new last element of the array.
*/
void        arraySAppend(ArrayS* a, const char *string) {
  assert(a);
  g_array_append_val(a->gArray, string);
} // arraySAppend

/**
Return pointer to ga[index]
*/
char* arraySIndex(const ArrayS* a, guint index) {
  assert(a);
  assert(index >= 0);
  assert(index < a->gArray->len);
  char *result = g_array_index(a->gArray, char*, index);
  return result;
} // arraySIndex

/**
Return number of elements in the array
*/
guint arraySSize(const ArrayS *a) {
  assert(a);
  guint result = a->gArray->len;
  return result;
} // arraySSize

/**
Run unit tests for arrayS
*/
void arraySUnitTest() {
  ArrayS *a = arraySNew();
  assert(0 == arraySSize(a));

  arraySAppend(a, "one");
  arraySAppend(a, "two");

  assert(2 == arraySSize(a));

  const char* maybeOne = arraySIndex(a, 0);
  assert(strcmp(maybeOne, "one") == 0);

  const char* maybeTwo = arraySIndex(a, 1);
  assert(strcmp(maybeTwo, "two") == 0);

  arraySUnref(a);

  // call each function to avoid warnings from the compiler
  if (0) {
    arraySUnitTest();
  }

} // arraySUnitTest

////////////////////////////////////////////////////////////////////////////////
// HashDD
////////////////////////////////////////////////////////////////////////////////

HashDD* hashDDNew() {
  HashDD *h = malloc(sizeof(HashDD));
  assert(h);
  h->gHashTable = g_hash_table_new_full(g_double_hash,
                                        g_double_equal,
                                        free,
                                        free);
  assert(h->gHashTable);
  return h;
} // hashDDNew

void hashDDUnref(HashDD *h) {
  assert(h);
  g_hash_table_unref(h->gHashTable);
  free(h);
}

void hashDDInsert(HashDD *h, double key, double value) {
  const unsigned verbose = 0;
  assert(h);

  double *keyP = malloc(sizeof(key));
  assert(keyP);
  *keyP = key;

  double *valueP = malloc(sizeof(value));
  assert(value);
  *valueP = value;

  g_hash_table_insert(h->gHashTable, keyP, valueP);
  if (verbose > 0)
    printf("hashDDInsert: inserted key %g keyP %p value %g valueP %p\n",
           key, keyP, value, valueP);
} // hashDDInsert

HashDDLookup hashDDLookup(const HashDD *h, double key) {
  assert(h);
  HashDDLookup result;
  double *valueP;
  gboolean found = g_hash_table_lookup_extended(h->gHashTable,
                                                &key,
                                                NULL,
                                                (gpointer *) &valueP);
  result.found = found;
  if (found) 
    result.value = *valueP;
  return result;
} // hashDDLookup

void hashDDIterInit(const HashDD *h, HashDDIter *iter) {
  assert(h);
  assert(iter);
  g_hash_table_iter_init(iter, h->gHashTable);
} // hashDDIterInit

gboolean hashDDIterNext(HashDDIter *iterP,
                               double *keyP,
                               double *valueP) {
  assert(iterP);
  assert(keyP);
  assert(valueP);
  double *keyResultP = NULL;
  double *valueResultP = NULL;
  const gboolean found = 
    g_hash_table_iter_next(iterP, 
                           (void **) &keyResultP, 
                           (void **)&valueResultP);
  if (found) {
    *keyP = *keyResultP;
    *valueP = *valueResultP;
  }
  return found;
} // hashDDIterNext

void hashDDUnitTest() {
  //printf("DEBUG ME: hashDDTest\n");
  HashDD *h = hashDDNew();
  hashDDInsert(h, 1, 10);
  hashDDInsert(h, 2, 20);
  
  HashDDLookup result;
  result = hashDDLookup(h, 1);
  assert(result.found);
  assert(result.value == 10.0);
  
  result = hashDDLookup(h, 2);
  assert(result.found);
  assert(result.value == 20.0);

  result = hashDDLookup(h, 0);
  assert(!result.found);

  HashDDIter iter;
  hashDDIterInit(h, &iter);
  double key  = 0;
  double value = 0;
  unsigned count = 0;
  while (hashDDIterNext(&iter, &key, &value)) {
    assert(key == 1.0 || key == 2.0);
    assert(value == 10.0 || value == 20.0);
    if (key == 1.0)
      assert(value == 10.0);
    else if (key == 2.0)
      assert(value == 20.0);
    else
      assert(0); // only keys are 1.0 and 2.0
    count++;
  }
  assert(count == 2);

  hashDDUnref(h);

  // call each function to avoid compiler warnings
  if (0) {
    hashDDUnitTest();
  }

} // hashDDUnitTest
