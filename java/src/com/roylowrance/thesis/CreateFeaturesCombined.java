package com.roylowrance.thesis;

import java.io.IOException;
import java.util.HashMap;

import com.roylowrance.util.CommandLine;
import com.roylowrance.util.CsvReader;
import com.roylowrance.util.CsvWriter;
import com.roylowrance.util.DataFrame;
import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;


// Read the obsOBS/features/* files and combine them into one CSV in obsOBs/COMBINATION_FILE_NAME.csv
public class CreateFeaturesCombined {
    
    // command line parameters
    // --obs=[1A|2R]  which observation set to use
    //          reads from <project>/data/generated-v4/obsOBS/features/*.csv
    // --combination=COMBINATION_FILE_NAME name of file to create
    //          writes <project/data/generated-v4/obsOBS/COMBINATION_FILE_NAME
    public static void main(String[] args)
    throws IOException {
        Log log = new Log("CreateFeaturesCombined", true);       
        CommandLineParameters clp = parseCommandLine(args);
        
        // setup file paths
        String baseName = Dir.project() + "data/generated-v4/obs" + clp.obs;
        String baseDir = Dir.project() + "data/generated-v4/obs" + clp.obs + "/";
        String inDir = baseDir + "features/";
        String outFilePath = baseDir + clp.combinationFileName;
        
        create(inDir, outFilePath, clp.obs);
        System.out.println("finished CreateFeaturesCombined; --obs=" + clp.obs + " --combination=" + clp.combinationFileName);
    }
    
    // read the files /features/*.csv and create COMBINATION_FILE_NAME
    static void create  (String inDir, String outFilePath, String obs) 
    throws IOException {
        final String separatorRegex = "\\|";
        final String delimiter = "|";
        String[] inFieldNames = makeInFieldNames(obs);
        
        // read each feature file
        // accumulate results into map allColumns
        HashMap<String,Tensor> allColumns = new HashMap<String,Tensor> ();
        Integer numberRows = null;
        for (String inFileName : inFieldNames) {
            CsvReader csvReader = new CsvReader(inDir + inFileName + ".csv", separatorRegex);
            DataFrame dataFrame = csvReader.readAll();
            csvReader.close();
            if (numberRows == null) {
                numberRows = dataFrame.getTensor().getSize(0);
            }
            else {
                int nextNumberRows = dataFrame.getTensor().getSize(0);
                if (nextNumberRows != numberRows)
                    throw new RuntimeException("mismatch; nextNumberRows=" + nextNumberRows + " numberRows=" + numberRows);
            }
            allColumns.put(inFileName, dataFrame.getTensor()); // save 2D tensor with 1 column
            
        }
        
        // create a single tensor holding all the columns now in allColumns
        final int numberColumns = inFieldNames.length;
        Tensor bigTensor = new Tensor(numberRows, numberColumns);
        for (int columnNumber = 0; columnNumber < numberColumns; columnNumber++) {
            String fieldName = inFieldNames[columnNumber];
            Tensor savedTensor = allColumns.get(fieldName);
            // set the row
            for (int rowNumber = 0; rowNumber < numberRows; rowNumber++)
                bigTensor.set(rowNumber, columnNumber, savedTensor.get(rowNumber, 0)); // savedTensor is 2D
        }
        
        // write bigTensor; first the header then the data
        CsvWriter csvWriter = new CsvWriter(outFilePath, delimiter);
        csvWriter.writeRow(inFieldNames); // write header
        csvWriter.writeRows(bigTensor); // write data
        csvWriter.close();
    }
    
    // return array of field names for the observation set
    static String[] makeInFieldNames(String obs) {
        if (obs.equals("1A"))
            return makeInFieldNames1A();
        else if (obs.equals("2R"))
            return makeInFieldNames2R();
        else
            throw new IllegalArgumentException("bad obs; obs=" + obs);
    }
    
    static String[] makeInFieldNames1A() {
        String[] names = {
                "ACRES-log-std",
                "BEDROOMS-std",
                "census-avg-commute-std",
                "census-income-log-std",
                "census-ownership-std",
                "day-std",                 // not date nor day
                "FOUNDATION-CODE-is-CRE",  // omit first code in all 1-in-K fields
                "FOUNDATION-CODE-is-MSN",
                "FOUNDATION-CODE-is-PIR",
                "FOUNDATION-CODE-is-RAS",
                "FOUNDATION-CODE-is-SLB",
                "FOUNDATION-CODE-is-UCR",
                "HEATING-CODE-is-001",
                "HEATING-CODE-is-BBE",
                "HEATING-CODE-is-CL0",
                "HEATING-CODE-is-FA0",
                "HEATING-CODE-is-FF0",
                "HEATING-CODE-is-GR0",
                "HEATING-CODE-is-HP0",
                "HEATING-CODE-is-HW0",
                "HEATING-CODE-is-RD0",
                "HEATING-CODE-is-SP0",
                "HEATING-CODE-is-ST0",
                "HEATING-CODE-is-SV0",
                "HEATING-CODE-is-WF0",
                "IMPROVEMENT-VALUE-CALCULATED-log-std",
                "LAND-VALUE-CALCULATED-log-std",
                "latitude-std",
                "LIVING-SQUARE-FEET-log-std",
                "LOCATION-INFLUENCE-CODE-is-IBF",
                "LOCATION-INFLUENCE-CODE-is-ICA",
                "LOCATION-INFLUENCE-CODE-is-ICR",
                "LOCATION-INFLUENCE-CODE-is-ICU",
                "LOCATION-INFLUENCE-CODE-is-IGC",
                "LOCATION-INFLUENCE-CODE-is-ILP",
                "LOCATION-INFLUENCE-CODE-is-IRI",
                "LOCATION-INFLUENCE-CODE-is-IWL",
                "longitude-std",
                "PARKING-SPACES-std",
                "PARKING-TYPE-CODE-is-120",
                "PARKING-TYPE-CODE-is-140",
                "PARKING-TYPE-CODE-is-450",
                "PARKING-TYPE-CODE-is-920",
                "PARKING-TYPE-CODE-is-A00",
                "PARKING-TYPE-CODE-is-ASP",
                "PARKING-TYPE-CODE-is-OSP",
                "PARKING-TYPE-CODE-is-PAP",
                "PARKING-TYPE-CODE-is-Z00",
                "percent-improvement-value-std",
                "POOL-FLAG-is-1",
                "ROOF-TYPE-CODE-is-G00",
                "ROOF-TYPE-CODE-is-I00",
                "SALE-AMOUNT-log-std",
                "TOTAL-BATHS-CALCULATED-std",
                "TRANSACTION-TYPE-CODE-is-3",
                "YEAR-BUILT-std"
        };
        return names;
    }
    
    static String[] makeInFieldNames2R() {
        String[] names = {
                "ACRES-log-std",
                "BEDROOMS-std",
                "census-avg-commute-std",
                "census-income-log-std",
                "census-ownership-std",
                "day-std",                 // not date nor day
                "IMPROVEMENT-VALUE-CALCULATED-log-std",
                "LAND-VALUE-CALCULATED-log-std",
                "latitude-std",
                "LIVING-SQUARE-FEET-log-std",
                "longitude-std",
                "PARKING-SPACES-std",
                "percent-improvement-value-std",
                "POOL-FLAG-is-1",
                "SALE-AMOUNT-log-std",
                "TOTAL-BATHS-CALCULATED-std",
                "TRANSACTION-TYPE-CODE-is-3",
                "YEAR-BUILT-std"
        };
        return names;
    }
    
    static class CommandLineParameters {
        public String combinationFileName;
        public String obs;
        
        public CommandLineParameters(String combinationFileName, String obs) {
            this.combinationFileName = combinationFileName;
            this.obs = obs;
        }
    }
    
    static CommandLineParameters parseCommandLine(String[] args) {
        Log log = new Log("CreateFeaturesCombination.parseCommandLine", true);
        for (String arg : args)
            log.println("arg:" + arg);
       
        CommandLine cl = new CommandLine(args);
        
        // --obs=OBS is required
        if (!cl.isPresent("--obs="))
            throw new IllegalArgumentException("missing --obs; args=" + args);
        
        // --combination=COMBINATION_FILE_NAME is required
        if (!cl.isPresent("--combination="))
            throw new IllegalArgumentException("missing --combination; args=" + args);
        
        return new CommandLineParameters(cl.getOptionValue("--combination="), cl.getOptionValue("--obs="));
        
    }


}
