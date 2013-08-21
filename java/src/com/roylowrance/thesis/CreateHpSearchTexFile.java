package com.roylowrance.thesis;

public class CreateHpSearchTexFile {
    
    // writes the Tex file for a knn search
    // TODO: write me
    private static class KnnSearchTexFileWriter implements SearchResults.TestResultsVisitor {
        
        public KnnSearchTexFileWriter(String dataDir, String obs) {}

        @Override
        public void start() {
        }

        @Override
        public void visit(Tensor key, Tensor value) {
            // Report r = new Report(texFilePath);
            // boolean firstTime = true;
            // for (CacheKey cacheKey : results.keySet()) {
            // if (firstTime) {
            // r.println("% all hyperparameters apart from those in table");
            // r.println("% initial1DCutoff " + cacheKey.getInitial1DCutoff());
            // r.println("% numberTestSamples " +
            // cacheKey.getNumberTestSamples());
            // r.println("\\begin{tabular}{|l|l|l|}");
            // r.println("\\hline");
            // if (clp.algo.equals("knn")) {
            // r.println("%sigma " + cacheKey.getSigma());
            // r.println("K & RMSE & Fraction Within 10\\% \\\\ \\hline");
            // }
            // else {
            // r.println("% k " + cacheKey.getK());
            // r.println("\\sigma & RMSE % Fraction With 10\\% \\\\ \\hline");
            // }
            // firstTime = false;
            // }
            // CacheValue cacheValue = results.get(cacheKey);
            // final float rmse = (float) cacheValue.getRmse();
            // final float within10 = (float) cacheValue.getWithin10();
            //
            // if (clp.algo.equals("knn"))
            // r.println(cacheKey.getK() + "&" + rmse + "&" + within10 +
            // "\\\\ \\hline");
            // else
            // r.println(cacheKey.getSigma() + "&" + rmse + "&" + within10 +
            // "\\\\ \\hline");
            // }
            // r.println("\\end{tabular}");
            // r.close();
            
        }


    /**
     * @param args
     */
    public static void main(String[] args) {
        // TODO Auto-generated method stub

    }

}
