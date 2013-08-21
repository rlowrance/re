package com.roylowrance.thesis;

// main program to create estimates using specified hyperparameters and test data
// writes a csv file in the analysis directory of the selected observation set

import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

import com.roylowrance.util.CommandLine;
import com.roylowrance.util.CsvReader;
import com.roylowrance.util.CsvWriter;
import com.roylowrance.util.DataFrame;
import com.roylowrance.util.Date;
import com.roylowrance.util.LineScanner;
import com.roylowrance.util.Log;
import com.roylowrance.util.Represents;
import com.roylowrance.util.Tensor;

/*
 * Main program to write a csv file containing estimates for a specified algorithm and hyperparameters 
 * for each mid-quarter date in years 2000, 2001, ..., 2009. To date, these
 * algorithms are not trained so there is no learned W vector to manage.
 * <p>
 * The program can run for a long time, so it periodically writes the csv file to disk. However, this
 * implementation does not re-use this potentially-partial set of results if the program is restarted.
 * <p>
 * Program will read 112,143 APNs and estimate prices and estimate 40 prices for each (once per calendar
 * quarter for 10 years) for a total of about 4,500,000 estimates.
 * <p>
 * Each estimate takes about 0.07 seconds, so 4,500,000 will take 315,000 seconds which is 87 hours.
 * Plan is to run this on one core. Note that this program appends the estimates to the csv file, so 
 * that results are not lost if this program is stopped.
 */
public class CreateEstimates {

    /**
     * Hold the estimation data and, at construction time, compute the values needed to standardize
     * new day numbers.
     * 
     * @author roy
     *
     */
    private static class EstimationData {
        public Tensor apns;
        public Tensor days;
        public int indexOfStandardizedDay;
        public Tensor xs;
        public Tensor ys;

        private double daysMean;
        private double daysStandardDeviation;

        // constructor also computes factors needed to standardize a day number
        public EstimationData(Tensor apns, Tensor days, int indexOfStandardizeDay, Tensor xs, Tensor ys) {
            this.apns = apns;
            this.days = days;
            this.indexOfStandardizedDay = indexOfStandardizeDay;
            this.xs = xs;
            this.ys = ys;
            setDaysStandardizationValues();
        }

        /**
         * Determine factors (mean and standard deviation) needed to standardize day numbers.
         */
        private void setDaysStandardizationValues() {
            // compute from first principles
            this.daysMean = Tensor.mean(days);
            this.daysStandardDeviation = Tensor.std(days);
        }

        /**
         * Return standardized day number for a date YYYYMMDD
         * @param date  the date "YYYYMMDD"
         * @return      the standardized day number (number of days past epoch, standardized)
         */
        public double standardizedDay(String date) {
            IAE.notNull(date, "date");
            long dayNumber = Date.daysPastEpoch(date);
            return (dayNumber - daysMean) / daysStandardDeviation;
        }
    }

    /**
     * Estimate value for every APN in the the quarters in 2000, 2001, ..., 2009 and write these estimates to
     * file analysis/estimates-knn-PIECE.txt. Write progress lines to stdout.
     * <p>
     * The APNs are determined by reading the transaction file. Each APN may occur multiple times, so the implementation
     * keeps track of APNs already seen and does not reprocess them. There may be some APNs that are not in the 
     * test period (the quarters estimated) so the entire transaction file needs to be examined.
     * 
     * @param piece           piece to create
     * @param dataDir         location of data directory     
     * @param k               value to use for k
     * @param obs             name of observation set
     * @param estimationData  previously existing estimation data
     * @param pieces          number of pieces
     */
    private void estimatesKnn(int piece, String dataDir, int k, String obs, EstimationData estimationData, int pieces) {

        final boolean debugging = false;
        Log log = new Log("CreateEstimate.estimatesKnn", true);
        //final int saveFrequency = 1000;

        String txtFilePath = dataDir + "generated-v4/obs" + obs + "/analysis/estimates-knn-" + obs + "-" + piece + ".txt";
        PrintWriter textFile;
        try {textFile= new PrintWriter(txtFilePath);}
        catch (FileNotFoundException e) {throw new RuntimeException("File Not Found e=" + e);}
        //PriorResults priorResults = readPriorResultsFile(csvFilePath);
        //Set<ApnDateK> processed = priorResults.knownResultIds;
        //CsvWriter csvWriter = priorResults.csvWriter;  // header already written
        
        // setup the k nearest neighbors algorithm
        final String cacheFileNameSuffix = "-merged";
        KNearestNeighbors knn = new KNearestNeighbors(
                estimationData.xs, 
                estimationData.ys,
                null,  // no cache 
                cacheFileNameSuffix);

        // process each transaction in the estimation data
        // determine each unique APN
        // for each unique APN in the piece, estimate its value at mid-quarter in the years 2000, 2001, ..., 2009
        final int numberIndices = estimationData.xs.getSize(0);
        final Tensor xs = estimationData.xs;
        final int indexOfStandardizedDay = estimationData.indexOfStandardizedDay;
        final int omitNoXsRow = -1; // indicator to knn.estimate to use all the xs
        int countApnsEstimated = 0;
        Set<ApnDateK> processed = new HashSet<ApnDateK> ();
        for (int testIndex = 0; testIndex < numberIndices; testIndex++) {
            final double apn = estimationData.apns.get(testIndex);
            //System.out.println("apn " + apn + " pieces " + pieces + " rem " + (apn%pieces) + " piece " + piece);
            if (piece != (apn % pieces)) {
                //log.format("APN %.0f is not in our piece%n", apn);
                continue; // the apn is not in our piece
            }
            log.format("APN %.0f is in our piece%n", apn);
            countApnsEstimated++;
            final long apnStartTime = System.nanoTime();
            
                for (int year = 2000; year < 2010; year++) {
                    for (String dateString : makeDateStrings(year)) {
                    	// check if we already have an estimate
                    	ApnDateK newKey = new ApnDateK(apn, dateString, k);
                    	if (processed.contains(newKey)) {
                    		log.format("skipping %.0f %s %k since already done%n", apn, dateString, k);
                    		continue; // on to next date
                    	}
                    	processed.add(newKey);
                    	
                    	// create and save the estimate
                        Tensor query = xs.selectRow(testIndex);
                        query.set(indexOfStandardizedDay, estimationData.standardizedDay(dateString));
                        long startTime = System.nanoTime();
                        String record = String.format("%.0f,%s,%d,%.2f", apn, dateString, k, 
                                Math.exp(knn.estimate((int) k, query, omitNoXsRow)));
                        //String txtRow = makeTextFileRecord(apn, dateString, (int) k, knn.estimate((int) k, query, omitNoXsRow));
                        log.println(record);
                        final int apnReportingFrequency = 1000;
                        if (processed.size() % apnReportingFrequency == 0) {
                            double elapsedSeconds = ((System.nanoTime() - startTime) / 1e9);
                            log.format("in %7.5f secs%n", elapsedSeconds);
                        }
                        textFile.println(record);
                    } // end for dateString
                } // end for year  
                
                // maybe write progress info to stdout
                final int indexReportingFrequency = 100;
                if (testIndex % indexReportingFrequency == 0) {
                    System.out.format("estimated APN %.0f in %f seconds%n", apn, (System.nanoTime() - apnStartTime) / 1e9);
                    System.out.format("processed index %d of %d; added %d APNs so far%n", 
                            testIndex, numberIndices, processed.size());
                }
                if (debugging && (processed.size() > 3))
                    break;
        } // end for testIndex

        textFile.close();
        log.format("estimated %d APNs%n", countApnsEstimated);
        log.format("estimated %d values%n", processed.size());
    }

    /**
     * Convert the args to an array of String value.
     * @param apn
     * @param date
     * @param k
     * @param logPrice
     * @return
     */
    private String[] makeCsvRow(double apn, String date, int k, double logPrice) {
        String[] result = new String[4];
        result[0] = String.format("%.0f", apn);
        result[1] = date;
        result[2] = Integer.toString(k);
        result[3] = String.format("%.2f", Math.exp(logPrice));
        return result;
    }

    /**
     * Make the quarterly date strings "YYYYMMDD" needed for a given year.
     * @param year the year "YYYY"
     * @return
     */
    private ArrayList<String> makeDateStrings(int year) {
        ArrayList<String> result = new ArrayList<String>();
        String yearString = String.format("%4d", year);
        result.add(yearString + "0215");
        result.add(yearString + "0515");
        result.add(yearString + "0815");
        result.add(yearString + "1115");
        return result;
    }

    // read the estimation data from the file system
    /**
     * Read and return the estimation data from the file system.
     * @param obs      observation set name; ex: "1A"
     * @param dataDir  path to data directory; ex: "/home/roy/..."
     * @return         collection of estimation data
     */
    private EstimationData makeEstimationData(String obs, String dataDir) {
        String obsDir = dataDir + "generated-v4/obs" + obs + "/";
        String featuresDir = obsDir + "features/";
        String separatorRegex = "\\|";

        // read in features and determine the column index that contains the standardized day value
        CsvReader csvReader = new CsvReader(obsDir + "features-combined.csv", separatorRegex);
        DataFrame dataFrame = csvReader.readAll();
        int indexOfStandardizedDay;
        for (indexOfStandardizedDay = 0; indexOfStandardizedDay < dataFrame.getNames().size(); indexOfStandardizedDay++) {
            if (dataFrame.getNames().get(indexOfStandardizedDay).equals("day-std"))
                break;
        }
        if (indexOfStandardizedDay == dataFrame.getNames().size())
            throw new RuntimeException("day-std not found");

        return new EstimationData(new CsvReader(featuresDir + "apns.csv", separatorRegex).readOnlyColumn().getTensor(), new CsvReader(
                featuresDir + "day.csv", separatorRegex).readOnlyColumn().getTensor(), indexOfStandardizedDay, dataFrame.getTensor(),
                new CsvReader(featuresDir + "SALE-AMOUNT-log.csv", separatorRegex).readOnlyColumn().getTensor());
    }

    private String makePathToCacheDirectory(String dataDir, String obs) {
        return dataDir + "generated-v4/obs" + obs + "/caches/";
    }

    /**
     * Determine estimates for each APN for each test date and write to csv file.
     * 
     * The test dates are the dates in mid-calendar quarter in 2000, 2001, ..., 2009.
     * 
     * Example: To create a piece 23 (in file estimates-knn-23.txt) of the 48 estimate pieces
     *  CreateEstimates --action=23,--algo=knn,--dataDir=../../data/,--k=24,--obs=1A,--pieces=48
     *  
     * Example: To merge 48 pieces into estimates-knn.csv
     *   CreateEstimates --action=merge,--algo=knn,--dataDir=../../data/,--obs=1A,--pieces=48
     * 
     * Command line arguments: 
     * <ul>
     * <li> --action[N|merge]         if n, create estimates-knn-1a-N.csv; 
     *                                if merge, merge all the pieces and estimates-knn-1A.csv together into estimates-knn.csv
     * <li> --algo=[knn|kwavg|llr]    algorithm to test 
     * <li> --dataDir=path/to/data/   where to find <project>/data/ 
     * <li> --k=INTEGER               k value to use 
     * <li> --obs=[1A|2R|3R]          observation set to use
     * <li> --pieces=N                number of pieces
     * </ul>
     * 
     * @param commandLineArguments       command line from operating system
     */
    public static void main(String[] commandLineArguments) {
        Log log = new Log("CreateEstimate.main", true);

        // remove the need to declare all the function and inner classes to be static
        CreateEstimates hs = new CreateEstimates();

        // read, validate, and print command line parameters
        final CommandLine commandLine = new CommandLine(commandLineArguments);
        commandLine.println();
        final String action = commandLine.optionValue("--action");
        final String algo = commandLine.optionIsOneOf("--algo", "knn");
        final String dataDir = commandLine.optionValue("--dataDir");
        final int k = commandLine.optionValueInteger("--k");
        final String obs = commandLine.optionValue("--obs");
        final int pieces = commandLine.optionValueInteger("--pieces");
        
        if (action.equals("merge"))
            hs.merge(algo, dataDir, obs, pieces);
        else if  (Represents.int_(action))
            hs.estimates(Integer.valueOf(action), algo, dataDir, k, obs, pieces);
        else 
            throw new IllegalArgumentException("unknown action =" + action);
        

        commandLine.println();
        System.out.println("Finished.");
        // System.out.println("Wrote to files " + outFileNameBaseSuffix + ".*");
    }
    
    private void estimates(int piece, String algo, String dataDir, int k, String obs, int pieces) {
        if (algo.equals("knn"))
            estimatesKnn(piece, dataDir, k, obs, makeEstimationData(obs, dataDir), pieces);
        else
            throw new IllegalArgumentException("algo not known; algo=" + algo);
    }
    
    private void merge(String algo, String dataDir, String obs, int numPieces) {
        if (algo.equals("knn"))
            mergeKnn(dataDir, obs, numPieces);
        else 
            throw new IllegalArgumentException("unknown algo = " + algo);
    }
    
    /**
     * Append to estimates-knn-1A.csv the info in files estimates-knn-N.txt.
     * @param dataDir  path to data directory
     * @param obs      observation set
     * @param pieces   N runs from 1, 2, ..., pieces
     */
    private void mergeKnn(String dataDir, String obs, int numPieces) {
        String analysisDir = dataDir + "generated-v4/obs" + obs + "/analysis/";
        String csvFilePath = analysisDir + "estimates-knn-1A.csv";
        PriorResults pr = readPriorResultsFile(csvFilePath);
        CsvWriter csvWriter = pr.csvWriter;  // this csv contains the current 
        
        for (int piece = 1; piece < numPieces; piece++) {
            mergeKnnPiece(analysisDir, csvWriter, piece);
        }
        
        csvWriter.close();
    }
    
    /**
     * Append file estimates-knn-PIECE.txt to the csvWriter
     * @param analysisDir path to the analysis directory 
     * @param csvWriter   csv to append to
     * @param piece       piece number
     */
    private void mergeKnnPiece(String analysisDir, CsvWriter csvWriter, int piece) {
        String fileName = "estimates-knn-" + Integer.toString(piece) + ".txt";
        LineScanner ls = new LineScanner(analysisDir + fileName);
        while (ls.hasNextLine()) {
            csvWriter.writeRow(ls.nextLine());
        }
        
    }
    
    private class ApnDateK {
    	public double apn;
    	public String date;
    	public int k;
    	
    	public ApnDateK(double apn, String date, int k) {
    		this.apn = apn;
    		this.date = date;
    		this.k = k;
    	}
    }
    
    private class ResultRow {
    	public double apn;
    	public String date;
    	public int k;
    	public double estimatedValue;
    	
    	public ResultRow(double apn, String date, int k, double estimatedValue) {
    		this.apn = apn;
    		this.date = date;
    		this.k = k;
    		this.estimatedValue = estimatedValue;
    	}
    }
    
    /**
     * Return new CsvWriter positioned to append data rows and containing the header and all the existing results
     * @param csvFilePath path to the csv file
     * @param existingResults the existing results
     * @return a new CsvWriter
     */
    private CsvWriter makeResultsCsvWriter(String csvFilePath, ArrayList<ResultRow> existingResults) {
    	String separator = "|";
    	CsvWriter csvWriter = new CsvWriter(csvFilePath, separator);
    	
    	// write the header
    	String[] headerFields = { "apn", "date", "k", "estimatedValue" };
        csvWriter.writeRow(headerFields);
        
        // write the existing data fields
        for (ResultRow resultRow : existingResults) {
        	csvWriter.writeRow(makeCsvRow(resultRow.apn,
                                          resultRow.date,
                                          resultRow.k,
                                          resultRow.estimatedValue));
        }
        
        return csvWriter;
    }
    
    private class PriorResults {
    	public Set<ApnDateK> knownResultIds;
    	public CsvWriter csvWriter;
    	
    	public PriorResults(Set<ApnDateK> knownResultIds, CsvWriter csvWriter) {
    		this.knownResultIds = knownResultIds;
    		this.csvWriter = csvWriter;
    	}
    }
    
    /**
     * Read the prior results file and return (apns already analyzed, CsvWriter positioned to append new items)
     * @param csvFilePath path to the csv file which may or may not exist when method is called
     * @return Tuple2(a set of double containing apns already completely processed, CsvWriter positioned to write additional data rows)
     */
    private PriorResults readPriorResultsFile(String csvFilePath) {
    	Log log = new Log("CreateEstimate.readPriorResultsFile", true);
    	log.println("reading prior results");
    	log.println("csvFilePath:" + csvFilePath);
    	File file = new File(csvFilePath);
    	if (!file.exists()) {
    		// return empty prior results
    		return new PriorResults(new HashSet<ApnDateK>(),
    				                makeResultsCsvWriter(csvFilePath, new ArrayList<ResultRow>()));    
    	}
    	// accumulate all the results in the existing csv file
    	// build the set of known apns
    	String separatorRegex = "\\|";
    	CsvReader csvReader = new CsvReader(csvFilePath, separatorRegex);
    	ArrayList<String> headerInput = csvReader.next(); // ignore the header
    	
    	ArrayList<ResultRow> existing = new ArrayList<ResultRow>();
    	Set<ApnDateK> alreadyKnown = new HashSet<ApnDateK>();
    	while (csvReader.hasNext()) {
    		ArrayList<String> row = csvReader.next();
    		if (row.size() != 4)
    		    throw new RuntimeException("existing csv row does not have 4 elements; csvFilePath=" + csvFilePath);
    		double apn = Double.valueOf(row.get(0));
    		String date = row.get(1);
    		int k = Integer.valueOf(row.get(2));
    		existing.add(new ResultRow(apn,
    				                   date,
    				                   k,
    				                   Double.valueOf(row.get(3))));
    		alreadyKnown.add(new ApnDateK(apn, date, k));
    	}
    	
    	csvReader.close();
    	System.out.format("Read %d prior results%n", existing.size());
    	
    	// write the csv file
    	String separator = "|";
    	CsvWriter csvWriter = new CsvWriter(csvFilePath, separator);
    	String[] header = { "apn", "date", "k", "estimatedValue" };
    	csvWriter.writeRow(header);
    	
    	for (ResultRow resultRow : existing) {
    		csvWriter.writeRow(makeCsvRow(resultRow.apn,
    				                      resultRow.date,
    				                      resultRow.k,
    				                      resultRow.estimatedValue));
    	}
    	
    	return new PriorResults(alreadyKnown, csvWriter);
    	
    	
    }

}
