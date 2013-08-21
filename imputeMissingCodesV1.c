// imputeMissingCodes.c
// estimate probability distributions for the missing codes in observations
// write CSV file

#include "all-headers.h"

// GLOBAL options structure
// MAYBE: set via command line
typedef struct {
  unsigned     test;  // 1 == test, 0 == production
  // number of incremental obs needed to retain a greedily-selected ncoded col
  // (see reduceCodeColumns() function)
  unsigned     bigJump;
  unsigned     createImputable;  // create observations-imputable.csv
} options_s;

// set default options
static options_s options = {.test = 0, 
                            .bigJump = 200000, 
                            .createImputable = 0};

// GLOBAL setting structure
// values derived in part from options
// this structure is filled in by the main program
typedef struct {
  GString *resultsDir; // write non-output files here (ex: log file)
  GString *outputDir;
  Log_T    log;        // loging via macro LOG(log, format, ...);
} settings_s;

static settings_s settings;

// redefine the LOG macro so that it uses settings.log
#undef LOG
#define LOGF(format, ...) \
  Log_printfFunctionLineTime(settings.log, \
                             __func__, \
                             __LINE__, \
                             format, \
                             __VA_ARGS__)

#define LOG(s) \
  Log_printfFunctionLineTime(settings.log, \
                             __func__, \
                             __LINE__, \
                             s)



// macros

/* verbose print (vp): print if verbose is not 0 */
#define vp(...)  if (verbose > 0) fprintf(stderr, __VA_ARGS__)
#define vp2(...) if (verbose > 1) fprintf(stderr, __VA_ARGS__)


////////////////////////////////////////////////////////////////////////////////
// LOCAL TYPE DECLARATIONS
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// ArrayD: array of doubles
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GArray *gArray;
} ArrayD;

static ArrayD* arrayDNew();
static void    arrayDUnref(ArrayD *a);

static void    arrayDAppend(ArrayD *a, double value);
static double  arrayDIndex(const ArrayD *a, guint index);
static guint   arrayDSize(const ArrayD *a);

static void    arrayDTest();

////////////////////////////////////////////////////////////////////////////////
// ArrayS: array of c strings
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GArray *gArray;
} ArrayS;

static ArrayS* arraySNew();
static void    arraySUnref(ArrayS* a);

static void    arraySAppend(ArrayS* a, const char *value);
static char*   arraySIndex(const ArrayS* a, unsigned index);
static guint   arraySSize(const ArrayS *a);

static void    arraySTest();

////////////////////////////////////////////////////////////////////////////////
// HashIS: hash table with key = int, value = string
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GHashTable *gHashTable;
} HashIS;

typedef struct {
  unsigned  found;
  char     *value;
} HashIS_s;

static HashIS*  hashISNew();
static void     hashISUnref(HashIS *h);

static void     hashISInsert(HashIS *h, gint key, const char* value);
static HashIS_s hashISLookup(const HashIS *h, gint key);

////////////////////////////////////////////////////////////////////////////////
// HashSI: hash table with key = string, value = int
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  GHashTable *gHashTable;
} HashSI; 

typedef struct { // value returned by HashSILookup
  unsigned found; // 1 or 0
  gint     value;
} HashSI_s;

static HashSI*  hashSINew(); //key=string value=gint (32 bits, signed)
static void     hashSIUnref(HashSI *h);

static void     hashSIInsert(HashSI *h, const char *key, gint value);
static HashSI_s hashSILookup(const HashSI *h, const char *key);
static void     hashSIPrint(const HashSI *h);
static guint    hashSISize(const HashSI *h);

static void     hashSITest();   // unit test

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


////////////////////////////////////////////////////////////////////////////////
// local function declarations
////////////////////////////////////////////////////////////////////////////////

static void     apopAppendColumn(apop_data *data, 
                                 gsl_vector *v, 
                                 const char* newName);
static unsigned apopColumnName(const apop_data *data,
                               const char      *cName,
                               char             designator);
static unsigned apopColumnNameMatrix(const apop_data *data, const char *cName);
static unsigned apopColumnNameText(const apop_data *data, const char *cName);
static void     apopDataPrintAnomolies(const apop_data *data);
static void     apopDataPrintSummary(const apop_data *data);
static void     apopDataPrintRow(const apop_data *data, unsigned rowIndex);
static void     apopDropMatrixColumn(apop_data *data, const char *cName);
static void     apopDropMatrixColumns(apop_data *data, const ArrayD *nums);
static void     apopDropRows(apop_data *data, const ArrayD *rowIndices);
static void     apopModelPrintSummary(const apop_model *model);
static void     apopPrintSummary(const apop_data *data,
                                 FILE *file,
                                 const char *heading,
                                 unsigned nObs);
static void     apopSetMatrixColumn(apop_data *data, 
                                    unsigned colNumber, 
                                    gsl_vector *v);
static void     apopSummarizeData(const apop_data *data,
                                  const char *message,
                                  const char *fileName);
static void     apopWriteVectorMatrix(const apop_data *data,
                                      const char *path);


static unsigned countRemainingObservations(const apop_data *data,
                                           SetI            *examined,
                                           SetI            *excluded);

static void createImputable();

static void failIf(int condition, const char * message, ...); 

static void gslVectorMeanStddev(const gsl_vector *v, 
                                double *meanP, 
                                double *stddevP);
static void gslVectorStandardize(gsl_vector *v);
static void gslVectorTest();

static gboolean hasNan(const apop_data *data);

static void imputeAllNCoded(apop_data *data);
static void imputeOne(apop_data *data, unsigned colIndex, const char *colName);

static void makeSettings();

static void openDb();
static FILE* openResultsFile(GString *resultsDir, const char *name);

static void printTwice(FILE *file, const char *format, ...);
 

typedef gsl_vector* recodeDataF(const apop_data *data, 
                                unsigned col, 
                                const char *currentCode);
static void recodeData(apop_data *data);
//static void recodeDataCode(apop_data *data, const char *cName);
static void recodeDataDate(apop_data *data, const char *cName);
static void recodeDataFlag(apop_data *data, const char *cName);
static void recodeDataImprovementFraction(apop_data *data);
static void recodeDataNCode(apop_data *data, const char *cName, unsigned maxN);
static void recodeDataSize(apop_data *data, const char *cName);
static void recodeDataSpa(apop_data *data);
static void recodeDataStandardize(apop_data *data, const char *cName);
static gsl_vector* recodeDataTransformCode(const apop_data *data,
                                           unsigned         col,
                                           const char      *currentCode);
static gsl_vector* recodeDataTransformFlag(const apop_data *data,
                                           unsigned         col,
                                           const char      *currentCode);
static void recodeDataVectorLogP1(apop_data *data);
static void recodeDataWorker(apop_data *data, const char *cName, char c);

static void reduceCodeColumns(apop_data *data);
static void reduceCodeColumnsIter(apop_data *data,
                                  SetI      *examined,
                                  SetI      *excluded,
                                  ArrayD    *deletedIndices,
                                  ArrayD    *nRemaining);

static gboolean strSuffixEqual(const char *s, const char *suffix);



#if 0
static unsigned long strToUnsignedLong(const char *str);
#endif

static ArrayS* distinctTextValues(const apop_data *data, const char* cName);

static void unitTests();


////////////////////////////////////////////////////////////////////////////////
int main(int argc, char **argv) {
  const unsigned verbose = 1;
  
  makeSettings();
  
  unitTests();

  openDb();

  // maybe create the imputable table in the database
  if (options.createImputable)
    createImputable();   // this takes several minutes

  // read the data for the imputations
  vp("reading imputable table\n");
  apop_data *data = apop_query_to_data("select * from imputable;");
  assert(data);
  printf("imputable\n");
  apopDataPrintSummary(data);

  // do the imputation
  imputeAllNCoded(data);

  // close the database
  failIf(0 != apop_db_close('q'), // q ==> don't vacuum
         "db did not close");

  // stop logging
  Log_free(&settings.log);  // close underlying file and free object
} // end main

////////////////////////////////////////////////////////////////////////////////
// STATIC FUNCTIONS
////////////////////////////////////////////////////////////////////////////////

/**
Append a new column to the matrix portion of a dataset.
@param data the dataset; mutated
@param v; the vector
@param newName; name of the column
*/
static void apopAppendColumn(apop_data *data, 
                             gsl_vector *v, 
                             const char* newName) {
  const unsigned verbose = 0;
  assert(data);
  assert(v);
  assert(newName);

  // Step 1: build a new data set with a name structure
  const unsigned nObs = v->size;
  assert(nObs > 0);
  assert(data->matrix->size1 == nObs);

  apop_data *newData = apop_data_alloc_base(0, nObs, 1); // just matrix 1 col
  assert(newData);
  apopSetMatrixColumn(newData, 0, v);

  apop_name *name = apop_name_alloc();
  assert(name);
  name->colct = 1;
  // the name->column must be alloc'd, so can't say
  // name->column = (char **) &newName;
  // must allocate new storage
  GString *newNameGS = g_string_new(newName);
  char ** colNames = calloc(1, sizeof(char *));
  colNames[0] = newNameGS->str;
  name->column = colNames;

  newData->names = name;
  
  // Step 2: stack the new data set to right of current data set, mutating
  // the current data set

  if (verbose) {
    printf("data before stacking\n");
    apopDataPrintSummary(data);
    printf("temp data\n");
    apopDataPrintSummary(newData);
  }

  apop_data_stack(.m1 = data, .m2 = newData, .posn = 'c', .inplace = 'y');

  if (verbose) {
    printf("data after stacking\n");
    apopDataPrintSummary(data);
  }

  // Step 3: free working storage
  apop_data_free_base(newData);
} // apopAppendColumn

/** 
Return index of matrix or text column name
@param data the dataset
@param cName column name (a regex)
@param designator 'c'-->search vector and matrix; 't'-->search text
*/
static unsigned apopColumnName(const apop_data *data, 
                               const char      *cName,
                               char             designator) {
  assert(data != NULL);
  assert(cName);
  assert(designator == 'c' || designator == 't');
  const apop_name *names = data->names;
  assert(names != NULL);

  const unsigned col = apop_name_find(names, cName, designator);
  failIf(col == -2, "column name %s not found", cName);
  failIf(col == -1, "column name %s is the vector name", cName);

  return col;
} // apopColumnName


/**
Return index of column name in the matrix portion of a dataset
@parm data the dataset
@parm name the name
*/
static unsigned apopColumnNameText(const apop_data *data, const char *cName) {
  return apopColumnName(data, cName, 't');
} // apopColumnNameText

/**
Drop a matrix column
@param data the dataset; mutated
@param cName the name of the matrix column
*/
static void     apopDropMatrixColumn(apop_data *data, const char *cName) {
  assert(data);
  assert(cName);
  
  ArrayD *a = arrayDNew();
  arrayDAppend(a, (double) apopColumnNameMatrix(data, cName));
  apopDropMatrixColumns(data, a);
  arrayDUnref(a);
} // apopDropMatrixColumn

static void apopDropMatrixColumns(apop_data *data, const ArrayD* indices) {
  assert(data);
  assert(indices);

  const int nMatrixColumns = data->matrix->size2;

  // build array of int containing indicators
  // initially all are zero
  int *drop = calloc(nMatrixColumns, sizeof(int));

  for (unsigned i = 0; i < arrayDSize(indices); i++) {
    const int colNum = (int) arrayDIndex(indices, i);
    assert(colNum >= 0);
    assert(colNum < nMatrixColumns);
    LOGF("dropping matrix column %d\n", colNum);
    drop[colNum] = 1;
  }
  apop_data_rm_columns(data, drop);
  free(drop);
} // apopDropMatrixColumns

static void apopDropRows(apop_data *data, const ArrayD *rowIndices) {
  printf("DEBUG ME\n");
  assert(data);
  assert(rowIndices);

  const unsigned nObs = data->matrix->size1;
  const unsigned nRowIndices = arrayDSize(rowIndices);
  assert(nRowIndices < nObs - 1);

  // build int* with indicator 1 for rows to drop
  int * toDrop = calloc(nObs, sizeof(int));  // initialized to all zeroes
  assert(toDrop);
  for (unsigned i = 0; i < nRowIndices; i++) {
    toDrop[(int) arrayDIndex(rowIndices, i)] = 1;
  }

  apop_data_rm_rows(data, toDrop, NULL, NULL);
 
  free(toDrop);
} // apopDropRows

/**
Print summary of a model
*/
static void     apopModelPrintSummary(const apop_model *model) {
  printf("title %s\n", model->name);
  printf("vbase %d mbase1 %d mbase2 %d\n",
         model->vbase, model->m1base, model->m2base);
  printf("dsize (parameter set size) %d\n", model->dsize);

  printf("setting %a\n", model->settings);
  printf(" name %s\n", model->settings->name);
  printf(" setting_group %a\n", model->settings->setting_group);
  printf(" copy %a\n", model->settings->copy);
  printf(" free %a\n", model->settings->free);

  printf("parameters %a\n", model->parameters);
  apopDataPrintSummary(model->parameters);
  printf("end of parameters summary");
  
  printf("data %a\n", model->data);
  printf("info %a\n", model->info); // depends on the model
  printf("more %a more_size %lu\n", model->more, model->more_size);
  
  printf("function apop_estimate %a\n", model->estimate);
  printf("function apop_p        %a\n", model->p);
  printf("function apop_log_likelihood %a\n", model->log_likelihood);
  printf("function apop_score          %a\n", model->score);
  printf("function apop_predict        %a\n", model->predict);
  printf("function apop_parameter_model %a\n", model->parameter_model);
  printf("function apop_cdf             %a\n", model->cdf);
  printf("function apop_constraint      %a\n", model->constraint);
  printf("function apop_draw            %a\n", model->draw);
  printf("function apop_prep            %a\n", model->prep);
  printf("function apop_print           %a\n", model->print);
  
} // apopModelPrintSummary

/**
Print means, std dev, etc of a dataset.

The table was created by the apop_data_summarize(apop_data*) function. It
has one row for each feature and columns for mean, std dev, var, min, med,
max.
@param table created by apop_data_summarize
@param file  where to write the results
@param heading print as title of table
@paran nObs number of observations
*/
static void apopPrintSummary(const apop_data *table, 
                             FILE *file,
                             const char *heading,
                             unsigned nObs) {
  assert(table);
  assert(file);
  assert(heading);
  const unsigned nRows = table->matrix->size1;
  const unsigned nCols = table->matrix->size2;
  assert(nCols == 6);

  // write header for printed table
  const apop_name *names = table->names;
  assert(names);
  assert(names->colct == 6);
  fprintf(file, "%s\n", heading);
  fprintf(file, "Number of observations = %u\n", nObs);
  fprintf(file,
          "%30s %11s %11s %11s\n%30s %11s %11s %11s\n", 
         "feature", "mean", "std dev", "variance", 
         " ", "min", "median", "max");

  // print each row of the table
  // each row contains statistics on a feature
  assert(names->rowct == nRows);
  for (unsigned r = 0; r < nRows; ++r) {
    // print first row
    fprintf(file, "%30s", names->row[r]);
    fprintf(file, " %11g", gsl_matrix_get(table->matrix, r, 0));
    fprintf(file, " %11g", gsl_matrix_get(table->matrix, r, 1));
    fprintf(file, " %11g", gsl_matrix_get(table->matrix, r, 2));
    // print second row
    fprintf(file, "\n%30s", " ");
    fprintf(file, " %11g", gsl_matrix_get(table->matrix, r, 3));
    fprintf(file, " %11g", gsl_matrix_get(table->matrix, r, 4));
    fprintf(file, " %11g", gsl_matrix_get(table->matrix, r, 5));
    fprintf(file, "\n");
  }
} // apopPrintSummary

/**
Return index of column name in the matrix portion of a dataset
@parm data the dataset
@parm name the name
*/
static unsigned apopColumnNameMatrix(const apop_data *data, const char *cName) {
  return apopColumnName(data, cName, 'c');
}

/**
Set data->matrix[colIndex][*] := v
@param    data a dataset; it's matrix component is mutated
@colIndex column to set
@v        vector of values to set
*/
static void apopSetMatrixColumn(apop_data *data,
                            unsigned colIndex,
                            gsl_vector *v) {
  assert(v->size == data->matrix->size1);
  assert(colIndex >= 0);
  for (unsigned i = 0; i < data->matrix->size1; i++) {
    const double value = gsl_vector_get(v,i);
    apop_data_set(data, .row = i, .col = colIndex, .val = value);
  }
}

/**
Print descriptive and statical summaries of the data
@param typelist list of column types 
@param selectStatement the select statement
@param message explain what data are to be read
@param fileName name of file in results directory where stat summary is written
*/
static void apopSummarizeData(const apop_data *data,
                              const char      *message,
                              const char      *fileName) {
  assert(data);
  assert(message);
  assert(fileName);
 
  printf("%s\n", message);
  apopDataPrintSummary(data);
  apopDataPrintAnomolies(data);

  // create statistical summary of features and print on stdout and fileName
  printf("Statistics on %s\n", message);
  apop_data *summary = apop_data_summarize((apop_data*) data);
  const unsigned nObs = data->matrix->size1;
  apopPrintSummary(summary, 
                   stdout, 
                   message,
                   nObs);
  FILE *file= openResultsFile(settings.resultsDir,
                              "observations-count-before-rejections");
  apopPrintSummary(summary,
                   file,
                   message,
                   nObs);
  fclose(file);
  apop_data_free(summary);
} // apopSummarizeData

/**
Write vector and matrix to csv file
*/
static void apopWriteVectorMatrix(const apop_data *data, const char* path) {
  assert(data);
  assert(path);

  FILE *file = fopen(path, "w");
  assert(file);

  const unsigned nObs = data->matrix->size1;
  const int nCols = data->matrix->size2;    // must not be unsigned
  const apop_name *names = data->names;

  // write the csv header
  fprintf(file, "%s", names->vector);
  for (unsigned k = 0; k < nCols; k++) {
    fprintf(file, ",%s", names->column[k]);
  }
  fprintf(file, "\n");

  // write each row
  for (unsigned i = 0; i < nObs; i++) {
    for (int k = -1; k < nCols; k++) {
      if (k > -1)
        fprintf(file, ",");
      // -1^{th} col is the vector
      fprintf(file, "%g", apop_data_get(.data = data,
                                        .row = i,
                                        .col = k));
    }
    fprintf(file, "\n");
  }
  fclose(file);

  LOGF("wrote file %s\n", path);
  LOGF(" containing %u observations and %u features + sale_amount\n",
       nObs, nCols);
} // apopWriteVectorMatrix


/**
Allocate a new arrayS (array of strings)
*/
static ArrayS*     arraySNew() {
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
static void        arraySUnref(ArrayS* a) {
  assert(a);
  g_array_unref(a->gArray);
  free(a);
} // arraySUnref

/**
Append the string pointer as the new last element of the array.
*/
static void        arraySAppend(ArrayS* a, const char *string) {
  assert(a);
  g_array_append_val(a->gArray, string);
} // arraySAppend

/**
Return pointer to ga[index]
*/
static char* arraySIndex(const ArrayS* a, unsigned index) {
  assert(a);
  assert(index >= 0);
  assert(index < a->gArray->len);
  char *result = g_array_index(a->gArray, char*, index);
  return result;
} // arraySIndex

/**
Return number of elements in the array
*/
static guint arraySSize(const ArrayS *a) {
  assert(a);
  guint result = a->gArray->len;
  return result;
} // arraySSize

/**
Run unit tests for arrayS
*/
static void arraySTest() {
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
} // arraySTest

/**
Allocate new array of double
*/
static ArrayD * arrayDNew() {
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
static void arrayDUnref(ArrayD *a) {
  assert(a);
  g_array_unref(a->gArray);
  free(a);
} // arraySUnref

/**
Append double value
*/
static void arrayDAppend(ArrayD *a, double value) {
  assert(a);
  // the macro call below determines the element size
  g_array_append_val(a->gArray, value);
} // arrayDAppend

/**
Return double value at index
*/
static double arrayDIndex(const ArrayD *a, unsigned index) {
  assert(a);
  return g_array_index(a->gArray, double, index);
} // arrayDIndex


/**
Return number of elements in array
*/
static guint arrayDSize(const ArrayD *a) {
  assert(a);
  return a->gArray->len;
} // arrayDSize

/**
Unit tests for ArrayD
*/
static void arrayDTest() {
  ArrayD *a = arrayDNew();
  assert(0 == arrayDSize(a));
  
  arrayDAppend(a, 27.0);
  arrayDAppend(a, 59.0);

  assert(2 == arrayDSize(a));

  assert(27.0 == arrayDIndex(a, 0));
  assert(59.0 == arrayDIndex(a, 1));

  arrayDUnref(a);
} // arrayDTest


/**
Detemine how many observations remain if NaNs exclude observations.

Exclude an obsevation if there is a NaN in any of the columns in 
examined - excluded.
@param data the data set
@param examine set of columns to examine
@param excluded subset of examined that are not used
*/
static unsigned countRemainingObservations(const apop_data *data,
                                           SetI            *examined,
                                           SetI            *excluded) {
  const unsigned verbose = 0;

  assert(data);
  assert(examined);
  assert(excluded);

  if (verbose > 0) {
    printf("columns examined = ");
    setIPrint(examined);
    printf("columns excluded = ");
    setIPrint(excluded);
  }

  const unsigned nObs = data->matrix->size1;
  const unsigned nFeatures = data->matrix->size2;

  unsigned count = 0;
  for (unsigned i = 0; i < nObs; i++) {
    gboolean allFeaturesPresent = TRUE;
    if (verbose > 1)
      printf("examined values in obs %u =", i);
    for (unsigned k = 0; k < nFeatures && allFeaturesPresent; k++) {
      if (setIContains(examined, k) && !setIContains(excluded, k)) {
        const double value = apop_data_get(.data = data,
                                           .row = i,
                                           .col = k);
        if (verbose > 1)
          printf(" %g ", value);
        if (isnan(value)) 
          allFeaturesPresent = FALSE;
      }
    }
    if (verbose > 1)
      printf("\n");
    if (allFeaturesPresent) 
      count++;
  }
  if (verbose > 0) 
    printf("count = %d\n", count);
  return count;
} // countRemainingObservations

/**
Read observations table from db.sqlite3, create file observations-imputable.csv
*/
static void createImputable() {
  const unsigned verbose = 1;

  openDb();

  // read everything
  // for columns that I know I don't want as features, read them as text
  const char * typelist = // m -> matrix feature, v-> vector target t->text info
    "tmt" // deeds_apn_unformatted, sale_date, apn_formatted,
    "tvt" // deed_apn_sequence_number, sale_amount, recording_date,
    "ttt" // document_type_code, transaction_type_code, taxroll_apn_unformatted,
    "ttt" // taxroll_apn_sequence_number, map_reference_1, map_reference_2,
    "ttt" // census_tract, census_block_group, census_block,
    "ttt" // census_block_suffix, zoning, township,
    "ttt" // section, thomas_bros_map_number, flood_zone_community_panel_id,
    "ttt" // centroid_code, homestead_exempt, absentee_indicator_code,
    "ttt" // tax_code_area, county_land_use_1, county_land_use_2,
    "ttt" // property_indicator_code, municipality_name, view,
    "ttt" // location_influence_code, number_of_buildings, property_city,
    "ttt" // property_state, property_zip_code, property_carrier_route,
    "tt"  // property_match_code, owner_corporate_indicator_flag,
    "tm"  // total_value_calculated, land_value_calculated,
    "mmt" // improvement_value_calculated, tax_amount, tax_year,
    "tt"  // subdivision_tract_number, subdivision_plat_book,
    "ttt" // subdivision_plat_page, subdivision_name, front_footage,
    "tmt" // depth_footage, acres, lot_area,
    "mmt" // universal_building_square_feet, living_square_feet, year_built,
    "mmm" // effective_year_built, bedrooms, total_rooms,
    "mmm" // total_baths, fireplace_number, parking_spaces,
    "mtt" // stories_number, air_conditioning_code, condition_code,
    "tt"  // construction_type_code, exterior_walls_code,
    "ttt" // fireplace_indicator_flag, fireplace_type_code, foundation_code,
    "ttt" // floor_code, frame_code, garage_code,
    "ttt" // heating_code, mobile_home_indicator_flag, parking_type_code,
    "ttt" // pool_flag, pool_code, quality_code,
    "ttt" // roof_cover_code, roof_type_code, style_code,
    "ttm" // units_number, water_code, latitude,
    "mmm" // longitude, average_commute,fraction_owner_occupied,
    "m";  // household_median_income

  // info needed for the thesis but not used in the calculations
  if (verbose > 1) {
    const char *selectStatementAll =  
      options.test 
      ? "SELECT * FROM observations limit 10;"
      : "SELECT * FROM observations;";
    
    apop_data *dataBeforeRejections = 
      apop_query_to_mixed_data(typelist,
                               "%s",
                               selectStatementAll);
    assert(dataBeforeRejections);
    apopSummarizeData(dataBeforeRejections, 
                      "Observation Without Any Rejection Criteria",
                      "stats-no-rejection-criteria.txt");
    apop_data_free(dataBeforeRejections);
  }

  // reject certain observations
  // don't change the columns read, as would need to create a new typelist
  // and that would be tedious
  
  GString *selectStatementReject = g_string_new("SELECT * FROM observations ");
  g_string_append(selectStatementReject,
                  "WHERE land_value_calculated != 0 "
                  "AND   improvement_value_calculated != 0 "
                  "AND   effective_year_built >= 1542 "
                  "AND   total_rooms != '00000' "
                  "AND   stories_number != '00000' "
                  "AND   latitude != 0 "
                  "AND   longitude != 0 "
                  "AND   average_commute != 0 "
                  "AND   fraction_owner_occupied != 0 "
                  "AND   household_median_income != 0 ");
  if (options.test == 1)
    g_string_append(selectStatementReject, "LIMIT 10");
  g_string_append(selectStatementReject, ";");
  apop_data *data =
    apop_query_to_mixed_data(typelist,
                             "%s",
                             selectStatementReject->str);
  g_string_free(selectStatementReject, TRUE); // TRUE ==> free segment

  // Drop the universal_building_square_feet feature
  apopDropMatrixColumn(data, "universal_building_square_feet");
  printf("size of matrix after dropping before recoding = %lu x %lu\n",
         data->matrix->size1,
         data->matrix->size2);

  if (verbose > 0)
    apopSummarizeData(data,
                      "Observations After Applying Rejection Criteria",
                      "stats-rejection-criteria.txt");


  // transform the matrix data
  recodeData(data);
  if (verbose > 0) {
    printf("dataset after recoding data\n");
    apopDataPrintSummary(data);
    apopDataPrintAnomolies(data);
  }


  // recode the text columns into the matrix
  reduceCodeColumns(data);
  if (verbose > 0) {
    printf("dataset after reducing number of text columns\n");
    apopDataPrintSummary(data);
    apopDataPrintAnomolies(data);
  }

  // write csv file with the matrix and vector and their names
  if (0) {
    GString *csvpath = g_string_new(settings.outputDir->str);
    g_string_append(csvpath, "/observations-imputable.csv");
    apopWriteVectorMatrix(data, csvpath->str);
    g_string_free(csvpath, 1); // 1-->also free segment
  }

  // create imputable table with 1 result (first column) and 32 features
  failIf(0 != apop_query("DROP TABLE IF EXISTS imputable;"),
         "did not drop imputable table");
  failIf(0 != apop_query("CREATE TABLE imputable "
                         "(sale_amount_log REAL "
                         ",sale_date_days REAL "
                         ",land_value_calculated_log_std REAL "
                         ",improvement_value_calculated_log_std REAL "
                         ",tax_amount_log_std REAL "
                         ",acres_log_std REAL "
                         ",living_square_feet_log_std REAL "
                         ",effective_year_built_std REAL "
                         ",bedrooms_log_std REAL "
                         ",total_rooms_log_std REAL "
                         ",total_baths_log_std REAL "
                         ",fireplace_number_log_std REAL "
                         ",parking_spaces_log_std REAL "
                         ",stories_number_log_std REAL "
                         ",latitude_std REAL "
                         ",longitude_std REAL "
                         ",average_commute_log_std REAL "
                         ",fraction_owner_occupied_std REAL "
                         ",household_median_income_log_std REAL "
                         ",improvement_fraction REAL "
                         ",transaction_type_code_ncoded REAL "
                         ",condition_code_ncoded REAL "
                         ",exterior_walls_code_ncoded REAL "
                         ",fireplace_indicator_flag_is_Y REAL "
                         ",foundation_code_ncoded REAL "
                         ",garage_code_ncoded REAL "
                         ",heating_code_ncoded REAL "
                         ",parking_type_code_ncoded REAL "
                         ",pool_flag_is_Y REAL "
                         ",has_spa REAL "
                         ",roof_cover_code_ncoded REAL "
                         ",roof_type_code_ncoded REAL "
                         ",style_code_ncoded REAL "
                         ");"),
         "unable to create imputable table");

  // insert each record
  // the value inserted is the actual matrix values if NaN or NULL
  const unsigned nObs = data->matrix->size1;
  const int nCols = data->matrix->size2;
  printf("writing imputable table with %u observations\n", nObs);
  for (unsigned i = 0; i < nObs; i++) {
    GString *query = g_string_new("INSERT INTO imputable VALUES ");
    for (int k = -1; k <  nCols; k++) {
      g_string_append(query, k == -1 ? "(" : ",");
      const double value = apop_data_get(.data=data, .row=i, .col=k);
      if (isnan(value)) 
        g_string_append(query, "NULL");
      else
        g_string_append_printf(query, "%g", value);
    } 
    g_string_append(query, ");");
    failIf(0 != apop_query("%s", query->str),
           "unable to insert record in imputable table");
    g_string_free(query, 1); // 1-->free segment
    if (i % 1000 == 0)
      printf("wrote record with index %u\n", i);
  }

  // free and close
  apop_data_free(data);
} // createImputable

/**
Examine a text column and determine the distinct text values it contains.

Print the values seen.

@parm data the dataset
@parm cName the text column name in the dataset
@return Garray of strings, each a value that occurs at least once in the column
*/
static ArrayS* distinctTextValues(const apop_data *data, const char *cName) {
  const unsigned verbose = 0;

  assert(data);
  assert(data->text);
  assert(cName);

  ArrayS *result = arraySNew();

  // make sure column is in the text
  unsigned col = apopColumnNameText(data, cName);
  vp("text col %u\n", col);
  vp("text sizes %lu %lu\n", data->textsize[0], data->textsize[1]);
  assert(col < data->textsize[1]);

  HashSI *seen = hashSINew(); // set of values seen

  const unsigned long nObs = data->textsize[0];
  for (unsigned i = 0; i < nObs; i++) {
    char *code = data->text[i][col];
    vp("code %s\n", code);
    const HashSI_s lookup = hashSILookup(seen, code);
    if (!lookup.found) {
      arraySAppend(result, code);
      hashSIInsert(seen, code, 1); // 1-->arbitrary value
    }
  }
  hashSIUnref(seen);

  const unsigned nCols = arraySSize(result);
  for (unsigned i = 0; i < nCols; i++) {
    printf("Codes found in column %s; %u: %s\n", 
           cName, i, arraySIndex(result, i));
  }

  return result;
} // distinctTextValues

/**
If the condition is not true, assert(0) after displaying the message
@param condition just return if not 0, otherwise exit with status code 1
@param format    format as for a printf function call with trailing \n
@param varargs   parameters to the format
 */
void static failIf(int condition, const char *format, ...) {
  if (condition == 0) {
    return;
  }
  fprintf(stderr, "failure\n");

  va_list argptr;
  va_start(argptr, format);
  vfprintf(stderr, format, argptr);
  va_end(argptr);
  fprintf(stderr, "\n");

  //fprintf(stderr, "exiting with status code 1\n");
  //exit(1);

  // while under development and hence running under a debugger, raise error
  assert("failIf condition");
} // failIf




/**
Determine mean and standard deviation of vector.

Algorithm is from wikipedia at "Algorithms for calculating variance"
@param v the vector
@param mean address where mean is set
@param stddev address where stddev is set
*/
static void gslVectorMeanStddev(const gsl_vector *v, 
                                double *meanP, 
                                double *stddevP){
  // use Compensated Variant in an attempt to combat round-off errors
  const unsigned n = v->size;
  assert(n > 1);

  // pass 1: compute mean
  double sum1 = 0.0;
  for (unsigned i = 0; i < n; i++) {
    sum1 += gsl_vector_get(v, i);
  }
  const double mean = sum1 / n;

  // pass 2: compute stddev
  double sum2 = 0.0;
  double sum3 = 0.0;
  for (unsigned i = 0; i < n; i++) {
    const double x = gsl_vector_get(v, i);
    const double diff = x - mean;
    sum2 += diff * diff;
    sum3 += diff;
  }
  const double nDouble = n + 0.0;
  const double variance = (sum2 - (sum3 * sum3 / nDouble)) / (nDouble) ;
  const double stddev = sqrt(variance);
  
  *meanP = mean;
  *stddevP = stddev;
} // gslVectorMeanStddev

/**
Run unit test of the gslVector* functions
*/
static void gslVectorTest() {
  // v = [1 2]
  gsl_vector *v = gsl_vector_alloc(2);
  gsl_vector_set(v, 0, 1.0);
  gsl_vector_set(v, 1, 2.0);
  
  double mean;
  double stddev;
  gslVectorMeanStddev(v, &mean, &stddev);
  assert(mean == 1.5);
  assert(stddev == 0.5);

  gslVectorStandardize(v);
  assert(-1 == gsl_vector_get(v, 0));
  assert( 1 == gsl_vector_get(v, 1));
} //gslVectorTest

/**
Return true iff a NaN is somewhere in the dataset
*/
static gboolean hasNan(const apop_data *data) {
  assert(data);

  const unsigned hasVector = data->vector != NULL;
  const unsigned hasMatrix = data->matrix != NULL;
  if (!hasVector && !hasMatrix)
    return 0;

  const unsigned nRows = hasMatrix ? data->matrix->size1 : data->vector->size;
  const unsigned nCols = hasMatrix ? data->matrix->size2 : 0;

  for (unsigned i = 0; i < nRows; i++) {
    for (unsigned j = 0; j < nCols; j++) {
      if (hasVector) {
        if (isnan(gsl_vector_get(data->vector, i)))
          return 1;
      }
      if (hasMatrix) {
        if (isnan(gsl_matrix_get(data->matrix, i, j)))
          return 1;
      }
    }
  }
  return 0;
} // hasNan

/**
Do the imputation for each nCoded column
*/
static void imputeAllNCoded(apop_data *data) {
  printf("DEBUG ME\n");
  assert(data);
  const apop_name *names = data->names;
  assert(names);
  
  const unsigned nCols = data->matrix->size2;
  assert(nCols == names->colct);

  for (unsigned k = 0; k < nCols; k++) {
    const char * colName = names->column[k];
    if (strSuffixEqual(colName, "_ncoded")) {
      printf("about to impute %u %s\n", k, colName);
      imputeOne(data, k, colName);
    }
  }
} // imputeAllNCoded

/**
Impute one ncoded column
*/
static void imputeOne(apop_data *dataOriginal, 
                      unsigned colIndex,
                      const char *colName) {
  printf("DEBUG ME\n");
  const unsigned verbose = 1;
  assert(dataOriginal);
  assert(colName);

  const unsigned nObs = dataOriginal->matrix->size1;
  const unsigned nCols = dataOriginal->matrix->size2;
  assert(colIndex < nCols);
  vp("nObs %u\n", nObs);
 
  apop_data *data = apop_data_copy(dataOriginal);
  
  // create and set vector to the k-th column
  // count number of missing values
  gsl_vector *vector = gsl_vector_alloc(nObs);
  unsigned nNans = 0;
  for (unsigned i = 0; i < nObs; i++) {
    double value = apop_data_get(.data=data,
                                 .row=i,
                                 .col=colIndex);
    gsl_vector_set(vector, i, value);
    if (isnan(value))
      nNans++;
  }
  // don't impute if no missing data
  if (nNans == 0) {
    vp("column %u %s has no nulls, so not imputed\n", colIndex, colName);
    gsl_vector_free(vector);
    apop_data_free(data);
    return;
  }
  vp("column %u %s has %u missing values\n", colIndex, colName, nNans);
    
  data->vector = vector;

  // delete the k-th column
  apopDropMatrixColumn(data, colName);

  // drop rows that have a NaN
  // build up an array of indices of rows with at least on NaN value
  ArrayD *toDelete = arrayDNew();
  unsigned countNansInVector = 0;
  unsigned countNansInMatrix = 0;
  for (unsigned i = 0; i < nObs; i++) {
    if (isnan(apop_data_get(.data=data, .row=i, .col=-1))) {
      vp2("found NaN in vector[%u]\n", i);
      arrayDAppend(toDelete, i);
      countNansInVector++;
      continue;
    }
    for (unsigned k = 0; k < nCols - 1; k++) {
      if (isnan(apop_data_get(.data=data, .row=i, .col=k))) {
        vp2("found NaN in matrix[%u][%u]\n", i, k);
        arrayDAppend(toDelete, i);
        countNansInMatrix++;
        continue;
      }
    }
  }
  const unsigned nToDelete = arrayDSize(toDelete);
  printf("found %u NaNs in vector and %u in matrix\n", 
         countNansInVector, countNansInMatrix);
  printf("number of rows to delete because of NaNs = %u\n", 
         nToDelete);
  printf("number of rows remaining = %u\n", nObs - nToDelete);
  apopDropRows(data, toDelete);
  
  // print to look for NaN values
  printf("Data used for the logistic regression\n");
  apopDataPrintSummary(data);
  
  if (1) {
    // debugging code

    // double check that there are no NaNs
    // also determine highest vector value
    double highest = -1;
    for (unsigned i = 0; i < data->matrix->size1; i++) {
      int nCols = (int) data->matrix->size2;
      for (int k = -1; k < nCols; k++) {
        const double value = apop_data_get(.data=data, .row=i, .col=k);
        if (k == -1) {
          assert(value >= 0);
          if (value > highest)
            highest = value;
        }
        assert(!isnan(value));
      }
    }

    printf("highest vector value is %g\n", highest);
  } // end debugging code


  // estimate the logistic regression model
  apop_model *estimated = apop_estimate(data, apop_logit);
  apopModelPrintSummary(estimated);

  // determine best estimates for missing values
  gsl_vector *predictions = gsl_vector_alloc(nObs);
  unsigned nCompared = 0;
  unsigned nCorrect = 0;
  for (unsigned i = 0; i < nObs; i++) {
    apop_data_row(dataOriginal, i, outd);
    if (verbose > 0) {
      printf("before dropping column being imputed\n");
      apopDataPrintSummary(outd);
    }
    // drop the column we are imputing
    if (1) {
      // debug version
      ArrayD *indices = arrayDNew();
      arrayDAppend(indices, colIndex);
      apopDropMatrixColumns(outd, indices);
      arrayDUnref(indices);
    }
    apopDropMatrixColumn(outd, colName);
    if (verbose > 0) {
      printf("after dropping column being imputed\n");
      apopDataPrintSummary(outd);
    }
    apop_data *prediction = hasNan(outd) ? NULL : apop_predict(outd, estimated);
    apopDataPrintSummary(prediction);
    // for now, assume the prediction is in the vector
    double predictedValue = 
      (prediction == NULL) 
      ? NAN
      : apop_data_get(.data=prediction,
                      .row=0,
                      .col=-1);
    gsl_vector_set(predictions, i, predictedValue);
    const double trueValue = apop_data_get(.data=data, .row=i, .col=-1);
    if (!isnan(trueValue)) {
      nCompared++;
      if (trueValue == predictedValue)
        nCorrect++;
    }
  }
  printf("nCompared %u nCorrect %u\n", nCompared, nCorrect);
  
  printf("STUB: saved predicted values\n");

  apop_data_free(data);

} // imputeOne

static HashIS* hashISNew() {
  HashIS *h = malloc(sizeof(HashIS));
  assert(h);
  h->gHashTable = g_hash_table_new(g_direct_hash, g_direct_equal);
  assert(h->gHashTable);
  return h;
} // hashSINew

static void hashISInsert(HashIS *h, gint key, const char *value) {
  assert(h);
  g_hash_table_insert(h->gHashTable, GINT_TO_POINTER(key), (char *) value);
} // hashISInsert

static HashIS_s hashISLookup(const HashIS *h, gint key) {
  assert(h);
  HashIS_s result = {.found = 0, .value = NULL};
  char *value;
  gboolean found = 
    g_hash_table_lookup_extended(h->gHashTable,
                                 GINT_TO_POINTER(key),
                                 NULL,    // gpointer *orig_key
                                 (gpointer *) &value);      // gpointer *value
  if (!found) 
    return result;
  result.found = 1;
  result.value = value;
  return result;
} // hashISLookup

static void hashISUnref(HashIS *h) {
  assert(h);
  g_hash_table_unref(h->gHashTable);
  free(h);
} // hashUnref

/**
Unit tests for HashIS
*/


static void hashISTest() {
  HashIS *h = hashISNew();
  const char* one = "one";
  hashISInsert(h, 1, one);
  hashISInsert(h, 27, "twenty seven");
  
  HashIS_s result = hashISLookup(h, 1);
  assert(result.found);
  assert(strcmp(result.value, one) == 0);
  
  result = hashISLookup(h, 27);
  assert(result.found);
  assert(strcmp(result.value, "twenty seven") == 0);

  hashISUnref(h);
} // hashISTest


/**
Return new hash table with key a string and value a double
*/
static HashSI* hashSINew() {
  HashSI *h = malloc(sizeof(HashSI));
  assert(h);
  h->gHashTable = g_hash_table_new(g_str_hash, g_str_equal);
  assert(h->gHashTable);
  return h;
}

/**
Insert a (string,double) value into the hash table
@param h     the hash table
@param key   the string
@param value the double
*/
static void hashSIInsert(HashSI *h, const char *key, gint value) {
  assert(h != NULL);
  // stuff the gint value into a pointer
  // remove the const on key, to conform to function def
  gpointer valueAsPointer = GINT_TO_POINTER(value);
  g_hash_table_insert(h->gHashTable, (char *) key, valueAsPointer);
}

/**
Lookup a gint value using the string key
@param h the hash table
@param key the string
@return hashSI_s structure
If the value is found, then     {.found = 1, .value = the gint value}
If the value is not found, then {.found = 0, value = -1}
*/
static HashSI_s hashSILookup(const HashSI *h, const char *key) {
  assert(h != NULL);
  HashSI_s result = {.found = 0, .value = -1};
  // remove the const qualifier in order to conform to the function def
  gpointer value;
  gboolean found = g_hash_table_lookup_extended(h->gHashTable, 
                                                (char *) key,
                                                NULL,   // gpointer *orig_key
                                                &value);// gpointer *value
  if (!found) {
    return result;
  }
  result.found = 1;
  result.value = GPOINTER_TO_INT(value);
  return result;
}

/**
Decrement reference count and free if ref count is not 0.
@parm hash_table the hash table pointer
*/
static void hashSIUnref(HashSI *h) {
  assert(h);
  g_hash_table_unref(h->gHashTable);
  free(h);
}

static unsigned hashSIPrint_helper_counter = 0;
static void hashSIPrint_helper(gpointer key, 
                               gpointer value, 
                               gpointer user_data) {
  hashSIPrint_helper_counter++;
  printf("%u: %s-->%i\n", 
         hashSIPrint_helper_counter, 
         (char *) key, 
         GPOINTER_TO_INT(value));
} // hashSIPrint_helper

/**
Print key value pairs to stdout
*/
static void hashSIPrint(const HashSI *h) {
  hashSIPrint_helper_counter = 0;
  g_hash_table_foreach(h->gHashTable, hashSIPrint_helper, NULL);
} // hashSIPrint

static guint hashSISize(const HashSI *h) {
  assert(h);
  return g_hash_table_size(h->gHashTable);
}

/**
Unit test of hashSI... functions
*/
static void hashSITest() {
  const unsigned verbose = 0;
  HashSI *h = hashSINew();
  HashSI_s result;

  // there was a bug (since fixed) in which a 0 value could be inserted
  // and never found.
  const char *g = "G";
  hashSIInsert(h, g, 0);
  result = hashSILookup(h, g);
  assert(result.found);
  assert(result.value == 0);

  // test updating the value for an existing key
  hashSIInsert(h, g, 1);
  result = hashSILookup(h, g);
  assert(result.found);
  assert(result.value == 1);

  const char * one = "one";
  hashSIInsert(h, one, 1);
  result = hashSILookup(h, one);
  assert(result.found);
  assert(result.value == 1);

  hashSIInsert(h, "minus six", -6);
  result = hashSILookup(h, "minus six");
  assert(result.found);
  assert(result.value == -6);

  result = hashSILookup(h, "secret");
  assert(!result.found);

  guint size = hashSISize(h);
  assert(size == 3);

  // test when strings are same but addresses are different
  // this test is broken because C allocates one string "G" statically
  // and sets both g1 and g2 to point to it.
  char * g1 = "G";
  char * g2 = "G";
  hashSIInsert(h, g1, 1);
  result = hashSILookup(h, g2);
  assert(result.found == 1);

  // here is a correct test
  // NOTE: cannot allocate in text segment, as we want to modify the value
  char *g3 = calloc(2, 1);
  *g3 = 'G'; // trailing 0 provided by calloc()
  result = hashSILookup(h, g3);
  assert(result.found == 1);  // a nice surprise as the pointers are different
  free(g3);

  if (verbose) hashSIPrint(h);

  hashSIUnref(h);
} // hashSITest

/**
Set values in global settings struct based in part on value in global options.

Start the log by writing the options and settings.
*/
static void makeSettings() {

  // setup results directory name
  // results directory name depends in non-default option values
  settings.resultsDir = g_string_new("../data/v5/working/imputeMissingCodes");
  // always include test value
  g_string_append_printf(settings.resultsDir, ",test=%u", options.test);
  // always include bigJump value
  g_string_append_printf(settings.resultsDir, ",bigJump=%u", options.bigJump);

  // create results dir
  GString *command = g_string_new("mkdir -p ");
  g_string_append(command, settings.resultsDir->str);
  int result = system(command->str);
  // when using -Werror, gcc requires that the result be examined
  // however, the statement just below is not portable because
  // the value returned is implementation defined
  assert(result == 0);  // this is not portable 
  g_string_free(command, TRUE); // TRUE==>free segment

  // setup output directory name
  settings.outputDir = g_string_new("../data/v5/outputs");

  // setup Log object and start logging to file and stdout
  GString *logPath = g_string_new(settings.resultsDir->str);
  g_string_append(logPath, "/log.txt");
  settings.log = Log_new(logPath->str, stdout);
  g_string_free(logPath, TRUE);
  LOG("log started\n");

  // write options
  LOG("options\n");
  LOGF(" test=%u\n", options.test);
  LOGF(" bigJump=%u\n", options.bigJump);
  LOGF(" createImputable=%u\n", options.createImputable);

  // write settings
  LOG("settings\n");
  LOGF(" resultsDir=%s\n", settings.resultsDir->str);
  LOGF(" outputDir =%s\n", settings.outputDir->str);

  if (options.test != 0)
    LOG("TESTING: DISCARD RESULTS\n");
} // makeSettings


/**
Open the database
*/
static void openDb() {
  GString *path = g_string_new(settings.outputDir->str);
  g_string_append(path, "/db.sqlite3");
  
  failIf(apop_db_open(path->str), "db did not open");
  
  g_string_free(path, 1); // 1-->free segment
} // openDb

/**
Open the named file in write mode in the results directory
@param resultsDir name of results directory
@param name name of file
*/
static FILE* openResultsFile(GString *resultsDir, const char *name) {
  GString *path = g_string_new(resultsDir->str);
  g_string_append(path, name);
  FILE *file = fopen(path->str, "w");
  assert(file);
  g_string_free(path, TRUE); // TRUE-->free segment
  
  return file;
} // openResultsFile


/**
Print to stdout and to specified file
*/
static void printTwice(FILE *file, const char *format, ...) {
  assert(file);
  assert(format);

  va_list argptr;
  va_start(argptr, format);
  vfprintf(stdout, format, argptr);
  vfprintf(file, format, argptr);
  va_end(argptr);
} // printTwice

/**
Mutate v by replacing every element with (v_i - mean) / stddev
@param v vector to mutate
*/
static void gslVectorStandardize(gsl_vector *v) {
  double mean;
  double stddev;
  gslVectorMeanStddev(v, &mean, &stddev);
  assert(stddev != 0.0);
  for (unsigned i = 0; i < v->size; i++) {
    const double oldValue = gsl_vector_get(v, i);
    const double newValue = (oldValue - mean) / stddev;
    gsl_vector_set(v, i, newValue);
  }
}

/**
Print anomolies in the data: NaN's and zero length string 
@param data the dataset
*/
static void apopDataPrintAnomolies(const apop_data *data) {
  // limit number of anomolies of each kind to print
  const unsigned limit = 100;    

  const unsigned checkAllText = 0;

  const unsigned nRows = data->matrix->size1;
  const unsigned nCols = data->matrix->size2;
  const unsigned nTexts = data->names->textct;

  const apop_name *names = data->names;

  printf("Anomolies: indices of NaN values in vector:\n");
  unsigned found = 0;
  for (unsigned i = 0; i < nRows; i++) {
    const double value = gsl_vector_get(data->vector, i);
    if (isnan(value)) {
      printf("%u\n", i);
      found++;
      if (found >= limit) {
        printf("stopping since hit reporting limit of %u\n", limit);
        break;
      }
    }
  }
  printf("\n");

  printf("Anomolies: indices of NaN values in matrix:\n");
  found = 0;
  for (unsigned i = 0; i < nRows; i++) {
    for (unsigned j = 0; j < nCols; j++) {
      const double value = gsl_matrix_get(data->matrix, i, j);
      if (isnan(value)) {
        printf("(%u,%u=%s)\n", 
               i, j, names->column[j]);
        found++;
        if (found >= limit) {
          printf("stopping since hit reporting limit of %u\n", limit);
          break;
        }
      }
    }
    if (found >= limit)
      break;
  }

  printf("\nAnomolies: zero length strings in text\n");
  found = 0;
  if (checkAllText) {
    printf("\nAnomolies: zero length strings in text\n");
    for (unsigned i = 0; i < nRows; i++) {
      for (unsigned j = 0; j < nTexts; j++) {
        const char * value = data->text[i][j];
        if (strlen(value) == 0) {
          printf("(%u,%u=%s)\n", 
                 i, j, names->text[j]);
          found++;
          if (found >= limit) {
            printf("stopping since hit reporting limit of %u\n", limit);
            break;
          }
        }
      }
      if (found >= limit)
        break;
    }
  }

  printf("\nAnomolies: matrix columns that are always NaN\n");
  for (unsigned col = 0; col < nCols; col++) {
    unsigned allNan = 1;
    for (unsigned row = 0; row < nRows; row++) {
      const double value = gsl_matrix_get(data->matrix, row, col);
      if (!isnan(value)) {
        allNan = 0;
        break;
      }
    }
    if (allNan) printf("%u=%s", col, names->column[col]);
  }
  printf("\n");

  printf("\nAnomolies: text columns that are always zero length strings\n");
  const unsigned nTextCols = data->names->textct;
  for (unsigned col = 0; col < nTextCols; col++) {
    unsigned allZeroLength = 1;
    for (unsigned row = 0; row < nRows; row++) {
      const char *value = data->text[row][col];
      if (strlen(value) != 0) {
        allZeroLength = 0;
        break;
      }
    }
    if (allZeroLength) printf(" %u=%s\n", col, names->text[col]);
  }
} // apopDataPrintAnomolies

/**
Print a row of data from a dataset
@param data the dataset
@param rowIndex row to print
*/
static void apopDataPrintRow(const apop_data *data, unsigned rowIndex) {
  if (data->vector) {
    printf("row %u target=%g\n", 
           rowIndex, gsl_vector_get(data->vector, rowIndex));
  }
  else {
    printf("row %u has no target\n", rowIndex);
  }

  printf("feature row %u=", rowIndex);
  for (unsigned colIndex = 0; colIndex < data->matrix->size2; colIndex++) {
    if (colIndex > 0) printf("|");
    printf("%g", gsl_matrix_get(data->matrix, rowIndex, colIndex));
  }
  printf("\n");
} // apopDataPrintRow

/**
Print all the sizes and names associated with a dataset 
@param data the data set
*/
static void apopDataPrintSummary(const apop_data *data) {
  if (data == NULL) {
    printf("apopDataPrintSummary: data is NULL, nothing to print\n");
    return;
  }

  const apop_name *names = data->names;
  printf("basic description:");
  printf(" apop_data title = %s\n", names->title);
  printf(" apop_data vector name = %s\n", names->vector);

  if (data->matrix == NULL) 
    printf(" matrix is not present\n");
  else
    printf(" matrix is %lu x %lu\n", data->matrix->size1, data->matrix->size2);

  if (data->vector == NULL)
    printf(" vector is not present\n");
  else
    printf(" vector has %lu rows\n", data->vector->size);

  if (names == NULL)
    printf(" names is not present\n");
  else
    printf(" names has %i columns\n", names->textct);

  printf(" %i rows have a name\n", names->rowct);
  printf(" %i columns in matrix have a name\n", names->colct);
  printf(" %i text columns have a name\n", names->textct);

  printf("matrix column names=");
  for (unsigned col = 0; col < names->colct; col++) {
    if (col > 0) printf("|");
    printf("%s", names->column[col]);
  }
  printf("\n\n");

  printf("text column names=");
  for (unsigned col = 0; col < names->textct; col++) {
    if (col > 0) printf("|");
    printf("%s", names->text[col]);
  }
  printf("\n");

  // print first and last rows
  apopDataPrintRow(data, 0);
  apopDataPrintRow(data, data->matrix->size1 - 1);
} // apopDataPrintSummary

////////////////////////////////////////////////////////////////////////////////
// recodeData...
////////////////////////////////////////////////////////////////////////////////

/**
Recode the data to make ranges similar to each other.

Size features are those that one might expect the value to double if
the feature doubled.

Make these transformations:
-Standardize size features
-Convert text fields to 1 of K with NaN values for missing data
-Drop column flood_zone_community_panel_id, as its always a zero-length string
-Drop matrix features that are not in the model; standardize size features
-Drop text features that are not in the model; 1 of K code the others
@param data the dataset; mutated
*/
static void recodeData(apop_data *data) {
  // 0. For the vector
  recodeDataVectorLogP1(data);  // recodes "sale_amount"

  // 1. for each  matrix column names
  recodeDataDate(data, "sale_date");
  recodeDataSize(data, "land_value_calculated");
  recodeDataSize(data, "improvement_value_calculated");
  recodeDataImprovementFraction(data); // improvement_value/total_value
  recodeDataSize(data, "tax_amount");
  recodeDataSize(data, "acres");
  recodeDataSize(data, "living_square_feet");
  recodeDataStandardize(data, "effective_year_built");
  recodeDataSize(data, "bedrooms");
  recodeDataSize(data, "total_rooms");
  recodeDataSize(data, "total_baths");
  recodeDataSize(data, "fireplace_number");
  recodeDataSize(data, "parking_spaces");
  recodeDataSize(data, "stories_number");
  recodeDataStandardize(data, "latitude");
  recodeDataStandardize(data, "longitude");
  recodeDataSize(data, "average_commute");
  recodeDataStandardize(data, "fraction_owner_occupied");
  recodeDataSize(data, "household_median_income");

  // 2. for selected text column names
  // Include only features of the parcel or transaction; hence exclude
  // - codes that are identifiers of parcels
  // - codes that are identifiers of deeds
  // - codes that are redundant with other codes
  //   ex: don't recode census tract since we have the actual census data
  //   ex: don't recode location info since we have latitude and longitude
  //   ex: land use, since have zoning and flood zone
  // - codes that are features of the ownership
  //   ex: homestead exempt, absentee indicator
  // - codes that are always the same; the logic in recodeDataCode does this
  // - codes that are features of a data processing system, not the parcel
  //   ex: *_book (pointers to where manual-kept info was stored)
  const unsigned maxN = 20; // max number of codes allowed in a column
  recodeDataNCode(data, "document_type_code", maxN);  // grant or trust deed
  recodeDataNCode(data, "transaction_type_code", maxN);

  recodeDataNCode(data, "zoning", maxN); // has 3085 distinct codes
  recodeDataNCode(data, "flood_zone_community_panel_id", maxN);

  recodeDataNCode(data, "property_indicator_code", maxN); // residential, condo, ...
  recodeDataNCode(data, "view", maxN);
  recodeDataNCode(data, "location_influence_code", maxN);

  recodeDataNCode(data, "air_conditioning_code", maxN);
  recodeDataNCode(data, "condition_code", maxN);
  recodeDataNCode(data, "construction_type_code", maxN);
  recodeDataNCode(data, "exterior_walls_code", maxN);

  // these two seem redundant
  // when the fireplace_indicator_flag is 'Y',
  // the fireplace_type_code is always "001", which means "unknown" type
  recodeDataFlag(data, "fireplace_indicator_flag"); // "Y" or blank
  // fireplace_code is always code blank or the code for unknown
  //recodeDataNCode(data, "fireplace_type_code", maxN);

  recodeDataNCode(data, "foundation_code", maxN);
  recodeDataNCode(data, "floor_code", maxN);
  recodeDataNCode(data, "frame_code", maxN);
  recodeDataNCode(data, "garage_code", maxN);
  recodeDataNCode(data, "heating_code", maxN);
  recodeDataFlag(data, "mobile_home_indicator_flag"); // "Y" or blank
  recodeDataNCode(data, "parking_type_code", maxN);
  
  // these two seem redundant
  // record counts in observations
  // - with a pool = 143,151
  // - with a pool_code = 148,716
  // - with a pool_code coded "type unknown" = 138,413
  //   (perhaps intended to code 1 pool)
  // most popular pool codes of the 143,151 (where pool_flag = 'Y')
  // - 001 --> type unknown (maybe 1 pool) = 138,413
  // - 300 --> pool/spa                    =   4,389
  // - 00H --> heated                            322
  // CONCLUSION:
  // there are pools and spas
  // pools are designated by pool_flag = "Y"
  // spas are designated only by pool_code = "S00"
  recodeDataFlag(data, "pool_flag");
  recodeDataSpa(data);

  recodeDataNCode(data, "quality_code", maxN);
  recodeDataNCode(data, "roof_cover_code", maxN);
  recodeDataNCode(data, "roof_type_code", maxN);
  recodeDataNCode(data, "style_code", maxN);
  recodeDataNCode(data, "units_number", maxN);
  recodeDataNCode(data, "water_code", maxN);
} //recodeData

// this function is needed to do the 1-of-K encoding
// SO DO NOT DELETE IT
#if 0  
/**
Add numeric features to 1-of-K encode a code column
@param data the dataset; mutated
@param cName the name of the column
*/
static void recodeDataCode(apop_data *data, const char *cName) {
  recodeDataWorker(data, cName, 'c'); // 'c' --> regular code
} //recodeDataCode
#endif

/**
Recode a date by determining days past epoch, then standardizing

The epoch is 1970-01-01.
@param data the dataset; mutated
@param cName column name
*/
static void recodeDataDate(apop_data *data, const char *cName) {
  const unsigned verbose = 0;

  unsigned col = apopColumnNameMatrix(data, cName);

  
  GTimeZone *tz = g_time_zone_new("Z"); // UTC time zone
  failIf(tz == NULL, "alloction of time zone");
  GDateTime *epoch = g_date_time_new(tz,
                                     1970,  // 1970-01-01
                                     1,     // month
                                     1,     // year
                                     0,     // hour
                                     0,     // minute
                                     0.0);  // seconds

  // create vector of differences in days between observation date and epoch
  const unsigned nObs = data->matrix->size1;
  assert(nObs > 0);
  gsl_vector *diffs = gsl_vector_alloc(nObs);
  for (unsigned i = 0; i < nObs; i++) {
    const double obsDate = gsl_matrix_get(data->matrix, i, col);
    vp("obs %u col %u obsDate %8f", i, col, obsDate);
    // obsDate may have a fraction, because of input conversion
    const double obsDateRounded = round(obsDate);
    const int year = obsDateRounded / 10000.0;
    const int month = (obsDateRounded - year * 10000) / 100;
    const int day = ((int) obsDateRounded) % 100;
    // convert zero day number to day 01
    const int dayFixed = (day == 0) ? 1 : day;
    vp(" year %i month %i day %i", year, month, dayFixed);
    GDateTime *dt = g_date_time_new(tz,
                                    year,
                                    month,
                                    dayFixed,
                                    0,
                                    0,
                                    0.0);
    // calculate end - begin in microseconds
    GTimeSpan span = g_date_time_difference(dt,     // end time
                                            epoch); // begin time
    const double days = span / G_TIME_SPAN_DAY;
    vp("span %lu days %8f\n", span, days);
    gsl_vector_set(diffs, i, days);
  }
  gslVectorStandardize(diffs);
  apopSetMatrixColumn(data, col, diffs);

  // free 
  gsl_vector_free(diffs);
  g_time_zone_unref(tz);
  g_date_time_unref(epoch);
} // recodeDataDate


/**
Recode a flag column; it is true iff value is "Y"
@param data the data set; mutated
@param cName column name
*/
static void recodeDataFlag(apop_data *data, const char *cName) {
  recodeDataWorker(data, cName, 'f');  // f --> flag
} // recodeDataFlag

/**
Create new feature improvement_value/total_value
@param data the data set; mutated by adding a new feature column
*/
static void recodeDataImprovementFraction(apop_data *data) {
  assert(data);
  
  const unsigned colImprovement = 
    apopColumnNameMatrix(data, "improvement_value_calculated");
  const unsigned colLand = 
    apopColumnNameMatrix(data, "land_value_calculated");

  const unsigned nObs = data->matrix->size1;
  gsl_vector *fractions = gsl_vector_alloc(nObs);

  for (unsigned i = 0; i < nObs; i++) {
    const double land = 
      apop_data_get(.data=data, .row=i, .col=colLand);
    const double improvement =
      apop_data_get(.data=data, .row=i, .col=colImprovement);
    const double fraction = land / (land + improvement);
    gsl_vector_set(fractions, i, fraction);
  }

  apopAppendColumn(data, fractions, "ImprovementFraction");
  
  gsl_vector_free(fractions);

} // recodeDataImprovementFraction

/**
Add a matrix column that recodes a text column into 0, 1, .., N-1 and NaN

Where there are N distinct values in the field. Don't do this if there
are more than maxN values.
@param apop_data the data set; possibly mutated
@param cName name of text column to examine
@param maxN maximum number of codes to accept
*/
static void recodeDataNCode(apop_data *data, const char *cName, unsigned maxN) {
  const unsigned verbose = 0;
  assert(data);
  assert(cName);

  const unsigned nObs = data->matrix->size1;
  const unsigned col = apopColumnNameText(data, cName);

  HashSI *codeOccurrence = hashSINew();
  gsl_vector *v = gsl_vector_alloc(nObs);

  unsigned nDistinctCodes = 0;
  for (unsigned i = 0; i < nObs; i++) {
    const char *code = data->text[i][col];
    vp("code=%s\n", code);
    if (strcmp(code, "") == 0) {
      gsl_vector_set(v, i, NAN);
    }
    else {
      HashSI_s result = hashSILookup(codeOccurrence, code);
      if (result.found) {
        gsl_vector_set(v, i, result.value);
      }
      else {
        hashSIInsert(codeOccurrence, code, nDistinctCodes);
        gsl_vector_set(v, i, nDistinctCodes);
        nDistinctCodes++;
      }
    }
    vp("v[%u]=%g\n", i, gsl_vector_get(v, i));
  }
  vp("nDistinctCodes=%u\n", nDistinctCodes);

  if (nDistinctCodes == 0) {
    LOGF("Did not N-code %s, since all codes were blanks\n",
           cName);
    gsl_vector_free(v);
    hashSIUnref(codeOccurrence);
    return;
  }

  if (nDistinctCodes == 1) {
    LOGF("Did not N-code %s, since there was only 1 non-blank code\n",
           cName);
    gsl_vector_free(v);
    hashSIUnref(codeOccurrence);
    return;
  }

  if (nDistinctCodes > maxN) {
    LOGF("Did not N-code %s, since had %u distinct value\n",
           cName, nDistinctCodes);
    gsl_vector_free(v);
    hashSIUnref(codeOccurrence);
    return;
  }

  GString *newName = g_string_new(cName);
  newName = g_string_append(newName, "-ncoded");
  apopAppendColumn(data, v, newName->str);

  g_string_free(newName, TRUE); // TRUE-->free the char * structure as well
  gsl_vector_free(v);
  hashSIUnref(codeOccurrence);

  LOGF("recoded %s: %d distinct codes found\n", cName, nDistinctCodes);
} // recodeDataNCode

/** 
Recode a size variable by taking the log base e and then standardizing.

Raise an error if the value is always the same, as in that case, the standard
deviation is zero and standardization cannot be done.

The variable may be zero, so add 1 before taking log.
@param data the dataset; mutated
@param cName the column name
*/
static void recodeDataSize(apop_data *data, const char *cName) {
  assert(data);
  assert(cName);
  unsigned verbose = 0;
  if (strcmp(cName, "units_number") == 0)
    verbose = 0;
  const unsigned colIndex = apopColumnNameMatrix(data, cName);

  const unsigned nObs = data->matrix->size1;
  assert(nObs > 0);
  
  // take log of (v + 1)
  gsl_vector *v = gsl_vector_alloc(nObs);
  assert(v != NULL);

  double firstValue = 0;
  unsigned allSame = 1;
  for (unsigned i = 0; i < nObs; i++) {
    const double value = apop_data_get(.data=data, .row=i, .col=colIndex);

    // check for all identical values
    if (i == 0) firstValue = value;
    if (firstValue != value) allSame = 0;

    const double logValueP1 = log(value + 1);
    vp("cName %s i %u oldValue %g newValue %g\n", 
       cName, i, value, logValueP1);
    gsl_vector_set(v, i, logValueP1);
  }

  failIf(allSame, "cannot standardize %s, as all values are same (%g)",
         cName, firstValue);

  // standardize and set in matrix
  gslVectorStandardize(v);
  apopSetMatrixColumn(data, colIndex, v);

  // free
  gsl_vector_free(v);
} // recodeDataSize           

/**
Recode the pool_code field to pull out just the spas.

The spas have code "S00" in observations in which there is a pool.
@param data the dataset; mutated
@param cName the field name
*/
static void recodeDataSpa(apop_data *data) {
  assert(data);
  unsigned poolFlagCol = apopColumnName(data, "pool_flag-is-Y", 'c');
  unsigned poolCodeCol = apopColumnName(data, "pool_code", 't');

  const unsigned nObs = data->matrix->size1;
  gsl_vector *v = gsl_vector_alloc(nObs);
  unsigned foundOne = 0;
  unsigned foundZero = 0;
  for (unsigned i = 0; i < nObs; i++) {
    const double flag = apop_data_get(.data = data, 
                                       .row = i, 
                                       .col = poolFlagCol);
    assert(!isnan(flag));
    const char *code = data->text[i][poolCodeCol];
    const unsigned codeIsSpa = strcmp(code, "S00");
    if (flag == 1.0) {
      gsl_vector_set(v, i, codeIsSpa ? 1.0 : 0.0);
      foundOne = 1;
    }
    else {
      gsl_vector_set(v, i, 0.0); // no spa
      foundZero = 1;
    }
  }

  if (foundOne && foundZero) {
    LOG("adding spa column\n");
    apopAppendColumn(data, v, "has-spa");
  }
  else if (foundOne && !foundZero) {
    LOG("not adding spa column, as never found a 0 indicator\n");
  }
  else if (!foundOne && foundZero) {
    LOG("not adding spa column, as never found a 1 indicator\n");
  }
  else {
    LOG("not adding spa column, as never found a pool_flag = 1");
  }
  gsl_vector_free(v);
} // recodeDataSpa

/**
Recode a numeric variable by standardizing it.
@param data the data set; mutated
@param cName the column name
*/
static void recodeDataStandardize(apop_data *data, const char *cName) {
  const unsigned colIndex = apopColumnNameMatrix(data, cName);

  const unsigned nObs = data->matrix->size1;
  assert(nObs > 0);
  
  // extract the column
  gsl_vector *v = gsl_vector_alloc(nObs);
  assert(v != NULL);

  for (unsigned i = 0; i < nObs; i++) {
    const double value = apop_data_get(.data=data, .row=i, .col=colIndex);
    gsl_vector_set(v, i, value);
  }

  // standardize and set in matrix
  gslVectorStandardize(v);
  apopSetMatrixColumn(data, colIndex, v);

  // free
  gsl_vector_free(v);
} // recodeDataStandardize

/**
Make gsl_vector that holds the 1-of-N encoding for a column
*/
static gsl_vector* recodeDataTransformCode(const apop_data *data,
                                           unsigned col,
                                           const char *currentCode) {
  assert(data);
  assert(currentCode);
  assert(col < data->textsize[1]);

  // build vector of indicators, using NaN if value was blank
  const unsigned nObs = data->textsize[0];
  gsl_vector *v = gsl_vector_alloc(nObs);
  for (unsigned i = 0; i < nObs; i++) {
    const char *nextValue = data->text[i][col];
    if (strcmp(nextValue, "") == 0) 
      gsl_vector_set(v, i, NAN);
    else if (strcmp(nextValue, currentCode) == 0)  
      gsl_vector_set(v, i, 1.0);
    else
      gsl_vector_set(v, i, 0.0);
  }
  return v;
} // recodeDataTransformCode


/**
Convert a text column into a gsl indicator vector
@param data the data set
@param col  the column number in the text portion of the dataset
@param currentCode the value used to build the indicator: is-currentCode

Also look for blank values and code them a NaNs.

Thus the vector is tri-valued: {0, 1, Nan}
*/
static gsl_vector* recodeDataTransformFlag(const apop_data *data,
                                           unsigned col,
                                           const char *currentCode) {
  assert(data);
  assert(currentCode);
  assert(col < data->textsize[1]);

  // build vector of indicators, using NaN if value was blank
  const unsigned nObs = data->textsize[0];
  gsl_vector *v = gsl_vector_alloc(nObs);
  for (unsigned i = 0; i < nObs; i++) {
    const char *nextValue = data->text[i][col];
    if (strcmp(nextValue, "Y") == 0)
      gsl_vector_set(v, i, 1.0);
    else
      gsl_vector_set(v, i, 0.0);
  }
  return v;
} // recodeDataTransformFlag

/**
Recode the vector values by replacing each with log(x+1)
@param data the data set; mutated
@param cName the column name
*/
static void recodeDataVectorLogP1(apop_data *data) {
  assert(data);
  
  const unsigned colIndex = -1;
  const unsigned nObs = data->matrix->size1;

  for (unsigned i = 0; i < nObs; i++) {
    const double current = apop_data_get(.data=data, .row=i, .col=colIndex);
    const double new = log(current + 1);
    apop_data_set(.data=data, .row=i, .col=colIndex, .val=new);
  }
} // recodeDataLogP1

/**
Recode a code column
@param data the dataset; mutated
@param cName column name
@param recodF function to return a column of recoded values
@param kind 'c'--> a regular code (like air_conditioning_code)
            'f'--> a flag ("Y" means present, anything else means not present)
*/
static void recodeDataWorker(apop_data *data, 
                             const char *cName,
                             char kind) {
  assert(data);
  assert(cName);
  assert(kind == 'c' || kind == 'f');
  const unsigned verbose = 0;
  if (verbose > 0) {
    printf("data on entry");
    apopDataPrintSummary(data);
  }
  unsigned col = apopColumnNameText(data, cName);
  vp("text col %u\n", col);
  vp("text sizes %lu %lu\n", data->textsize[0], data->textsize[1]);
  assert(col < data->textsize[1]);

  ArrayS *values = distinctTextValues(data, cName);
  assert(values);
  const unsigned nCodeValues = arraySSize(values);
  assert(nCodeValues > 0);

  // if only 1 code value, do no recoding, because the column has no info
  // unless we are processing a flag column
  if ((kind == 'c') && (nCodeValues == 1)) {
    printf("column %s has only code %s, so it is not converted and appended\n",
           cName, arraySIndex(values, 0));
    return;
  }

  // determine number of new code columns
  // there is one new code column for every non-blank value
  unsigned nNewCols = 0;
  if (kind == 'f') {
    // since a kind column, only check if there is at least one "Y" value
    for (unsigned i = 0; i < arraySSize(values); i++) {
      const char *value = arraySIndex(values, i);
      if (strcmp(value, "Y") == 0) {
          nNewCols = 1;
          break;
        }
    }
  }
  else {
    for (unsigned i = 0; i < arraySSize(values); i++) {
      const char *value = arraySIndex(values, i);
      if (strcmp(value, "") == 0)
        continue;
      nNewCols++;
    }
  }
  vp("number of new columns %u\n", nNewCols);
  if (nNewCols == 0) {
    printf("all values are missing, so column not added\n");
    return;
  }
  if ((kind == 'c') && (nNewCols == 1)) {
    printf("code %s has only 1 non-missing value, so column not added\n",
           cName);
    return;
  }

  const unsigned nObs = data->textsize[0];
  apop_data *newData = apop_data_alloc_base(0, nObs, nNewCols); // just matrix
  if (verbose != 0) {
    printf("Summary of new data (newData)\n");
    apopDataPrintSummary(newData);
  }

  // build up the matrix inside the apop_data *newData
  // one pass for each code value
  char ** newColumnNames = calloc(nNewCols, sizeof(char *));
  unsigned nextValueIndex = 0;
  for (unsigned newColIndex = 0; newColIndex < nNewCols; newColIndex++) {
    // advance to next code from values, skipping blank values
    char *currentCode = NULL;
    if (kind == 'f') {
      currentCode = "Y";
    }
    else {
      do { 
        currentCode = arraySIndex(values, nextValueIndex);
        nextValueIndex++;
      }
      while (strcmp(currentCode, "") == 0);
    }

    gsl_vector *v;
    if (kind == 'c')
      v = recodeDataTransformCode(data, col, currentCode);
    else
      v = recodeDataTransformFlag(data, col, currentCode);


    apopSetMatrixColumn(newData, newColIndex, v);
    gsl_vector_free(v);

    // set column name to cName .. "-is-" .. currentCode
    GString *newName = g_string_new(cName);
    newName = g_string_append(newName, "-is-");
    newName = g_string_append(newName, currentCode);
    newColumnNames[newColIndex] = newName->str;
    // don't free newName, as otherwise we would have a dangling pointer
  }

  if (verbose > 0) {
    printf("New column names\n");
    for (unsigned i = 0; i < nNewCols; i++) {
      printf(" %u: %s\n", i, newColumnNames[i]);
    }
    // print compactly size value are in {0, 1, NaN}
    printf("New matrix of indicators (1 of K encodings)\n");
    for (unsigned i = 0; i < nObs; i++) {
      for (unsigned j = 0; j < nNewCols; j++) {
        printf("%4g", apop_data_get(.data = newData, .row = i, .col = j));
      }
      printf("\n");
    }
  }

  // append the nd matrix to the data matrix
  // first insert the names
  apop_name *newNames = apop_name_alloc();
  assert(newNames != NULL);
  newNames->colct = nNewCols;
  newNames->column = newColumnNames;
  newData->names = newNames;
  vp("newData with names\n");
  if (verbose) apopDataPrintSummary(newData);

  // append the names
  //apop_name_stack(data->names, newNames, 'c', 'c'); // c-->columns

  // append the matrices
  apop_data_stack(.m1 = data, .m2 = newData, .posn = 'c', .inplace = 'y');
  if (verbose) apopDataPrintSummary(data);

  arraySUnref(values);
  
  
} // recodeDataWorker

////////////////////////////////////////////////////////////////////////////////
// end recodeData...
////////////////////////////////////////////////////////////////////////////////

/**
Remove some ncode columns from dataset

Balance
- having enought observations to do the imputation
- having something to impute

@param data the dataset; mutated by dropping certain columns
*/
static void reduceCodeColumns(apop_data *data) {
  const unsigned verbose = 1;
  vp("reduceCodeColumns\n");
  assert(data);

  const unsigned nObs = data->matrix->size1;
  const unsigned nFeatureCols = data->matrix->size2;

  vp("nObs %u nFeatureCols %u\n", nObs, nFeatureCols);

  // determine set of col indices of ncoded names
  // these column name end in "-ncoded"
  // build up hash of ncoded column names for later use
  const apop_name *dataNames = data->names;
  assert(dataNames->colct == nFeatureCols);
  SetI   *ncoded = setINew();
  HashIS *names  = hashISNew();
  for (unsigned k = 0; k < nFeatureCols; k++) {
    const char *colName = dataNames->column[k];
    if (strSuffixEqual(colName, "-ncoded")) {
      setIAdd(ncoded, k);
      hashISInsert(names, k, colName);
    }
  }

  SetI *logicallyDeleted = setINew();
  if (verbose > 0) {
    printf("initial ncoded=");
    setIPrint(ncoded);
    printf("initial logicallyDeleted=");
    setIPrint(logicallyDeleted);
  }
  unsigned nRemainingInitially = countRemainingObservations(data, 
                                                            ncoded, 
                                                            logicallyDeleted);
  printf("number initially remaining = %d\n", nRemainingInitially);
  ArrayD *deletedIndices = arrayDNew();
  ArrayD *nRemaining = arrayDNew();
  reduceCodeColumnsIter(data, 
                        ncoded, 
                        logicallyDeleted, 
                        deletedIndices,
                        nRemaining);
  assert(arrayDSize(deletedIndices) == arrayDSize(nRemaining));
  printf("resulting nCoded=");
  setIPrint(ncoded);
  printf("resulting LogicallyDeleted=");
  setIPrint(logicallyDeleted);

  // determine columns to remove
  // the deleted columns will be those before the big jump
  // print to stdout and write file
  GString *path = g_string_new(settings.resultsDir->str);
  g_string_append(path, "/analysis-remove-columns.txt");
  FILE *file = fopen(path->str, "w");
  assert(file);
  g_string_free(path, TRUE); // TRUE-->also free segment
  // I could not get printTwice to run w/o a seg fault on the stmt below
  // So I just wrote out the two calls
  //printTwice(file, 
  //           "%9s %30s %10s\n", 
  //           "col Index",
  //           "col Name",
  //           "nRemaining");
  fprintf(file,   "%9s %30s %10s\n", "col Index", "col Name", "nRemaining");
  fprintf(stdout, "%9s %30s %10s\n", "col Index", "col Name", "nRemaining");
  double prevRemaining = nRemainingInitially;
  ArrayD *toRemove = arrayDNew();
  for (unsigned i = 0; i < arrayDSize(deletedIndices); i++) {
    const double index = arrayDIndex(deletedIndices, i);
    const double remaining = arrayDIndex(nRemaining, i);
    const double jump = remaining - prevRemaining;
    const HashIS_s result = hashISLookup(names, (int) index);
    assert(result.found);
    printTwice(file,
               "%9g %30s %10g\n", 
               index,
               remaining,
               result.value);
    if (jump > options.bigJump)
      break;
    arrayDAppend(toRemove, index);
    prevRemaining = remaining;
  }
  fclose(file);

  // remove the columns before the big jump
  apopDropMatrixColumns(data, toRemove);

  arrayDUnref(toRemove);

  setIUnref(ncoded);
  hashISUnref(names);
  setIUnref(logicallyDeleted);
  arrayDUnref(deletedIndices);
  arrayDUnref(nRemaining);
} // reduceCodeColumns

/**
Determine an order to eliminate columns in data.
@param data  the data set
@param examined set of column indices to examine
@param excluded subset of examined, these columns are not examined 
@param deletedIndices each index in examined-excluded is put into this array
@param nRemaining number of observations remaining after the corresponding index
                  in deletedIndices was removed
*/
static void reduceCodeColumnsIter(apop_data *data,
                                  SetI      *examined,
                                  SetI      *excluded,
                                  ArrayD    *deletedIndices,
                                  ArrayD    *nRemaining) {
  // stop recursion if no more to examine
  printf("status quo examined="); setIPrint(examined);
  printf("status quo excluded="); setIPrint(excluded);
  if (setISize(examined) == 0)
    return;

  // determine number of obs remaining if delete no additional columns
  const unsigned statusQuo = countRemainingObservations(data,
                                                        examined,
                                                        excluded);
  printf("num obs remaining if status quo = %u\n", statusQuo);

  // determine argmax(number of obs remaining) 
  // if remove one column from examined
  unsigned nColumns = data->matrix->size2;
  unsigned maxRemaining = 0;
  unsigned maxK = 0;
  for (unsigned k = 0; k < nColumns; k++) {
    if (setIContains(examined, k) && !setIContains(excluded, k)) {
      SetI *tempExamined = setICopy(examined);
      setIRemove(tempExamined, k);
      unsigned remaining = countRemainingObservations(data, 
                                                      tempExamined,
                                                      excluded);
      printf("%u remain, if remove %u from examined, leaving\n       ", 
             remaining, k);
      setIPrint(tempExamined);
      if (remaining > maxRemaining) {
        maxRemaining = remaining;
        maxK = k;
      }
      setIUnref(tempExamined);
    }
  }

  // record and print the best k
  printf("num obs remaining if greedily delete column %u = %u\n", 
         maxK, maxRemaining);

  // give up if no improvement from the greedy next step
  if (statusQuo >= maxRemaining)
    return;

  // keep track of the greedy solution
  arrayDAppend(deletedIndices, maxK);
  arrayDAppend(nRemaining, maxRemaining);

  // recursively call self
  setIRemove(examined, maxK);
  setIAdd(excluded, maxK);
  reduceCodeColumnsIter(data, examined, excluded, deletedIndices, nRemaining);
} // reduceCodeColumnsIter

/**
Does any suffix of s exactly equal the suffix?
*/
static gboolean strSuffixEqual(const char *s, const char *suffix) {
  assert(s);
  assert(suffix);
  for (unsigned i = 0; i < strlen(s); i++) {
    if (strcmp(s + i, suffix) == 0)
      return TRUE;
  }
  return FALSE;
} // strSuffixEqual

/**
Return pointer to a new SetI
*/
static SetI* setINew() {
  SetI *s = malloc(sizeof(SetI));
  assert(s);
  s->gHashTable = g_hash_table_new(g_direct_hash, g_direct_equal);
  assert(s->gHashTable);
  return s;
} // setINew

/**
Free a SetI
*/
static void setIUnref(SetI *s) {
  assert(s);
  g_hash_table_unref(s->gHashTable);
  free(s);
} // setIUnref

/**
Add element to SetI
*/
static void setIAdd(SetI *s, gint element) {
  assert(s);
  gint *p = GINT_TO_POINTER(element);
  g_hash_table_add(s->gHashTable, p);
} // SetIAdd

/**
Determine if element is in the set.
@param s the set
@param element the element
@return true if element in set, otherwise false
*/
static gboolean setIContains(const SetI *s, gint element) {
  assert(s);
  return g_hash_table_lookup_extended(s->gHashTable,
                                      GINT_TO_POINTER(element),
                                      NULL,
                                      NULL);
} // SetIContains

/**
make a copy
@param s set to copy
*/
static SetI* setICopy(const SetI* s) {
  assert(s);
  SetI* result = setINew();
  SetIIter iter;
  setIIterInit(s, &iter);
  gint element;
  while(setIIterNext(&iter, &element)) {
    setIAdd(result, element);
  }
  return result;
} // setICopy

/**
Print set on stdout
*/
static void setIPrint(const SetI *s) {
  assert(s);
  printf("SetI(");
  SetIIter iter;
  setIIterInit(s, &iter);
  gint element;
  gboolean first = TRUE;
  while (setIIterNext(&iter, &element)) {
    if (!first) printf(",");
    printf("%d", element);
    first = FALSE;
  }
  printf(")\n");
} // setIPrint

/**
Remove element from set
@param s the set
@param element the element
@return true if element was in the set and removed, otherwise return false
*/
static gboolean setIRemove(SetI *s, gint element) {
  assert(s);
  return g_hash_table_remove(s->gHashTable, GINT_TO_POINTER(element));
} // setIRemove

/**
Return size of a SetI
*/
static guint setISize(const SetI *s) {
  assert(s);
  return g_hash_table_size(s->gHashTable);
} // setISize

/**
Initialize an iterator
*/
static void setIIterInit(const SetI *s, SetIIter *iter) {
  assert(s);
  assert(iter);
  g_hash_table_iter_init(iter, s->gHashTable);
} // setIIterInit

/**
Take the next step using an iterator
*/
static gboolean setIIterNext(SetIIter *iter, gint *elementP) {
  assert(iter);
  assert(elementP);
  gpointer p; 
  gboolean another = g_hash_table_iter_next(iter, &p, NULL);
  gint value = GPOINTER_TO_INT(p);
  *elementP = value;
  return another;
} // setIIterNext


void setITest() {
  SetI *s = setINew();
  assert(0 == setISize(s));

  setIAdd(s, 27);
  setIAdd(s, 59);
  assert(2 == setISize(s));

  assert(setIContains(s, 27));
  assert(setIContains(s, 59));

  SetI *copy = setICopy(s);
  assert(copy != s);
  assert(setISize(copy) == 2);
  assert(setIContains(copy, 27));
  assert(setIContains(copy, 59));
  setIUnref(copy);

  assert(!setIContains(s, 0));
  setIAdd(s, 0);
  assert(setIContains(s, 0));
  assert(3 == setISize(s));

  setIAdd(s, -50);
  assert(setIContains(s, -50));
  assert(4 == setISize(s));
  assert(setIRemove(s, -50));  // 50 is present and gets removed
  assert(!setIRemove(s, 1000)); // 1000 is not present

  // iterate over elements
  SetIIter iter;
  setIIterInit(s, &iter);
  gint element = -1;
  unsigned counter = 0;
  while (setIIterNext(&iter, &element)) {
    assert(element == 0 || element == 27 || element == 59);
    counter++;
  }
  assert(counter == 3);
  
  assert(setIRemove(s, 27));
  assert(!setIContains(s, 27));
  assert(2 == setISize(s));
  
  assert(setIRemove(s, 59));
  assert(!setIContains(s, 59));
  assert(1 == setISize(s));

  assert(!setIRemove(s, 59));
  assert(setIRemove(s, 0));

  assert(!setIRemove(s, 123));
  assert(0 == setISize(s));

  setIUnref(s);
} // setITest



#if 0
/**
convert string to unsigned integer, catching errors
*/
static unsigned long strToUnsignedLong(const char *str) {
  errno = 0;
  unsigned long result = strtoul(str, NULL, 10); // 10 ==> base
  failIf(errno != 0, "conversion of string to unsigned long: %s", str);
  return result;
}
#endif


/**
Run all unit tests of static functions
*/
static void unitTests() {
  arraySTest();
  arrayDTest();
  gslVectorTest();
  hashISTest();
  hashSITest();
  setITest();
}
