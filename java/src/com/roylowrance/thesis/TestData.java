package com.roylowrance.thesis;

import com.roylowrance.util.CsvReader;
import com.roylowrance.util.Tensor;
// hold the data needed to search over hyper parameters

public class TestData {
    private Tensor days; // days past epoch (without loss of precision, because of upstream processes)
    private Tensor xs;
    private Tensor ys;

    // read the training data from the file system
    public TestData(String obs, String pathToDataDir) {
        String obsDir = pathToDataDir + "generated-v4/obs" + obs + "/";
        String featuresDir = obsDir + "features/";
        String separatorRegex = "\\|";
        this.days = new CsvReader(featuresDir + "day.csv", separatorRegex).readOnlyColumn().getTensor();
        this.xs = new CsvReader(obsDir + "features-combined.csv", separatorRegex).readAll().getTensor();
        this.ys = new CsvReader(featuresDir + "SALE-AMOUNT-log.csv", separatorRegex).readOnlyColumn().getTensor();
     
    }
    
    // accessors
    public Tensor getDays() {return days;}
    public Tensor getXs() {return xs;}
    public Tensor getYs() {return ys;}
}
