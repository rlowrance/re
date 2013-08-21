package com.roylowrance.thesis;

import java.io.IOException;

import com.roylowrance.util.CommandLine;
import com.roylowrance.util.Date;
import com.roylowrance.util.Log;
import com.roylowrance.util.Report;
import com.roylowrance.util.Represents;
import com.roylowrance.util.Tensor;

//for obs1A, with about 200,000 observations
//- time to compute k nearest neighbors for one query point: 0.065 seconds
//- rate is thus 15/sec = 900/min = 55,000/ hour
//- hence can compute them all with 1 core in about 4 hours
//for obs2R, with about 1.5 million observations
//- time to compute k nearest neighbors for one query point: 0.5 seconds
//- rate is thus 2/sec = 120/min = 7200 per hour
//- hence can compute them all with 1 core in about 214 hours = 9 days
//- with 4 cores in about 53.5 hours = 2.2 days
//- with 8 cores in about 26.75 hours = 1.1 days
// -with 16 cores in about 13.4 hours = 0.6 days
//The main program has a constant (numberPieces) that is 16, based on the above
//considerations


// The cache contains the 256 nearest neighbors for every transaction. An earlier
// version had the neighbors for only the training transactions. The constant 256
// is coded into the class NearestNeighborsCache

//Create the cache in PIECES + 1 passes
//step p (p in 1, 2, ..., PIECES) creates a shard of the final cache in nearestNeighborsCache-piece-P.csv
//step PIECES+1 combines the shards into nearestNeighborsCache-merged.csv

public class CreateNearestNeighborsCache {
    private static Report balanceReport;
    private static int PIECES = 48;
    
    private static class CommandLineParameters{
        String obs = null;
        boolean isMerge = false;
        int pieceNumber = 0;
        String pathToDataDir;
    }
    
    /**
     * Main program to compute pieces of the knn cache or to splice the pieces together into one big cache
     * 
     * Invoke with command line: --obs=[1R|2R] --action=[N|merge]
     *   Create piece N of the cache. There are 16 pieces all together (N = 1, 2, ..., 16)
     *   The file created is <project>/data/generated-v4/obsOBS/caches/NearestNeighborsCache-N.csv
     * Invoke with command line: merge
     *   Merge the 64 pieces together into file 
     *   <project>/data/generated-v4/obsObs/caches/<SHA>.KNearestNeighbors-merged
     *   (Someone should rename the suffix to KNearestNeighbors so that it can be found by 
     *   this class when invoked from other programs)
     * @param args the command line
     *      Either N or merge
     */
    public static void main(String[] args)
    throws ClassNotFoundException, IOException {
        Log log = new Log("CreateNearestNeighborsCache.main", true);

        CommandLineParameters clp = validateAndParseCommandLine(args);

        String cacheFileDirectory = clp.pathToDataDir + "generated-v4/obs" + clp.obs + "/caches/";
        String cacheFileBaseName = "nearestNeighborCache";
        String cacheFileBasePath = cacheFileDirectory + cacheFileBaseName;
        log.println("cacheFileBasePath:" + cacheFileBasePath);
        String now = Date.currentDateAndTime();
        balanceReport = new Report(cacheFileBasePath + "-report-" + now + ".txt");
        balanceReport.println("Balance report created " + now);
        balanceReport.println("obs " + clp.obs);
        
        // read the search data
        TestData testData = new TestData(clp.obs, clp.pathToDataDir);

        if (clp.isMerge) {
            mergePieces(PIECES, testData.getXs(), testData.getYs(), cacheFileDirectory);
        }
        else {
            createPiece(
                    clp.pieceNumber, 
                    PIECES, 
                    testData.getXs(), 
                    testData.getYs(),
                    testData.getDays(), 
                    cacheFileDirectory);  
        }
        balanceReport.close();
        System.out.println("CreateNearestNeighbors.main finished");
    }
    
    // create  a piece of the cache in a file of its own
    // NOTE: this method creates too much data as we need only the values that will be used
    // in training and the code below creates all values.
    // But there is a limit to how much optimization makes sense.
    public static void createPiece (
            int pieceNumber, 
            int numberPieces, 
            Tensor xs, 
            Tensor ys,
            Tensor days, 
            String cacheFileDirectory)
    throws ClassNotFoundException, IOException {
        final boolean debugging = false;
        if (debugging)
            System.out.println("CreateNearestNeighborsCache.createPiece is debugging");
        Log log = new Log("CreateNearestNeighborsCache.createPiece", false);
        IAE.is2D(xs, "xs");
        IAE.is1D(ys, "ys");
        IAE.is1D(days, "days");
        IAE.lessEqual(pieceNumber, numberPieces, "pieceNumber", "numberPieces");
        IAE.isNotNull(cacheFileDirectory, "cacheFileDirectory");
        
        int pieceCounter = 1;
        final int numberObservations = xs.getSize(0);

        // construct knn algo with a cache, as we will write to the cache
        KNearestNeighbors knn = new KNearestNeighbors(xs, ys, cacheFileDirectory, pieceSuffix(pieceNumber));
        
        int countNeighborsDetermined = 0;
        int countNotInPiece = 0;
        int countNotInTestSet = 0;
      
        for (int queryIndex = 0; queryIndex < numberObservations; queryIndex++) {
            if (pieceCounter == pieceNumber) {
                final long startTime = System.nanoTime();
                log.println("pieceNumber:" + pieceNumber + " queryIndex:" + queryIndex);
                
                // estimate for any value of k (say k = 1)
                // the reason is that we don't use the estimate, we just want the side
                // effect of calculating the 256 nearest neighbors
                final int k = 1;
                knn.estimate(k, xs.selectRow(queryIndex), queryIndex); 
               
                countNeighborsDetermined++;
                final int reportingFrequency = 1000;
                if (countNeighborsDetermined % reportingFrequency == 0) {
                    final long elapsedSeconds = System.nanoTime() - startTime;
                    System.out.format(
                            "finished query index %d of piece %d of %d in %6.3f seconds%n",
                            queryIndex, pieceNumber, numberPieces, elapsedSeconds / 1e9);
                }
            }
            else {
                countNotInPiece++;
            }

            pieceCounter++;
            if (pieceCounter > numberPieces)
                pieceCounter = 1;
            if (debugging && countNeighborsDetermined > 3)
                break;
        }
        
        // write the cache
        
        log.format("writing cache piece %d to directory ", pieceNumber, cacheFileDirectory);
        knn.cacheWrite();
        balanceReport.format("wrote piece %d with %d records%n",
                pieceNumber, countNeighborsDetermined);
        balanceReport.format("skipped %d as not in test set%n", countNotInTestSet);
        balanceReport.format("skipped %d as in test set but not in piece%n", countNotInPiece);
      
        balanceReport.format("read %d observations%n", numberObservations);
        if ((!debugging) && numberObservations != countNeighborsDetermined + countNotInTestSet + countNotInPiece)
            throw new RuntimeException("out of balance");
        balanceReport.format("Wrote to directory %s%n", cacheFileDirectory);
        System.out.println("CreateNearestNeighborsCache.createPiece finished");
    }
    
    // read  <project-dir>/data/generated-v4/obsOBS/caches/nearestNeighborsCache-piece-N.csv
    // write <project-dir>/data/generated-v4/obsOBS/cache/nearestNeighborsCache-merged.csv
    public static void mergePieces(int numberPieces, Tensor xs, Tensor ys, String cacheDirectory)
    throws IOException {
        Log log = new Log("CreateNearestNeighborsCache.mergePieces", true);
        // start to create the merged cache
        KNearestNeighbors knn = new KNearestNeighbors(xs, ys, cacheDirectory, "-merged");
        balanceReport.println("merge");
        int totalRecordsAdded = 0;
        for (int pieceNumber = 1; pieceNumber <= numberPieces; pieceNumber++) {
            log.println("starting to merge piece " + pieceNumber);
            final int recordsAdded = knn.cacheMerge("-" + pieceNumber);
            balanceReport.format("added %d records from piece %d%n", recordsAdded, pieceNumber);
            totalRecordsAdded += recordsAdded;
        }
        log.println("starting to write the merged cache");
        final int recordsWritten = knn.cacheWrite();
        balanceReport.format("Wrote %d records; should have written %d%n", recordsWritten, totalRecordsAdded);
        if (recordsWritten != totalRecordsAdded)
            throw new RuntimeException("out of balance; records written=" + recordsWritten + " ; records added=" + totalRecordsAdded);
    }
    
    // return suffix to cache file name
    public static String pieceSuffix(int pieceNumber) {
        return "-" + Integer.toString(pieceNumber);
    }


  
    // validate and parse the command line
    // --obs=[1A|2R]
    // --action=[N|merge]
    // --dataDir=path/to/data/directory
    private static CommandLineParameters validateAndParseCommandLine(String[] args) {
        Log log = new Log("KNearestNeighbors.CommandLineParameters", false);
        CommandLine cl = new CommandLine(args);
        System.out.println("command line:"  + cl);

        if (!(cl.isPresent("--action") && cl.isPresent("--dataDir") && cl.isPresent("--obs"))) 
            throw new IllegalArgumentException("required parameters are --action=[N|merge] --dataDir=path/to/data/dir/ --obs=[1A|2R]");
        
        CommandLineParameters clp = new CommandLineParameters();
        
        // --action

        String action = cl.getOptionValue("--action");
        log.println("action:" + action);
        if (action.equals("merge")) {
            clp.isMerge = true;
        }
        else if (Represents.int_(action)) {
            clp.pieceNumber = Integer.parseInt(action);
            if (clp.pieceNumber < 1 || clp.pieceNumber > PIECES)
                throw new IllegalArgumentException("piece number in [1,16]; piece number=" + clp.pieceNumber);
        }
        else 
            throw new IllegalArgumentException("--action=[merge|N]");
        
        // --data
        clp.pathToDataDir = cl.getOptionValue("--dataDir");

    
        // --obs
        clp.obs = cl.getOptionValue("--obs");
        if (!(clp.obs.equals("1A") || clp.obs.equals("2R")))
            throw new IllegalArgumentException("parameter is --obs=[1A|2R]");
    
        return clp;
    }
}

