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
                            .createImputable = 1};

// GLOBAL setting structure
// values derived in part from options
// this structure is filled in by the main program
typedef struct {
  GString *resultsDir; // write non-output files here (ex: log file)
  GString *outputDir;
  Log_T    log;        // loging via macro LOG(log, format, ...);
  unsigned version;    
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

/* verbose print (vp): print if verbose is at least some value */
#define vp(...)  if (verbose > 0) fprintf(stderr, __VA_ARGS__)
#define vp1(...) if (verbose >= 1) fprintf(stderr, __VA_ARGS__)
#define vp2(...) if (verbose >= 2) fprintf(stderr, __VA_ARGS__)

////////////////////////////////////////////////////////////////////////////////
// LOCAL TYPE DECLARATIONS
////////////////////////////////////////////////////////////////////////////////


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

static void         hashSIUnitTest();   // unit test

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

static void      setIUnitTest(); // unit test


////////////////////////////////////////////////////////////////////////////////
// local function declarations
////////////////////////////////////////////////////////////////////////////////

static void     apopAppendColumn(apop_data *data, 
                                 gsl_vector *v, 
                                 const char* newName);
static unsigned apopColumnName(const apop_data *data,
                               const char      *cName,
                               char             designator);
static unsigned    apopColumnNameMatrix(const apop_data *data, 
                                        const char *cName);
static unsigned    apopColumnNameText(const apop_data *data, const char *cName);
//static void        apopDataDropRowsIfNanTarget(apop_data *data);
static gboolean    apopDataHasNan(const apop_data *data);
static void        apopDataPrintAnomolies(const apop_data *data);
static void        apopDataPrintSummary(const apop_data *data);
static void        apopDataPrintRow(const apop_data *data, unsigned rowIndex);
static gsl_vector* apopDataRemoveColumns(const apop_data *data,
                                         unsigned         rowIndex,
                                         const ArrayD    *keptColIndices);
static void        apopDropMatrixColumn(apop_data *data, const char *cName);
static void        apopDropMatrixColumns(apop_data *data, const ArrayD *nums);
static void        apopDropRows(apop_data *data, 
                                const ArrayD *droppedRowIndices);
static void        apopModelPrintSummary(const apop_model *model);
static void        apopPrintSummary(const apop_data *data,
                                    FILE *file,
                                    const char *heading,
                                    unsigned nObs);
static void        apopSetMatrixColumn(apop_data *data, 
                                       unsigned colNumber, 
                                       gsl_vector *v);
static void        apopSummarizeData(const apop_data *data,
                                     const char *message,
                                     const char *fileName);
static void        apopWriteVectorMatrix(const apop_data *data,
                                         const char *path);

static void appendToColumnName(apop_data *data, 
                               unsigned colIndex, 
                               const char *);
typedef struct {
  ArrayD *doesntHaveNan;
  ArrayD *haveNan;
} ClassifyColumns;

static ClassifyColumns classifyColumns(const gsl_matrix *matrix);

static unsigned countNans(gsl_vector* vector);

static void createImputableTable(apop_data *data);

static void dropDuplicateApnDate(apop_data *data);

static void failIf(int condition, const char * message, ...); 

static void     gslVectorDistributionPrint(const gsl_vector *v);
//static gboolean gslVectorHasNan(const gsl_vector *v);
static void     gslVectorMeanStddev(const gsl_vector *v, 
                                    double *meanP, 
                                    double *stddevP);
static void     gslVectorStandardize(gsl_vector *v);
static void     gslVectorTest();

static gboolean hasNan(const apop_data *data);

static double impute(const apop_data  *data,
                     apop_model       *model,
                     unsigned          rowIndex, 
                     const ArrayD     *keptColIndices);
static void imputeAllNCoded(apop_data *data);
static void imputeOne(apop_data    *data,
                      unsigned      colIndex,
                      const ArrayD *keptColumnIndices);

static apop_data*  makeImputationData(const apop_data *data,
                                      unsigned         imputationColumnIndex,
                                      const ArrayD    *keptColumnIndices);
static void makeSettings();

//static ArrayD* nonNanColumnIndices(const apop_data *data);

static void openDb();
static FILE* openResultsFile(GString *resultsDir, const char *name);

#if 0
static void printDistribution(const apop_data *data,
                              unsigned         colIndex,
                              const char      *colName);
#endif

static void printTwice(FILE *file, const char *format, ...);
 
static apop_data* readObservations(); 

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
static void recodeDataVectorLog(apop_data *data);
static void recodeDataWorker(apop_data *data, const char *cName, char c);

static gboolean strSuffixEqual(const char *s, const char *suffix);



#if 0
static unsigned long strToUnsignedLong(const char *str);
#endif

static ArrayS* distinctTextValues(const apop_data *data, const char* cName);

static void unitTests();
static void writeCsv(const apop_data *data, const GString *path);


////////////////////////////////////////////////////////////////////////////////
int main(int argc, char **argv) {
  printf("DEBUG ME main\n");
  const unsigned verbose = 1;
  
  // use otherwise unused functions
  if (0) {
    apopDropRows(NULL, NULL);
    hasNan(NULL);
    printTwice(NULL, NULL);
    setIPrint(NULL);
    strSuffixEqual(NULL, NULL);
  }
  makeSettings();
  apop_opts.verbose = 1;
  apop_opts.stop_on_warning = 'y';
  
  unitTests();

  openDb();

  apop_data *data = readObservations();
  dropDuplicateApnDate(data);
  apopDropMatrixColumn(data, "universal_building_square_feet");
  recodeData(data);

  // write the recoded data to the output directory
  // in file observations-imputable.csv
  GString *path = g_string_new(settings.outputDir->str);
  g_string_append(path, "/thesisobservations-imputable.csv");
  writeCsv(data, path);
  g_string_free(path, TRUE); // TRUE ==> also free segment

  LOG("data after dropping dup (apn,date), building sq ft, and recoding\n");
  LOGF(" vector has %u entries\n", data->vector->size);
  LOGF(" matrix is %u x %u\n", data->matrix->size1, data->matrix->size2);

  // maybe drop text info, to free RAM
  if (verbose > 0) {
    printf("Data after recoding");
    apopDataPrintSummary(data);
    apopDataPrintAnomolies(data);
  }

  // do the imputation
  imputeAllNCoded(data);

  // write the imputed data
  // maybe also split inot training and test
  printf("STUB: write imputed data\n");
  if (0) {
    // FIXME: should be called createImputedTable
    createImputableTable(data);  // old version: TODO: update it
  }

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
Create vector from a row by retaining certain columns
*/
static gsl_vector* apopDataRemoveColumns(const apop_data *data,
                                         unsigned         rowIndex,
                                         const ArrayD    *keptColIndices) {
  const unsigned nColsKept = arrayDSize(keptColIndices);
  gsl_vector *result = gsl_vector_alloc(nColsKept);
  for (unsigned k = 0; k < nColsKept; k++) {
    int colIndex = arrayDIndex(keptColIndices, k);
    if (colIndex == -1) {
      // replace the sale_amount with a standardized sale_amount
      static gsl_vector *standardizedSaleAmount = NULL;
      if (!standardizedSaleAmount) {
        apop_col(data, colIndex, v);
        standardizedSaleAmount = gsl_vector_alloc(v->size);
        gsl_vector_memcpy(standardizedSaleAmount, v);
        gslVectorStandardize(standardizedSaleAmount);
      }
      gsl_vector_set(result, 
                     k, 
                     gsl_vector_get(standardizedSaleAmount, rowIndex));
    } else {
      // just copy the other values
      gsl_vector_set(result, 
                     k,
                     apop_data_get(.data=data, .row=rowIndex, .col=colIndex));
    }
  }
  return result;
} // apopDataRemoveColumns
                                         
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

/**
drop rows named in array

@param droppedRowIndices; array of indices to drop
*/
static void apopDropRows(apop_data    *data, 
                         const ArrayD *droppedRowIndices) {
  assert(data);
  assert(droppedRowIndices);

  const unsigned nObs = data->matrix->size1;
  const unsigned nRowIndices = arrayDSize(droppedRowIndices);
  assert(nRowIndices < nObs - 1);

  // build int* with indicator 1 for rows to drop
  int * toDrop = calloc(nObs, sizeof(int));  // initialized to all zeroes
  assert(toDrop);
  for (unsigned i = 0; i < nRowIndices; i++) {
    toDrop[(int) arrayDIndex(droppedRowIndices, i)] = 1;
  }

  apop_data_rm_rows(data, toDrop, NULL, NULL);
  assert(data);  // should not remove all the rows
 
  free(toDrop);
} // apopDropRows

/**
Print summary of a model
*/
static void     apopModelPrintSummary(const apop_model *model) {
  printf("apop model at %p\n", model);
  printf("title %s\n", model->name);
  printf("vbase %d mbase1 %d mbase2 %d\n",
         model->vbase, model->m1base, model->m2base);
  printf("dsize (parameter set size) %d\n", model->dsize);

  printf("setting %p\n", model->settings);
  printf(" name %s\n", model->settings->name);
  printf(" setting_group %p\n", model->settings->setting_group);
  printf(" copy %p\n", model->settings->copy);
  printf(" free %p\n", model->settings->free);

  printf("parameters %p\n", model->parameters);
  apopDataPrintSummary(model->parameters);
  printf("end of parameters summary");
  
  printf("data %p\n", model->data);
  printf("info %p\n", model->info); // depends on the model
  printf("more %p more_size %lu\n", model->more, model->more_size);
  
  printf("function apop_estimate        %p\n", model->estimate);
  printf("function apop_p               %p\n", model->p);
  printf("function apop_log_likelihood  %p\n", model->log_likelihood);
  printf("function apop_score           %p\n", model->score);
  printf("function apop_predict         %p\n", model->predict);
  printf("function apop_parameter_model %p\n", model->parameter_model);
  printf("function apop_cdf             %p\n", model->cdf);
  printf("function apop_constraint      %p\n", model->constraint);
  printf("function apop_draw            %p\n", model->draw);
  printf("function apop_prep            %p\n", model->prep);
  printf("function apop_print           %p\n", model->print);
  
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
Mutate column name by appending a string
@param data; data set
@param colIndex; index of the matrix column
@param text to be appended
*/
static void appendToColumnName(apop_data *data, 
                               unsigned colIndex, 
                               const char *text) {
  assert(data);
  assert(data->matrix);
  assert(colIndex < data->matrix->size2);
  assert(text);
  
  assert(data->names);
  const char *currentName = data->names->column[colIndex];
  assert(currentName);
  GString *newName = g_string_new(currentName);
  g_string_append(newName, text);
  data->names->column[colIndex] = newName->str;
  g_string_free(newName, 0); // 0 -- don't free segment
} // appendToColumnName

/**
classify columns into those with and without NaN values

@param matrx; 
*/
static ClassifyColumns classifyColumns(const gsl_matrix *matrix) {
  //printf("DEBUG ME: classifyColumns\n");
  assert(matrix);
  const unsigned verbose = 1;

  ArrayD *doesntHaveNan = arrayDNew();
  ArrayD *haveNan = arrayDNew();
  for (unsigned k = 0; k < matrix->size2; k++) {
    unsigned foundNan = 0;
    for (unsigned i = 0; i < matrix->size1; i++) {
      const double value = gsl_matrix_get(matrix, i, k);
      if (isnan(value)) {
        foundNan = 1;
        vp("found NaN in column %u\n", k);
        break;
      }
    }
    arrayDAppend(foundNan ? haveNan : doesntHaveNan, k);
  }
  
  ClassifyColumns result = {.doesntHaveNan = doesntHaveNan,
                            .haveNan = haveNan};
  return result;
} // classifyColumns

/**
Count number of Nans
*/
static unsigned countNans(gsl_vector *vector) {
  assert(vector);
  unsigned count = 0;
  for (unsigned i = 0; i < vector->size; i++) {
    if (isnan(gsl_vector_get(vector, i)))
      count++;
  }
  return count;
} // countNans


/**
Read observations table from db.sqlite3, create file observations-imputable.csv
*/
static void createImputableTable(apop_data *data) {
  printf("DEBUG ME createImputableTable\n");
  //static unsigned verbose = 1;
  assert(data);

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
} // createImputableTable

/**
drop data rows containing duplicate (apn,sale date) pairs

@param data; the dataset; it is mutated
*/
static void dropDuplicateApnDate(apop_data *data) {
  //printf("DEBUG ME: dropDuplicateApnDate\n");
  assert(data);
  const unsigned verbose = 1;

  // 1. Create set of row indices for duplicate (apn,sale date) pairs
  HashSI *first = hashSINew(); // first row index with (apn,sale date) pair
  SetI   *toDeleteSet = setINew(); // indices that are dups
  const apop_name *names = data->names;
  // index of apn is in text portion
  const int apnColIndex = apop_name_find(names, "deeds_apn_unformatted", 't');
  assert(apnColIndex >= 0);
  // index of sale date is in columns (matrix)
  const int dateColIndex = apop_name_find(names, "sale_date", 'c');
  assert(dateColIndex >= 0);
  const unsigned nObs = data->matrix->size1;
  for (unsigned i = 0; i < nObs; i++) {
    GString *pair = g_string_new(data->text[i][apnColIndex]);
    g_string_append(pair, "|");
    g_string_append_printf(pair, "%d", (int) apop_data_get(.data=data,
                                                           .row= i,
                                                           .col=dateColIndex));
    if (verbose > 1)
      printf("pair=%s\n", pair->str);
    HashSILookup lookup = hashSILookup(first, pair->str);
    if (lookup.found) {
      // delete both first and current observation
      setIAdd(toDeleteSet, lookup.value);  // potentially reinsert many times
      setIAdd(toDeleteSet, i);
    }
    else
      hashSIInsert(first, pair->str, i);
    g_string_free(pair, 1); // 1-->free segment
  }
  hashSIUnref(first);

  // 2. delete the duplicate rows
  // must convert toDeleteSet to arrayD first
  ArrayD *toDeleteArray = arrayDNew();
  SetIIter iter;
  gint     element;
  setIIterInit(toDeleteSet, &iter);
  while (setIIterNext(&iter, &element)) {
    if (verbose > 1)
      printf("element=%d\n", element);
    arrayDAppend(toDeleteArray, element);
  }
  setIUnref(toDeleteSet);

  LOGF("dropping %d rows that contains duplicate (apn,sale date) pairs\n",
       arrayDSize(toDeleteArray));
  apopDropRows(data, toDeleteArray);
  LOGF("resulting data->matrix is %lu x %lu\n",
       data->matrix->size1, data->matrix->size2);
  arrayDUnref(toDeleteArray);
} // dropDuplicateApnDate

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
    const HashSILookup lookup = hashSILookup(seen, code);
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

#if 1
/** 
print the distribution of values in a vector
*/
static void gslVectorDistributionPrint(const gsl_vector *v) {
  assert(v);

  // determine distribution
  const size_t nElements = v->size;
  HashDD *countOfValue = hashDDNew();
  double nNans = 0;
  for (size_t i = 0; i < nElements; i++) {
    const double key = gsl_vector_get(v, i);
    if (isnan(key)) {
      nNans++;
    } else {
      const HashDDLookup lookup = hashDDLookup(countOfValue, key);
      if (lookup.found)
        hashDDInsert(countOfValue, key, lookup.value + 1.0);
      else
        hashDDInsert(countOfValue, key, 1.0);
    }
  }

  // print distribution
  printf("distribution of values in gsl_vector %p\n", v);
  printf(" there are %lu elements\n", nElements);
  printf(" value NaN occurs %g times\n", nNans);
  HashDDIter iter;
  hashDDIterInit(countOfValue, &iter);
  double key;
  double value;
  while (hashDDIterNext(&iter, &key, &value)) {
    printf(" value %g occurs %g times\n", key, value);
  }
  hashDDUnref(countOfValue);


} // gslVectorDistributionPrint
#endif

#if 0
/**
Determine if vector has a NaN element
*/
static gboolean gslVectorHasNan(const gsl_vector *v) {
  assert(v);
  const int size = v->size;
  for (int i = 0; i < size; i++) {
    const double value = gsl_vector_get(v, i);
    if (isnan(value))
      return 1;
  }
  return 0;
} // glsVectorHasNaN
#endif

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
} //gslVectorStandardize

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
Estimate one missing value
*/
static double impute(const apop_data  *data,
                     apop_model       *model,
                     unsigned          rowIndex,
                     const ArrayD     *keptColumnIndices) {
  //printf("DEBUG ME: impute\n");
  const unsigned verbose = 0;
  assert(data);
  assert(keptColumnIndices);

  // create vector that holds just the independent vars from the log regress
  gsl_vector *vectorShort = apopDataRemoveColumns(data,
                                                  rowIndex,
                                                  keptColumnIndices);
  // put a 1 in the first position
  gsl_vector *vector = gsl_vector_alloc(vectorShort->size + 1);
  for (unsigned i = 0; i < vector->size; i++) {
    gsl_vector_set(vector, 
                   i,
                   (i == 0) ? 1 : gsl_vector_get(vectorShort, i - 1));
  }
  gsl_vector_free(vectorShort);

  if (verbose > 0) {
    printf("features used in imputation of obs index %u\n", rowIndex);
    gsl_vector_fprintf(stdout, vectorShort, "%g");
  }
    
  gsl_matrix *matrix = gsl_matrix_alloc(1, 1 + arrayDSize(keptColumnIndices));
  gsl_matrix_set_row(matrix, 0, vector);
  
  apop_data *features = apop_data_alloc(); // everything null
  features->matrix = matrix;

  // predict 
  apop_data *prediction = apop_predict(features, model);
  if (verbose > 0) {
    printf("prediction\n");
    apopDataPrintSummary(prediction);
  }

  // predicted->vector[0] is a most likely value
  // for now, assume the prediction is in the first element of the vector
  const double predictedValue =  apop_data_get(.data=prediction,
                                               .row=0,
                                               .col=-1);

  // free temp storage
  apop_data_free(prediction);

  return predictedValue;
} // impute

/**
Do the imputation for each nCoded column
*/
static void imputeAllNCoded(apop_data *data) {
  printf("DEBUG ME imputeAllCoded\n");
  assert(data);
  const unsigned verbose = 1;
  const apop_name *names = data->names;
  assert(names);
  
  const unsigned nCols = data->matrix->size2;
  assert(nCols == names->colct);

  // determine indices of columns with and without Nan values
  ClassifyColumns classified = classifyColumns(data->matrix);
  ArrayD *doesntHaveNan = classified.doesntHaveNan;
  ArrayD *haveNan = classified.haveNan;
  if (verbose > 0) {
    printf("column indices without a NaN in column: ");
    arrayDPrint(doesntHaveNan);
    printf("column indices with a NaN in column: ");
    arrayDPrint(haveNan);
  }

  for (unsigned haveIndex = 0; haveIndex < arrayDSize(haveNan); haveIndex++) {
    const double hasNan = arrayDIndex(haveNan, haveIndex);
    imputeOne(data, (unsigned) hasNan, doesntHaveNan);
  }
  
  #if 0
  for (unsigned k = 0; k < nCols; k++) {
    const char * colName = names->column[k];
    if (strSuffixEqual(colName, "_ncoded")) {
      Apop_col(data, k, vector);
      if (gslVectorHasNan(vector)) {
        printf("about to impute %u %s\n", k, colName);
        imputeOne(data, imputationData, k, colName, keptColumnIndices);
      }
    }
  }
  #endif
  free(haveNan);
  free(doesntHaveNan);
} // imputeAllNCoded

/**
Impute one ncoded column

Replace the ncoded column in data
*/
static void imputeOne(apop_data       *data,
                      unsigned         colIndex,
                      const ArrayD    *keptColumnIndices) {
  printf("DEBUG ME imputeOne\n");
  // MAYBE: test apop_ml_impute(apop_data *d, apop_model *mvn)
  // but it uses mvn model, not a logistic regression model
  //  This function fills in the missing data so that it is ready to use.

  // MAYBE: review apop_missing_data.c
  const unsigned verbose = 0;
  const unsigned debugging = 0;
  assert(data);

  // keep only all-known columns and all-known rows
  // set dependent variable column (colIndex) as first data column
  // set vector to NULL
  apop_data *imputationData = makeImputationData(data, 
                                                 colIndex, 
                                                 keptColumnIndices);

  LOGF("imputing col %u using imputation data that is %lu x %lu\n",
       colIndex,
       imputationData->matrix->size1, imputationData->matrix->size2);

  // estimate column 1 using lotistic regression
  apop_model *estimatedModel = apop_estimate(imputationData, apop_logit);
  if (verbose > 0) {
    printf("estimated summary\n");
    apopModelPrintSummary(estimatedModel);
  }
  int status = apop_data_get(estimatedModel->info, .rowname="status");
  if (status) {
    LOGF("apop_estimate return non zero status of %d\n", status);
    // for error message "I got a NaN value in evaluating objective function"
    // - that error comes from gsl_multimin_fdminimizer_iterate
    // - I don't know why it is generated or whether the model is now usable
    // for now, keep going
    //exit(1);
  }
  apop_data_free(imputationData);

  // determine best estimates for all values, including missing values
  const unsigned nObs = data->matrix->size1;
  unsigned nCompared = 0;
  unsigned nCorrect = 0;
  unsigned nReplaced = 0;
  for (unsigned i = 0; i < nObs; i++) {
    const double originalValue = apop_data_get(.data=data,
                                               .row=i,
                                               .col=colIndex);
    // estimate every value, not just the unknown values
    const double estimate = impute(data, estimatedModel, i, keptColumnIndices);
    assert(estimate == (int) estimate); // estimate must be an integer
    
    if (isnan(originalValue)) {
      // value is not known; update data with estimate
      apop_data_set(.data=data, .row=i, .col=colIndex, estimate);
      if (debugging)
        assert(estimate == apop_data_get(.data=data, .row=i, .col=colIndex));
      nReplaced++;
    } else {
      // value is already known; keep track of accuracy
      nCompared++;
      if (originalValue == estimate)
        nCorrect++;
    }
  }
  printf("nCompared %u nCorrect %u\n", nCompared, nCorrect);
  LOGF("replaced %u NaNs with imputed values\n", nReplaced);
  // the estimatedModel is somehow corruped; one the the paramter->more objects
  // has an invalid address
  if (debugging) {
    apopModelPrintSummary(estimatedModel);
  }
  // statement below had segfault in earlier version of this function
  apop_model_free(estimatedModel);
  return;

  // OLD BELOW ME
  #if 0
  const unsigned nObs = data->matrix->size1;
  const unsigned nDataCols = data->matrix->size2;

  assert(colIndex < nDataCols);
  
  if (debugging)
    printDistribution(data, colIndex, colName);
  
  // put the data column to be imputed as the vector in imputationData
  apop_data *modelData = apop_data_copy(imputationData);
  // NOTE: creating the vector with Apop_col(data, colIndex, vector) would
  // create a view and a view cannot participate in Apophenia's row drop
  // operation. Hence, create the vector from scratch.
  gsl_vector *vector = gsl_vector_alloc(nObs);
  for (unsigned i = 0; i < nObs; i++) {
    gsl_vector_set(vector, 
                   i,
                   apop_data_get(.data=data, .row=i, .col=colIndex));
  }
  modelData->vector = vector;

  // eliminate all imputation data rows with a NaN in the vector
  apopDataDropRowsIfNanTarget(modelData);
  if (verbose > 1) {
    printf("modelData\n");
    apopDataPrintSummary(modelData);
  }
  LOGF("modelData for column %u %s is %lu by %lu\n", 
       colIndex, colName,
       modelData->matrix->size1, modelData->matrix->size2);

  // estimate the logistic regression model
  // ref: 
  // http://apophenia.info/group__models.html
  apop_model *estimatedModel = apop_estimate(modelData, apop_logit);
  if (verbose > 0) {
    printf("estimated summary\n");
    apopModelPrintSummary(estimatedModel);
  }
  apop_data_free(modelData);

  // determine best estimates for all values, including missing values
  unsigned nCompared = 0;
  unsigned nCorrect = 0;
  unsigned nReplaced = 0;
  for (unsigned i = 0; i < nObs; i++) {
    const double originalValue = apop_data_get(.data=data,
                                               .row=i,
                                               .col=colIndex);
    // estimate every value, not just the unknown values
    const double estimate = impute(data, estimatedModel, i, keptColumnIndices);
    assert(estimate == (int) estimate); // estimate must be an integer
    
    if (isnan(originalValue)) {
      // value is not known; update data with estimate
      apop_data_set(.data=data, .row=i, .col=colIndex, estimate);
      if (debugging)
        assert(estimate == apop_data_get(.data=data, .row=i, .col=colIndex));
      nReplaced++;
    } else {
      // value is already known; keep track of accuracy
      nCompared++;
      if (originalValue == estimate)
        nCorrect++;
    }
  }
  printf("%s nCompared %u nCorrect %u\n", colName, nCompared, nCorrect);
  LOGF("replaced %u NaNs with imputed values\n", nReplaced);
  // the estimatedModel is somehow corruped; one the the paramter->more objects
  // has an invalid address
  if (debugging) {
    apopModelPrintSummary(estimatedModel);
  }
  // for now, don't free the estimated model
  //apop_model_free(estimatedModel);
  #endif
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

static HashISLookup hashISLookup(const HashIS *h, gint key) {
  assert(h);
  HashISLookup result = {.found = 0, .value = NULL};
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


static void hashISUnitTest() {
  HashIS *h = hashISNew();
  const char* one = "one";
  hashISInsert(h, 1, one);
  hashISInsert(h, 27, "twenty seven");
  
  HashISLookup result = hashISLookup(h, 1);
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
@return hashSILookup structure
If the value is found, then     {.found = 1, .value = the gint value}
If the value is not found, then {.found = 0, value = -1}
*/
static HashSILookup hashSILookup(const HashSI *h, const char *key) {
  assert(h != NULL);
  HashSILookup result = {.found = 0, .value = -1};
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
static void hashSIUnitTest() {
  const unsigned verbose = 0;
  HashSI *h = hashSINew();
  HashSILookup result;

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
Build the imputation data matrix;

Version 1: (incorrectly layed out)
- vector contains the values to be imputed
- matrix contains all the columns that have no NaNs in them

Version 2 is the form documented for apop_logit
Version 2: (results in NaN from GSL code during optimization)
- vector is null
- matrix column 1 enumerates the factors
- other columns contain the covariates
- drop any row with a NaN in the imputation value

Version 3: (does not work)
- vector is the imputation column
- column 1 has ones
- rows with a NaN in the imputation column are eliminated

Drop all rows that have a null value
@returns a new apop_data
*/
static apop_data* makeImputationData(const apop_data *data,
                                     unsigned         imputationColIndex,
                                     const ArrayD    *nonNanColIndices) {
  printf("DEBUG ME: makeImputationData\n");
  assert(data);
  assert(data->names);
  const unsigned verbose = 0;
  //const unsigned debugging = 1;

  int nDataObs = data->matrix->size1;
  int nDataCols = data->matrix->size2;

  // generate an extra column for the imputation column
  int nResultCols = arrayDSize(nonNanColIndices) + 1;

  // determine number of rows in result apop_data
  // equal to number of non-Nan entries in the data[imputationColIndex,*]
  unsigned nResultRows = 0;
  for (unsigned i = 0; i < nDataObs; i++) {
    if (!isnan(apop_data_get(.data=data, .row=i, .col=imputationColIndex)))
      nResultRows++;
  }
  assert(nResultRows < nDataObs); // must be at least one NaN
  vp("imputation matrix will be %u x %d\n", nResultRows, nResultCols);

  // allocate just the matrix
  apop_data *result = apop_data_alloc(nResultRows, nResultCols);

  // copy each row where the value to be imputated is known
  unsigned rowIndex = 0;
  for (unsigned i = 0; i < nDataObs; i++) {
    // drop rows that hava a NaN in the imputation column
    const double imputationValue = apop_data_get(.data=data,
                                                 .row=i,
                                                 .col=imputationColIndex);
    if (isnan(imputationValue))
      continue;
    // first column is the value from the imputation column
    apop_data_set(.data=result, .row=rowIndex, .col=0, imputationValue); 
    // other columns in the matrix are the the designated from the matrix
    unsigned colIndex = 1;  // first column to set has index 1
    const unsigned nColsToCopy = arrayDSize(nonNanColIndices);
    for (unsigned kIndex = 0; kIndex < nColsToCopy; kIndex++) {
      unsigned k = (unsigned) arrayDIndex(nonNanColIndices, kIndex);
      assert(k < nDataCols);
      const double value = apop_data_get(.data=data, .row=i, .col=k);
      apop_data_set(.data=result, .row=rowIndex, .col=colIndex, value);
      colIndex++;
    }
    rowIndex++;
    assert(colIndex == nResultCols);
  }
  assert(rowIndex == nResultRows);
  assert(!apopDataHasNan(result));
  if (verbose > 0) {
    printf("Summary of result from makeImputationData\n");
    apopDataPrintSummary(result);
    printf("Summary of input data from makeImputationData\n");
    apopDataPrintSummary(data);
  }

  return result;
} // makeImputationData

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

  // version number
  settings.version = 2;

  // write options
  LOG("options\n");
  LOGF(" test=%u\n", options.test);
  LOGF(" bigJump=%u\n", options.bigJump);
  LOGF(" createImputable=%u\n", options.createImputable);

  // write settings
  LOG("settings\n");
  LOGF(" resultsDir=%s\n", settings.resultsDir->str);
  LOGF(" outputDir =%s\n", settings.outputDir->str);
  LOGF(" version   =%u\n", settings.version);

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

#if 0
/**
print the distribution of a variable that takes on double values
*/
static void printDistribution(const apop_data *data,
                              unsigned         colIndex,
                              const char      *colName) {
  assert(data);
  assert(colName);
  
  assert(data->matrix);
  //const unsigned nObs = data->matrix->size1;
  const unsigned nCols = data->matrix->size2;

  // determine number of times each value is seen
  // BUG: a NaN value can be inserted but will never be found
  assert(colIndex < nCols);
  printf("distribution of column %u %s\n", colIndex, colName);
  Apop_matrix_col(data->matrix, colIndex, column);
  gslVectorDistributionPrint(column);
  // delete the rest
  #if 0
  HashDD* countOfValue = hashDDNew();
  double nNans = 0;
  for (unsigned i = 0; i < nObs; i++) {
    const double key = apop_data_get(.data=data, .row=i, .col=colIndex);
    if (isnan(key)) {
      nNans++;
    } else {
      const HashDDLookup lookup = hashDDLookup(countOfValue, key);
      if (lookup.found) 
        hashDDInsert(countOfValue, key, lookup.value + 1.0);
      else
        hashDDInsert(countOfValue, key, 1.0);
    }
  }

  // print number of times each value was seen
  printf("distribution of values in column %u %s\n", colIndex, colName);
  printf(" there are %u rows\n", nObs);
  printf(" value NaN occurs %g times\n", nNans);
  HashDDIter iter;
  hashDDIterInit(countOfValue, &iter);
  double key;
  double value;
  while (hashDDIterNext(&iter, &key, &value)) {
    printf(" value %g occurs %g times\n", key, value);
  }
  hashDDUnref(countOfValue);
  #endif
} // printDistribution
#endif

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
Return selected rows from the observations tables.

Keep rows satisfying:
- land value > 0
- improvement value > 0
- built after 1542 (date of first settlers in California)
- rooms > 0
- stories > 0
- latitude and longitude known
- average commute > 0
- fraction owner occupied > 0
- household median income > 0
- distinct (apn,sale date) pair

*/
static apop_data* readObservations() {
  //printf("DEBUG ME: readObservations\n");
  const unsigned verbose = 1;
  
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
  LOGF("select statement = %s\n", selectStatementReject->str);
  apop_data *data =
    apop_query_to_mixed_data(typelist,
                             "%s",
                             selectStatementReject->str);
  g_string_free(selectStatementReject, TRUE); // TRUE ==> free segment
  LOGF("read %u observations\n", data->matrix->size1);
  
  return data;
} // readObservations


#if 0
/**
Drop any row where the vector element is NaN
*/
static void     apopDataDropRowsIfNanTarget(apop_data *data) {
  assert(data);
  assert(data->vector);

  const unsigned nObs = data->vector->size;

  ArrayD *toDrop = arrayDNew();
  for (unsigned i = 0; i < nObs; i++) {
    if (isnan(apop_data_get(.data=data, .row=i, .col=-1)))
      arrayDAppend(toDrop, i);
  }

  assert(arrayDSize(toDrop) < nObs);

  apopDropRows(data, toDrop);
  arrayDUnref(toDrop);
} // apopDataDropRowsIfNanTarget
#endif

/**
Determine if the vector or matrix has a NaN value

@param data; must have a matrix, may have a vector
*/
static gboolean apopDataHasNan(const apop_data *data) {
  assert(data);
  assert(data->matrix);

  const size_t nRows = data->matrix->size1;
  const size_t nCols = data->matrix->size2;
  assert(data->vector == NULL || nRows == data->vector->size);

  for (size_t rowIndex = 0; rowIndex < nRows; ++rowIndex) {
    unsigned startColIndex = data->vector ? -1 : 0;
    for (size_t colIndex = startColIndex; colIndex < nCols; ++colIndex) {
      if (isnan(apop_data_get(.data=data, .row=rowIndex, .col=colIndex)))
        return TRUE;
    }
  }
  return FALSE;
} // apopDataHasNan

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

  printf("Anomolies: vector and matrix columns with at least one NaN value\n");

  // examine vector
  Apop_col(data, -1, vector);
  unsigned count = countNans(vector);
  if (count > 0)
    printf("vector has %u NaNs\n", count);

  // examine each matrix column
  for (unsigned k = 0; k < nCols; k++) {
    Apop_col(data, k, vector);
    unsigned count = countNans(vector);
    if (count > 0)
      printf("column %u %s has %u NaNs\n",
             k, data->names->column[k], count);
  }
  
  printf("\nAnomolies: zero length strings in text\n");
  unsigned found = 0;
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
  recodeDataVectorLog(data);  // recodes "sale_amount"

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

  #if 0
  // set the title to reflect the recoding
  const apop_name *names = data->names;
  assert(names);
  strcpy(names->title, "recoded");  // this generates a compile error
  #endif 
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

The epoch is 1970-01-01. Also change name of column
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

  // change column name
  appendToColumnName(data, col, "_days_std");
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

  apopAppendColumn(data, fractions, "improvement_fraction");
  
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
  printf("DEBUG ME: recodeDataNCode\n");
  const unsigned verbose = 1;
  const unsigned experiment = 0; // test apop_data_to_factors
  assert(data);
  assert(cName);

  const unsigned nObs = data->matrix->size1;
  const unsigned col = apopColumnNameText(data, cName);

  if (experiment == 1) {
    // determine what apop_data_to_factors returns
    // I want to return the same
    // It turns out the apop_data_to_factors sets a numeric code for blank
    // values. I want to convert blank values to NaN, not to encode them
    // as some value.

    // Conclusion: I can't use apop_data_to_factors
    apop_data_to_factors(data, 't', col, -1); // set vector
    printf("Distribution of %s values in apop_data_to_factors vector\n", cName);
    gslVectorDistributionPrint(data->vector);
  }

  HashSI *codeOccurrence = hashSINew();
  gsl_vector *v = gsl_vector_alloc(nObs);

  // convert the N distinct text values to codes in {0, 1, ..., N-1}
  // don't convert blanks, as these are NAs; but count the blanks
  unsigned nDistinctCodes = 0;
  for (unsigned i = 0; i < nObs; i++) {
    const char *code = data->text[i][col];
    vp2("code=%s\n", code);
    if (strcmp(code, "") == 0) {
      gsl_vector_set(v, i, NAN);
    }
    else {
      HashSILookup result = hashSILookup(codeOccurrence, code);
      if (result.found) {
        gsl_vector_set(v, i, result.value);
      }
      else {
        hashSIInsert(codeOccurrence, code, nDistinctCodes);
        gsl_vector_set(v, i, nDistinctCodes);
        nDistinctCodes++;
      }
    }
    vp2("v[%u]=%g\n", i, gsl_vector_get(v, i));
  }
  vp1("%s has %u distinct text values\n", cName, nDistinctCodes);

  if (experiment == 1) {
    printf("distribution from own code for %s\n", cName);
    gslVectorDistributionPrint(v);
  }

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
  newName = g_string_append(newName, "_ncoded");
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

Append "_log_std" to column name

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

  appendToColumnName(data, colIndex, "_log_std");
} // recodeDataSize           

/**
Create new column that indicates if the pool is really a spa.

A parcel can have both a pool and spa. A spa is indicated by "S00" in 
the pool code (the pool type).

Don't create the feature if it would be always zero or always one.

@param data the dataset; mutated
*/
static void recodeDataSpa(apop_data *data) {
  //printf("DEBUG ME: recodedDataSpa\n");
  const unsigned verbose = 1;
  // BUG: the isSpa and hasPool columns are identifical
  const unsigned debugging = 1;
  assert(data);
  const unsigned poolCodeCol = apopColumnName(data, "pool_code", 't');

  const unsigned nObs = data->matrix->size1;
  gsl_vector *v = gsl_vector_alloc(nObs);
  unsigned foundOne = 0;
  unsigned foundZero = 0;
  for (unsigned i = 0; i < nObs; i++) {
    const char *code = data->text[i][poolCodeCol];
    const unsigned codeIsSpa = (strcmp(code, "S00") == 0);
    if (codeIsSpa) {
      gsl_vector_set(v, i, 1.0);
      foundOne = 1;
    } else {
      gsl_vector_set(v, i, 0.0);
      foundZero = 1;
    }
  }

  if (debugging) {
    // are all the pools also spas?
    unsigned allEqual = 1;
    const unsigned poolFlagCol = apopColumnName(data, "pool_flag_is_Y", 'c'); 
    for (unsigned i = 0; i < nObs && allEqual; i++) {
      if (apop_data_get(.data=data, .row=i, .col=poolFlagCol) != 
          gsl_vector_get(v, i))
        allEqual = 0;
    }
    if (allEqual)
      vp("all are equal\n");
    else
      vp("some are different\n");
  }

  if (foundOne && foundZero) {
    LOG("adding spa column\n");
    apopAppendColumn(data, v, "has_spa");
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

Append "_std" to column name
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

  appendToColumnName(data, colIndex, "_std");
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
Recode the vector values by replacing each with log(x)

Also change name of the column.

@param data the data set; mutated
@param cName the column name
*/
static void recodeDataVectorLog(apop_data *data) {
  assert(data);
  
  const unsigned colIndex = -1;
  const unsigned nObs = data->matrix->size1;

  // change the values in the vector
  for (unsigned i = 0; i < nObs; i++) {
    const double current = apop_data_get(.data=data, .row=i, .col=colIndex);
    assert(current > 0);
    const double new = log(current);
    apop_data_set(.data=data, .row=i, .col=colIndex, .val=new);
  }

  // change the vector column name
  const char *currentName = data->names->vector;
  GString *newName = g_string_new(currentName);
  g_string_append(newName, "_log");
  free((char *) currentName);
  data->names->vector = newName->str;
  g_string_free(newName, 0); // 0 --> don't free segment
  
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

    // set column name to cName .. "_is_" .. currentCode
    GString *newName = g_string_new(cName);
    newName = g_string_append(newName, "_is_");
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


static void setIUnitTest() {
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
  arraySUnitTest();
  arrayDUnitTest();
  gslVectorTest();
  hashDDUnitTest();
  hashISUnitTest();
  hashSIUnitTest();
  setIUnitTest();
}

/**
write a dataset to a csv file

@param data; the data set, only vector and data portions are written
@param filePath; path to the file, overwritten if already exists
*/
static void writeCsv(const apop_data *data, const GString *filePath) {
  printf("DEBUG ME: writeCsv\n");
  const unsigned verbose = 1;
  assert(data);
  assert(filePath);

  FILE *file = fopen(filePath->str, "w");
  assert(file);

  // 1. Write the header: vector name followed by matrix column names
  apop_name *names= data->names;
  assert(names);
  const char *p = names->vector;
  assert(p);
  fprintf(file, "%s", p);
  vp("vector name %s\n", p);
  const int nCols = data->matrix->size2;
  for (unsigned col = 0; col < nCols; col++) {
    const char *p = names->column[col];
    assert(p);
    fprintf(file, ",%s", p);
    vp("column %u name %s\n", col, p);
  }
  fprintf(file, "\n");
  
  // 2. Write each data record: vector followed by matrix columns
  const int nRows = data->matrix->size1;
  for (int row = 0; row < nRows; row++) {
    for (int col = -1; col < nCols; col++) {
      if (col >= 0)
        fprintf(file, ",");
      fprintf(file, "%g", apop_data_get(.data=data, .row=row, .col=col));
    }
    fprintf(file, "\n");
  }

  // clean up
  fclose(file);
} // writeCsv
