package com.roylowrance.thesis;

import java.io.FileNotFoundException;
import java.io.PrintWriter;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import com.roylowrance.util.CsvReader;
import com.roylowrance.util.DataFrame;
import com.roylowrance.util.Date;
import com.roylowrance.util.Tensor;

public class CompareHpiKnn {
    String DATA_DIR = "/home/roy/Dropbox/nyu-thesis-project/data/";
    String LAUFER_DIR = DATA_DIR + "laufer-2012-03-hpi-values/";
    String OBS1_DIR = "/generated-v4/obs1A/";

    String SEPARATOR_REGEX = "\\|";
    
    double lowestTestDay = new Date("20000101").getDaysPastEpoch();
    double highestTestDay = new Date("20091231").getDaysPastEpoch();
    
    /**
     * Compare accuracy of estimates from HPI and KNN methods using as the metric
     * the RMSE in the log domain and comparing actual trades to the estimated trade on
     * the nearest date.
     *   
     * @param args command line args are not used
     */
    public static void main(String[] args) {
        CompareHpiKnn me = new CompareHpiKnn();
        me.mainWorker();
        System.out.println("finished");
    }
    
    private void mainWorker() {
        
        final Tensor actualApns = readFeature("apns");
        final Tensor actualDates = readFeature("dates");
        final Tensor actualPricesLog = readFeature("SALE-AMOUNT-log");
        checkSizes(actualApns, actualDates, actualPricesLog);
        
        CsvReader hpiReader = new CsvReader(LAUFER_DIR + "hpivalues.txt", SEPARATOR_REGEX);
        DataFrame hpiDf = hpiReader.readAll();
        final Tensor hpiApns = hpiDf.getColumnNamed("unformattedapn");
        final Tensor hpiDates = hpiDf.getColumnNamed("date");
        final Tensor hpiPricesLog = Tensor.log(hpiDf.getColumnNamed("housevalue"));
        checkSizes(hpiApns, hpiDates, hpiPricesLog);
        
        CsvReader knnReader = new CsvReader(OBS1_DIR + "analysis/" + "estimates-knn-1A.csv", SEPARATOR_REGEX);
        DataFrame knnDf = knnReader.readAll();
        final Tensor knnApns = knnDf.getColumnNamed("apn");
        final Tensor knnDates = knnDf.getColumnNamed("date");
        final Tensor knnPricesLog = Tensor.log(knnDf.getColumnNamed("estimatedValue"));
        checkSizes(knnApns, knnDates, knnPricesLog);
        
        analyze(actualApns, actualDates, actualPricesLog,
                hpiApns, hpiDates, hpiPricesLog,
                knnApns, knnDates, knnPricesLog);
        
        System.out.println("finished");

    }
    
    ///////////////////////////// private
    
    private class ApnDate {
        public double apn;
        public double date;
        
        // constructor
        public ApnDate(double apn, double date) {
            this.apn = apn;
            this.date = date;
        }
    }
    
    // produce the RMSE values for each set of comparisons
    private void analyze(Tensor actualApns, Tensor actualDates, Tensor actualPricesLog,
                         Tensor hpiApns, Tensor hpiDates, Tensor hpiPricesLog,
                         Tensor knnApns, Tensor knnDates, Tensor knnPricesLog) {
        Map<ApnDate,Double> hpiMap = makeMap(hpiApns, hpiDates, hpiPricesLog);
        Map<ApnDate,Double> knnMap = makeMap(knnApns, knnDates, knnPricesLog);
        
        Set<ApnDate> seen = new HashSet<ApnDate> ();
        
        PrintWriter pw = null;
        try { pw = new PrintWriter(OBS1_DIR + "analysis/compare-hpi-knn.txt");}
        catch (FileNotFoundException e) {throw new RuntimeException(e);}
        
        writeHeader(pw);
        double hpiSumSquaredErrors = 0;
        double knnSumSquaredErrors = 0;
        final int NUMBER_OBSERVATIONS = actualApns.getSize(0);
        for (int i = 0; i < NUMBER_OBSERVATIONS; i++) {
            double actualApn = actualApns.get(i);
            double actualDate = actualDates.get(i);
            if (!isDateOfInterest(actualDate))
                continue;
            ApnDate actualApnDate = new ApnDate(actualApn, actualDate);
            if (seen.contains(actualApnDate))
                continue; // don't repeat work
            double closestDate = closestTestDate(actualDate);
            ApnDate estimateKey = new ApnDate(actualApn, closestDate);
            if (!hpiMap.containsKey(estimateKey))
                keyNotFound(estimateKey, "hpi");
            if (!knnMap.containsKey(estimateKey))
                keyNotFound(estimateKey, "knn");
            double actualPrice = actualPricesLog.get(i);
            double hpiPrice = estimatedPrice(hpiMap, actualApn, closestDate);
            double knnPrice = estimatedPrice(knnMap, actualApn, closestDate);
            double hpiError = actualPrice - hpiPrice;
            double knnError = actualPrice - knnPrice;
            hpiSumSquaredErrors += hpiError * hpiError;
            knnSumSquaredErrors += knnError * knnError;
            writeDetail(pw, actualApnDate, actualPrice, estimateKey, hpiPrice, hpiError, knnPrice, knnError);
        }
        double hpiRmse = Math.sqrt(hpiSumSquaredErrors / NUMBER_OBSERVATIONS);
        double knnRmse = Math.sqrt(knnSumSquaredErrors / NUMBER_OBSERVATIONS);
        writeRmse(pw, "hpi", hpiRmse);
        writeRmse(pw, "knn", knnRmse);
        pw.close();
    }
    
    private boolean isDateOfInterest(double dayNumber) {
        return (lowestTestDay <= dayNumber && dayNumber <= highestTestDay);
    }
    
    // make sure size of the parallel arrays is the same
    private Integer commonSize = null;
    private void checkSize(Tensor x) {
        if (x.getNDimensions() != 0) 
            throw new IllegalArgumentException("must be 1d; x=" + x);
        if (commonSize == null)
            commonSize = x.getSize(0);
        else 
            if (commonSize != x.getSize(0))
                throw new IllegalArgumentException("x is not of size " + commonSize + " ;x=" + x);
    }
    
    // make sure sizes of the parallel arrays are the same
    private void checkSizes(Tensor a, Tensor b, Tensor c) {
        checkSize(a);
        checkSize(b);
        checkSize(c);
    }
    
    // return closest test date to the transaction day number
    // metric uses days past epoch
    private double closestTestDate(double actualDate) {
        String[] years = {"2000", "2001", "2002", "2003", "2004", "2005", "2006", "2007", "2008", "2009"};
        String[] days = {"0215", "0515", "0815", "1115"};
                
        final long actualDay = Date.newInstance(actualDate).getDaysPastEpoch();
        
        // search through all possible test days and remember day with shortest distance from actual day
        long shortestDistance = Long.MAX_VALUE;
        String bestDate = null;
        for (String year : years) {
            for (String day : days) {
                final String testDate = year + day;
                final long testDay = new Date(testDate).getDaysPastEpoch();
                final long distance = Math.abs(actualDay - testDay); 
                if (distance < shortestDistance) {
                    shortestDistance = distance;
                    bestDate = testDate;
                }
            }
        }
        return (double) new Date(bestDate).getDaysPastEpoch();
    }
    
    // return estimated price
    private double estimatedPrice(Map<ApnDate,Double> map, double apn, double date) {
        ApnDate key = new ApnDate(apn,date);
        if (map.containsKey(key))
            return map.get(key);
        throw new RuntimeException("not in map; key=" + key);
    }
    
    // report key was not found
    private void keyNotFound(ApnDate apnDate, String which) {
        throw new RuntimeException(which + " did not contains key with apn=" + apnDate.apn + " date=" + apnDate.date);
    }

    
    // construct a TreeMap from the inputs
    private Map<ApnDate,Double> makeMap(Tensor apns, Tensor dates, Tensor pricesLog) {
        Map<ApnDate,Double> result = new HashMap<ApnDate, Double>();
        for (int i = 0; i < apns.getSize(0); i++) {
            result.put(new ApnDate(apns.get(i), dates.get(i)), pricesLog.get(i));
        }
        return result;
    }
    
    // return feature as a tensor
    private Tensor readFeature(String filebasename) {
        CsvReader csvReader = new CsvReader(OBS1_DIR + "features/" + filebasename + ".csv", SEPARATOR_REGEX);
        DataFrame df = csvReader.readOnlyColumn();
        csvReader.close();
        return df.getColumnNamed(filebasename);
    }
    
    // write a detail line
    private void writeDetail(
            PrintWriter pw, 
            ApnDate actualApnDate, 
            double actualPrice, 
            ApnDate estimateApnDate, 
            double hpiPrice, 
            double hpiError,
            double knnPrice,
            double knnError) {
        String s = String.format("%10.0f %8.0f %8.0f %8s %8s %8s %8s %8s %8s",
                actualApnDate.apn, actualApnDate.date, actualPrice,
                estimateApnDate.date, hpiPrice, hpiError,
                estimateApnDate.date, knnPrice, knnError);
        writeLine(pw, s);
    }
    
    // write the 2 header records
    private void writeHeader(PrintWriter pw) {
        String formatter = "%10s %8s %8s %8s %8s %8s %8s %8s %8s";
        writeLine(pw, String.format(formatter, "", "actual", "actual", "hpi", "hpi", "hpi", "knn", "knn", "knn"));
        writeLine(pw, String.format(formatter, "apn", "date", "price", "date", "price", "|error|", "date", "price", "|error|"));
    }
    
    // write line to PrintWriter and stdout
    private void writeLine(PrintWriter pw, String s) {
        pw.println(s);
        System.out.println(s);
    }
    
    // write an RMSE summary line
    private void writeRmse(PrintWriter pw, String which, double rmse) {
        String s = String.format("RMSE for %s = %f", which, rmse);
        writeLine(pw, s);
    }
}
