package com.roylowrance.thesis;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;

import com.roylowrance.thesis.ObsVisit.Visitor;

import com.roylowrance.util.CommandLine;
import com.roylowrance.util.Date;
import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;
import com.roylowrance.util.Represents;
import com.roylowrance.util.Tensor;

// create either Obs1A/features or Obs2R/features, depending on the command line parameter

// TODO: fix this list
// create these serialization files in Obs1A/idxs/*.ser
// The content of the file is always an Idx1Double, except for apns, which is an Idx1Long
//file name                            content
//ACRES-log-std                        standardized log(acres)
//apns                                 apn
//BEDROOMS-std                         standardized number of bedrooms
//census-avg-commute-std               standardized average commute time in the census tract
//census-income-std                    standardized average income in the census tract
//census-ownership-std                 standardized fraction of occupant ownership in the census tract
//date                                 date of transaction YYYYMMDD
//days                                 days past epoch for transaction (used to identify the transaction date)
//day-std                              standardized days past epoch (used as a feature)
//IMPROVEMENT-VALUE-CALCULATED-log-std standardized log(improvement value)
//LAND-VALUE-CALCULATED-log-std        standardized log(improvement value)
//latitude-std                         standardized latitude
//LIVING-SQUARE-FEET-log-std           standardize log(living area)
//longitude-std                        standardized longitude
//PARKING-SPACES-std                   standardized number of parking spaces
//POOL-FLAG-is-0                       indicator (0/1), 1 if there is not a pool
//POOL-FLAG-is-1                       indicator (0/1), 1 if there is a pool
//random                               random number in (0,1)
//SALE-AMOUNT                          sale amount, the price
//SALE-AMOUNT-log                      log(sale amount)
//TOTAL-BATHS-CALCULATED-std           standardized number of bathrooms
//YEAR-BUILT-std                       standardized year built
//zipcodes9                            9-digit zip code

// create these serialization files in Obs2R/idxs/
//  file name                            content
//  ACRES-log-std                        standardized log(acres)
//  apns                                 apn
//  BEDROOMS-std                         standardized number of bedrooms
//  census-avg-commute-std               standardized average commute time in the census tract
//  census-income-std                    standardized average income in the census tract
//  census-ownership-std                 standardized fraction of occupant ownership in the census tract
//  date                                 date of transaction YYYYMMDD
//  days                                 days past epoch for transaction (used to identify the transaction date)
//  day-std                              standardized days past epoch (used as a feature)
//  IMPROVEMENT-VALUE-CALCULATED-log-std standardized log(improvement value)
//  LAND-VALUE-CALCULATED-log-std        standardized log(improvement value)
//  latitude-std                         standardized latitude
//  LIVING-SQUARE-FEET-log-std           standardize log(living area)
//  longitude-std                        standardized longitude
//  PARKING-SPACES-std                   standardized number of parking spaces
//  POOL-FLAG-is-0                       indicator (0/1), 1 if there is not a pool
//  POOL-FLAG-is-1                       indicator (0/1), 1 if there is a pool
//  random                               random number in (0,1)
//  SALE-AMOUNT                          sale amount, the price
//  SALE-AMOUNT-log                      log(sale amount)
//  TOTAL-BATHS-CALCULATED-std           standardized number of bathrooms
//  YEAR-BUILT-std                       standardized year built
//  zipcodes9                            9-digit zip code
//
// Also produces file SALE-AMOUNT-mean-stddev.csv containing the mean and standard deviation of SALE AMOUNT ?
public class CreateFeatures {

    /**
     * Create feature files (each holding a 1D Tensor) from observations files.
     * 
     * Read files PROJECT/data/generated-v4/obsOBS/obsOBS.*.
     * 
     * Write files PROJECT/data/generated-v4/obsOBS/features/*.ser (OLD VERSION)
     * Write files PROJECT/data/generate-v4/obsOBS/features/*.csv (pipe separated values)
     * 
     * @param args
     *            command line; specifies OBS as 1A or 2R
     */
    public static void main(String[] args) throws FileNotFoundException, IOException, ClassNotFoundException {
        Log log = new Log("CreateFeatures.main", true);
        final boolean debugging = false;
        // extract --obs=[1A|2R] from the command line
        System.out.print("command line =");
        for (int i = 0; i < args.length; i++)
            System.out.print(args[i] + " ");
        System.out.println("");
        CommandLine cl = new CommandLine(args);
        String obs = cl.getOptionValue("--obs");
        if (!(obs.equals("1A") || obs.equals("2R")))
            throw new IllegalArgumentException("--obs=[1A|2R] but obs=" + obs);

        String inDir = Dir.project() + "data/generated-v4/obs" + obs + "/";
        String outDir = inDir + "features/";
        String obsFileBasePath = inDir + "obs" + obs; // .suffix is provided by methods that read the data

        // read all columns that we are interested in
        final int throttle = 0; // zero means to read all the observations
        HashMap<String, ArrayList<String>> all = readColumns(obsFileBasePath, makeAllColumnNames(obs), throttle);

        // write the id fields and the days and days-std fields
        Tensor apn = convertStringsHoldingLongsToTensor(all.get("APN ID"));
        if (debugging) {
            log.format("first apn: %17.15f%n", apn.get(0));
            log.println("first apn:" + apn.get(0));
        }
        serialize(apn, outDir, "apns");
        if (debugging)
            return;

        // date is saved as
        // - plain date, as an integer
        // - number of days past the epoch, as a long
        // - standardized(number of days past the epoch), as a double
        Tensor date = convertStringsHoldingsIntToTensor(all.get("DATE ID")); // example: 20041215
        serialize(date, outDir, "date");

        Tensor day = convertStringsHoldingDateToTensorHoldingDays(all.get("DATE ID")); // example: 74516
        serialize(day, outDir, "day");

        Tensor dayStd = standardize(day);
        serialize(dayStd, outDir, "day-std");

        // every transaction has a random number that can be used for random
        // selection
        serialize(convertStringsHoldingFloatsToTensor(all.get("random")), outDir, "random");

        serialize(convertStringsHoldingsIntToTensor(all.get("PROPERTY ZIPCODE")), outDir, "zipcode9");

        // write the sale amount in raw and log form
        Tensor saleAmount = convertStringsHoldingFloatsToTensor(all.get("SALE AMOUNT"));
        Tensor saleAmountLog = Tensor.log(saleAmount);
        serialize(saleAmount, outDir, "SALE-AMOUNT");
        serialize(saleAmountLog, outDir, "SALE-AMOUNT-log");

        // write the numeric features fields
        // these are all standardized
        for (String name : makeNumericAttributeNames()) {
            String fileNameBase = name.replace(' ', '-'); // replace spaces with
                                                          // hyphens
            Tensor idx = convertStringsHoldingFloatsToTensor(all.get(name));
            String fieldName = fileNameBase + "-std";
            serialize(standardize(idx), outDir, fieldName);
        }

        // write the numeric size feature fields
        // these all transformed to the log domain and then standardized
        // create the field "percent improvement value" (which is standardized
        // but not moved to log domain)
        Tensor improvementValue = new Tensor(0); // initialize or we get a compiler error message
        Tensor landValue = new Tensor(0);
        for (String name : makeSizeAttributeNames()) {
            String fileNameBase = name.replace(' ', '-');
            Tensor idx = convertStringsHoldingFloatsToTensor(all.get(name));
            if (name.equals("IMPROVEMENT VALUE CALCULATED"))
                improvementValue = idx;
            else if (name.equals("LAND VALUE CALCULATED"))
                landValue = idx;
            else if (name.equals("PRIOR SALES AMOUNT")) {
                // debugging: check if all the prior sale amounts are zero
                // findings: the PRIOR SALES AMOUNT is zero because it is
                // missing from every deed
                // in the raw data
                final boolean debugging2 = false;
                if (debugging2) {
                    boolean allZero = true;
                    for (int i = 0; i < idx.getSize(0) && allZero; i++)
                        if (idx.get(i) != 0)
                            allZero = false;
                    if (allZero)
                        throw new RuntimeException("all zero");
                }
                // add 1 because the value is zero if the property has not sold before
                idx.add(1); // mutate the tensor
                log.println("PRIOR SALE AMOUNT PLUS 1 idx=" + idx);
                fileNameBase = "PRIOR-SALES-AMOUNT-PLUS-1";
            }
            Tensor idxLog = Tensor.log(idx);
            String fieldName = fileNameBase + "-log-std";
            serialize(standardize(idxLog), outDir, fieldName);
        }

        {
            // derive and write percent-improvement-value
            Tensor totalValue = Tensor.add(landValue,  improvementValue);
            Tensor percentImprovementValue = Tensor.cdiv(improvementValue, totalValue); 
            String filePath = outDir + "percent-improvement-value" + "-std.ser";
            System.out.println("writing file " + filePath);
            serialize(standardize(percentImprovementValue), outDir, "percent-improvement-value-std");
        }

        // write the categorical fields
        // for these, write one feature for each value of the category
        // Note: one of these feature files is redundant because of the 1-in-K
        // encoding
        for (String name : makeCategoricalAttributeNames(obs)) {

            // create an output file for each value
            if (name.equals("SALES TRANSACTION TYPE CODE")) {
                // create new construction indicator
                ArrayList<String> salesTransactionTypeCode = all.get("SALES TRANSACTION TYPE CODE");
                Tensor newConstructionIndicator = new Tensor(salesTransactionTypeCode.size());
                for (int i = 0; i < salesTransactionTypeCode.size(); i++) {
                    String value = salesTransactionTypeCode.get(i);
                    newConstructionIndicator.set(i, value.equals("3") || value.equals("003") ? 1 : 0);
                }
                String filePath = outDir + "new-construction-indicator.ser";
                serialize(newConstructionIndicator, outDir, "new-construction-indicator");
            }

            else {
                // create output file for each value
                HashSet<String> values = uniqueValues(all.get(name));
                for (String value : values) {
                    String fileNameBase = name.replace(' ', '-') + "-is-" + value;
                    ArrayList<String> indicator = indicate(all.get(name), value);
                    serialize(convertStringsHoldingFloatsToTensor(indicator), outDir, fileNameBase);
                }
            }
        }
        System.out.println("CreateFeatures finished");
    }

    // return array of id names
    // an id a column that is not transformed in any way; it is used as-is
    public static String[] makeIdNames() {
        String[] result = { "APN ID", "DATE ID", "random", "PROPERTY ZIPCODE" };
        return result;
    }

    // return array of numeric attribute names
    // a numeric attribute is standardized before using
    // standardization is done by subtracting the mean and dividing by the
    // standard deviation
    public static String[] makeNumericAttributeNames() {
        String[] result = { "BEDROOMS", "census avg commute", "census ownership", "latitude", "longitude", "TOTAL BATHS CALCULATED",
                "PARKING SPACES", "YEAR BUILT", };
        return result;
    }

    // return array of size attributes
    // a size attribute is transformed by standardizing the log of the value
    public static String[] makeSizeAttributeNames() {
        String[] result = { "ACRES", "census income", "IMPROVEMENT VALUE CALCULATED", "LAND VALUE CALCULATED", "LIVING SQUARE FEET",
                // PRIOR SALES AMOUNT commented out, since always missing in the
                // deeds file
                // "PRIOR SALES AMOUNT", // need to add 1 as may be zero
                "SALE AMOUNT", };
        return result;
    }

    // return array of categorical attributes
    // a categorical attribute is transformed into K values, each coded as an
    // indicator (0/1) value
    public static String[] makeCategoricalAttributeNames(String obs) {
        if (obs.equals("1A")) {
            String[] result = { "FOUNDATION CODE", "HEATING CODE", "LOCATION INFLUENCE CODE", "PARKING TYPE CODE", "POOL FLAG",
                    "ROOF TYPE CODE", "TRANSACTION TYPE CODE" // if
                                                              // 003
                                                              // or
                                                              // 3,
                                                              // its
                                                              // new
                                                              // construction
            };
            return result;
        } else if (obs.equals("2R")) {
            String[] result = { "POOL FLAG", "TRANSACTION TYPE CODE" };
            return result;
        } else
            throw new IllegalArgumentException("obs:" + obs);
    }

    // return List of all column names
    public static ArrayList<String> makeAllColumnNames(String obs) {
        ArrayList<String> result = new ArrayList<String>();
        for (String name : makeIdNames())
            result.add(name);
        for (String name : makeNumericAttributeNames())
            result.add(name);
        for (String name : makeSizeAttributeNames())
            result.add(name);
        for (String name : makeCategoricalAttributeNames(obs))
            result.add(name);
        return result;
    }

    // return set of unique values in the list
    public static HashSet<String> uniqueValues(ArrayList<String> values) {
        HashSet<String> result = new HashSet<String>();
        for (String value : values)
            result.add(value);
        return result;
    }

    // return indicator for the specified value
    public static ArrayList<String> indicate(ArrayList<String> values, String specialValue) {
        ArrayList<String> result = new ArrayList<String>();
        for (String value : values) {
            if (value.equals(specialValue))
                result.add("1");
            else
                result.add("0");
        }
        return result;
    }

    // read specified columns into a Map
    public static HashMap<String, ArrayList<String>> readColumns(String obsFileBasePath, List<String> columnNames, int throttle)
            throws FileNotFoundException, IOException {

        class MyVisitor implements Visitor {
            private Extractor extractor;
            private List<String> columnNames;
            private HashMap<String, ArrayList<String>> selectedValues;
            final private boolean showProgress = true;
            private int recordsRead;

            // constructor
            public MyVisitor(List<String> columnNames) {
                this.columnNames = columnNames;
                this.selectedValues = new HashMap<String, ArrayList<String>>();
                for (String columnName : columnNames)
                    this.selectedValues.put(columnName, new ArrayList<String>());
                recordsRead = 0;
            }

            public void start(String header) {
                String separatorRegex = "\\|";
                this.extractor = new Extractor(header, separatorRegex);

            }

            public void visit(String dataRecord) {
                Log log = new Log("CreateFeatures.readColumns.MyVisitor.visit", false);
                final boolean debugging = false;
                recordsRead += 1;
                if (showProgress) {
                    final int reportFrequency = 100000;
                    if (recordsRead % reportFrequency == 0)
                        System.out.println("CreateFeatures.ReadObs: read record number " + recordsRead);
                }
                for (String columnName : this.columnNames) {
                    String columnValue = extractor.extract(dataRecord, columnName);
                    if (debugging) {
                        if (columnName.equals("DATE ID") && columnValue.startsWith("2000"))
                            log.println("found record:" + dataRecord);
                    }
                    ArrayList<String> currentValues = selectedValues.get(columnName);
                    currentValues.add(columnValue); // mutates currentValues
                    selectedValues.put(columnName, currentValues);
                }
            }

            public void end() {
            }

            public HashMap<String, ArrayList<String>> getSelectedValues() {
                return this.selectedValues;
            }
        }
        ObsVisit myObsVisit = new ObsVisit(obsFileBasePath + ".data", obsFileBasePath + ".header");
        MyVisitor myVisitor = new MyVisitor(columnNames);
        myObsVisit.visit(myVisitor, throttle);
        myObsVisit.close();
        return myVisitor.getSelectedValues();
    }

    // convert list of strings to Idx1Long
    public static Tensor convertStringsHoldingLongsToTensor(ArrayList<String> in, Boolean... parameters) {
        boolean logging = false;
        if (parameters.length == 1)
            logging = parameters[0];
        else if (parameters.length > 1)
            throw new IllegalArgumentException("only 0 or 1 parameter accepted");
        Log log = new Log("CreateFeatures.convertStringsToIdx1Long", logging);

        Tensor result = new Tensor(in.size());
        for (int index = 0; index < in.size(); index++) {
            String s = in.get(index);
            if (index < 3)
                log.println("index:" + index + " s:" + s);
            if (!Represents.long_(s))
                throw new ExceptionOLD("String value <" + s + "> does not represent a long");
            result.setLong(index, Long.valueOf(s));
        }
        return result;
    }

    // convert list of Strings hold dates to Idx1Long holding day numbers
    public static Tensor convertStringsHoldingDateToTensorHoldingDays(ArrayList<String> in) {
        Tensor result = new Tensor(in.size());
        for (int index = 0; index < in.size(); index++) {
            final String s = in.get(index);
            if (!Represents.date(s))
                throw new ExceptionOLD("String value <" + s + "> does not represent a date value");
            // setLong throws if the long value would loose precision when
            // truncated to a double
            result.setLong(index, Date.daysPastEpoch(s));
        }
        return result;
    }

    // convert Strings holding Floats to Tensor
    public static Tensor convertStringsHoldingFloatsToTensor(ArrayList<String> in) {
        Tensor result = new Tensor(in.size());
        for (int index = 0; index < in.size(); index++) {
            String s = in.get(index);
            if (!Represents.float_(s))
                throw new ExceptionOLD("String value <" + s + "> does not represent a long");
            result.set(index, Double.valueOf(s));
        }
        return result;
    }

    // convert list of Strings holding int values to Tensor
    public static Tensor convertStringsHoldingsIntToTensor(ArrayList<String> in) {
        Tensor result = new Tensor(in.size());
        for (int index = 0; index < in.size(); index++) {
            String s = in.get(index);
            if (!Represents.int_(s))
                throw new ExceptionOLD("String value <" + s + "> does not represent an int");
            result.set(index, Integer.valueOf(s)); // the value is widened to a
                                                   // double without loss of
                                                   // precision
        }
        return result;
    }

    // serialize a Tensor as a pipe-limited csv file
    public static void serialize(Tensor tensor, String dir, String fieldName) throws FileNotFoundException, IOException {
        final String filePath = dir + fieldName + ".csv";
        System.out.println("writing file " + filePath);
        String[] fieldNames = new String[1];
        fieldNames[0] = fieldName;
        tensor.serialize(filePath,  "csvDelimiterPipe", fieldNames);
    }

    // standardize a Tensor by subtracting mean from each element and dividing by standard deviation
    private static Tensor standardize(Tensor x) {
        final double mean = Tensor.mean(x);
        final double stddev = Tensor.std(x);
        return Tensor.div(Tensor.add(x, - mean), stddev);
    }

}
