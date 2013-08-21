package com.roylowrance.thesis;

// main program to test a single set of hyperparameters
// the code is designed only for testing the k parameter to the knn algorithm

import java.io.FileNotFoundException;
import java.io.PrintWriter;

import com.roylowrance.util.CommandLine;
import com.roylowrance.util.Date;
import com.roylowrance.util.Log;
import com.roylowrance.util.Represents;

/**
 * Determine the pair (RMSE,fraction within 10 percent) for a single set of test parameters and write results to a txt file containing the
 * hyperparameters and the 2 results.
 * <p>
 * The text file contains one row in the format <p>hp1|hp2|...|hpN|rmse|within10
 * <p>
 * This implementation handles only testing of knn for which there is one hyperparameter k.
 * 
 * @author Roy Lowrance
 * 
 */
public class HpTest {


    /**
     * Functor to determine if day number is in test set
     * @author roy
     *
     */
    private static class IsTestDayNumber {
        private long lowestDayNumber;
        private long highestDayNumber;

        // constructor
        /**
         * Construct and establish the interval that contains selected day numbers.
         * <p>
         * The interval is lowestDayNumber <= dayNumber <= highestDayNumber
         * 
         * @param lowestDayNumber  lower bound on day numbers
         * @param highestDayNumber upper bound on day numbers
         */
        public IsTestDayNumber(long lowestDayNumber, long highestDayNumber) {
            this.lowestDayNumber = lowestDayNumber;
            this.highestDayNumber = highestDayNumber;
        }
        /**
         * Return true iff the day number is in the test set specified by the constructor.
         * @param dayNumber the number of days past the epoch
         * @return true if day number is within the interval specified during construction else false
         */
        public boolean apply(long dayNumber) {
            return (dayNumber >= lowestDayNumber) && (dayNumber <= highestDayNumber);
        }
    }

    /**
     * Conduct search specified on command line, writing file .../analysis/search-knn-OBS-STARTDATE-ENDDATE-n.txt
     * where n is the value of k.
     * <p>
     * A companion shell script hptest-1a-cat.sh concatenates all the txt files into a single file containing
     * the result lines sorted by k.
     * <p>
     * Command line arguments:
     * <ul>
     * <li> --algo=knn 
     * <li> --dataDir=pathToDataDirectory 
     * <li> --k=N a single k value to test (by producing RMSE and fraction within 10 percent)
     * <li> --obs=[1A|2R|3R] observation set to use; only 2R is implemented so far 
     * <li> --testDateFirst=YYYYMMDD first test date (ex: 20000101) 
     * <li> --testDateLast=YYYYMMDD
     * </ul>
     * 
     * @param commandLineArguments  the command line from operating system
     */
    public static void main(String[] commandLineArguments) {
        Log log = new Log("HpTest.main", true);

        // remove the need to declare all the function and inner classes to be static
        HpTest hs = new HpTest();

        // read and validate command line parameters
        CommandLineParameters clp = hs.commandLineValidate(commandLineArguments);

        if (clp.algo.equals("knn") && clp.k != null)
            hs.knnTest(clp.obs, clp.dataDir, clp.k, clp.testDateFirst, clp.testDateLast, new TestData(clp.obs, clp.dataDir));
        else
            throw new RuntimeException("unimplemented case");

        clp.print();
        System.out.println("Finished.");
    }

    // //////////////////////////////// private classes

    private static class TestResult {
        public double rmse;
        public double within10;
    }

    // ////////////////////////////////// private methods

    /**
     * Determine RMSE and fraction within 10 percent for hyperparameter k using the knn algorithm and testing
     * each transaction in the specified date range.
     * 
     * @param obs            name of the observation set
     * @param dataDir        path to find the data directory
     * @param k              the value of k, an integer
     * @param testDateFirst  first date to test YYYYMMDD
     * @param testDateLast   last date to test YYYYMMDD
     * @param testData       all the test data
     */
    private void knnTest(String obs, String dataDir, double k, String testDateFirst, String testDateLast, TestData testData) {
        String[] keyNames = { "k" };
        String cacheDir = dataDir + "generated-v4/obs" + obs + "/caches/";

        // construct the KNearestNeighbors object and read in the cache
        // NOTE: compare log(price), not price
        KNearestNeighbors knn = new KNearestNeighbors(testData.getXs(), testData.getYs(), cacheDir, "-merged");
        final String mergedCacheFileNameSuffix = "-merged";
        knn.cacheMerge(mergedCacheFileNameSuffix);

        // determine RMSE and fraction within 10 percent of actuals
        TestResult testResult = knnTestK(k, makeTestDayNumber(testDateFirst, testDateLast), testData, cacheDir, knn);

        // write k and result to file
        PrintWriter pw;
        try {
            String filePath = dataDir + "generated-v4/obs" + obs + "/analysis/search-knn" + "-" + obs + "-" + testDateFirst + "-"
                    + testDateLast + "-" + (int) k + ".txt";
            pw = new PrintWriter(filePath);
        } catch (FileNotFoundException e) {
            throw new RuntimeException(e);
        }

        // write one record
        final String separator = "|";
        pw.print(String.format("%03d", (int) k));
        pw.print(separator);
        pw.print(testResult.rmse);
        pw.print(separator);
        pw.print(testResult.within10);
        pw.println();

        pw.close();

        // write results to stdout
        System.out.format("results for k = %d: rmse = %f fraction within 10 percent = %f%n", (int) k, testResult.rmse, testResult.within10);
    }

    /**
     * Determine rmse and within10 for the hyperparameter k.
     * @param k
     * @param isTestDayNumber
     * @param testData
     * @param cacheDir
     * @param knn
     * @return
     */
    private TestResult knnTestK(double k, IsTestDayNumber isTestDayNumber, TestData testData, String cacheDir, KNearestNeighbors knn) {
        final boolean debugging = false;
        Log log = new Log("HpTest.appendKnnTestResult", true);
        final boolean printElapsedTime = true;

        double sumSquaredErrors = 0;
        int countNumberWithin10 = 0;
        int countEstimated = 0;
        final int testIndices = testData.getYs().getSize(0);
        for (int testIndex = 0; testIndex < testIndices; testIndex++) {
            long dayNumber = testData.getDays().getLong(testIndex);
            if (!isTestDayNumber.apply(dayNumber))
                continue;
            countEstimated++;
            // both estimate and actual are in the log domain
            final long startTime = System.nanoTime();
            double estimateLog = knn.estimate((int) k, testData.getXs().selectRow(testIndex), testIndex);
            final int reportingFrequency = 10000;
            if (printElapsedTime && countEstimated % reportingFrequency == 1) {
                final long endTime = System.nanoTime();
                double elapsedSeconds = (endTime - startTime) / 1e9;
                System.out.format("HpTest.knnAppendTestResults #%d (testIndex %d of %d) k %.0f took %f seconds%n", countEstimated,
                        testIndex, testIndices, k, elapsedSeconds);
            }
            double actualLog = testData.getYs().get(testIndex);

            // compute RMSE partial result based on log values
            double error = estimateLog - actualLog;
            sumSquaredErrors += error * error;

            // compute within 10 percent partial result
            double estimatePlain = Math.exp(estimateLog);
            double actualPlain = Math.exp(actualLog);
            double relativeError = Math.abs((estimatePlain - actualPlain) / actualPlain);
            if (relativeError <= 0.10)
                countNumberWithin10++;
            if (debugging)
                log.format("testIndex %d actualLog %10.6f estimateLog %10.6f error %10.6f%n" +
                        "actualPlain %10.0f estimatePlain %10.0f relerror %10.6f%n",
                        testIndex,actualLog,estimateLog,error,actualPlain,estimatePlain,relativeError);
        }
        log.println("testIndices:" + testIndices);
        log.println("countEstimated:" + countEstimated);
        TestResult testResult = new TestResult();
        testResult.rmse = Math.sqrt(sumSquaredErrors / countEstimated);
        testResult.within10 = countNumberWithin10 * 1.0 / countEstimated;
        return testResult;
    }

    /**
     *  return an IsTestDayInstance for the observation set
     * @param testDateFirst
     * @param testDateLast
     * @return
     */
    private IsTestDayNumber makeTestDayNumber(String testDateFirst, String testDateLast) {
        return new IsTestDayNumber(Date.daysPastEpoch(testDateFirst), Date.daysPastEpoch(testDateLast));
    }

    // /////////////////////////////////////////////////////////////////////////////////
    // command line parameters
    // /////////////////////////////////////////////////////////////////////////////////

    static class CommandLineParameters {
        public String algo;
        public String dataDir;
        public Double k; // ... and it keeps things simplier to have them all be the same type
        public String obs;
        public String testDateFirst;
        public String testDateLast;

        public void print() {
            System.out.format("Command Line Parameters as parsed%n");

            System.out.format("algo          = %s%n", algo);
            System.out.format("dataDir       = %s%n", dataDir);
            System.out.format("k             = %s%n", k);
            System.out.format("obs           = %s%n", obs);
            System.out.format("testDateFirst = %s%n", testDateFirst);
            System.out.format("testDateLast  = %s%n", testDateLast);
        }
    }

    /**
     * Return command line parameters that are present. Set those nnot present to null.
     * @param args
     * @return
     */
    private CommandLineParameters commandLineValidate(String[] args) {
        final boolean logging = false;
        Log log = new Log("HpTest.processCommandLine", logging);
        CommandLine cl = new CommandLine(args);
        if (logging)
            cl.println();
        CommandLineParameters clp = new CommandLineParameters();

        // required --algo=[knn|kwavg|llr]
        clp.algo = cl.optionIsOneOf("--algo", "knn", "kwavg", "llr");

        // required --dataDir=path/to/data/dir/
        clp.dataDir = cl.optionValue("--dataDir");

        clp.k = cl.optionIsDouble("--k");

        // required --obs==[1A|2R|3R]
        clp.obs = cl.optionIsOneOf("--obs", "1A", "2R", "2A");

        // required --testDateFirst=YYYYMMDD
        clp.testDateFirst = cl.optionValue("--testDateFirst");
        if (!Represents.date(clp.testDateFirst))
            throw new IllegalArgumentException("--testDateFirst does not represent a valid date; testDateFirst=" + clp.testDateFirst);

        // required --testDateFirst=YYYYMMDD
        clp.testDateLast = cl.getOptionValue("--testDateLast");
        if (!Represents.date(clp.testDateLast))
            throw new IllegalArgumentException("--testDateLast does not represent a valid date; testDateLast=" + clp.testDateLast);

        clp.print();
        return clp;
    }

}
