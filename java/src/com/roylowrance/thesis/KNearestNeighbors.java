package com.roylowrance.thesis;

// synopsis:
//
// making estimates:
// knn = KNearestNeighbors(xs, ys, pathToCacheDirectory, cacheFileNameOriginalSuffix);  // do not read the cache!
// double x = knn.estimate(k, query, xsRowIndexToOmit);  // estimate using xs, omitting perhaps one row
//
// maintaining the cache on disk:
// knn.writeCache();  // write cache to file name implied during construction
// knn.mergeCache(cacheFileNameSuffix); // merge in cache portion on disk, which may have a different suffix

// usage scenario
// 1. Create cache pieces
//    for pieceNumber = 1, 2, ...
//        knn = new KNearestNeighbors(xs, ys, cacheDir, "-piece-" + pieceNumber);
//        for queryIndex in pieceQueryIndices(pieceNumber)
//            knn.estimate(queryIndex);  // estimate each potential query in order to build up the cache
//        knn.cacheWrite(); // save the piece
//
// 2. Merge the cache pieces
//    knn = new KNearestNeighbors(xs, ys, cacheDir, "-merged");
//    for (pieceNumber : pieceNumbers)
//        knn.cacheMerge("-piece" + pieceNumber);
//    knn.writeCache();
//
// 3. Use the merged cache to find the best value for k
//
// 4. Use merged cache and the best value for k for estimating new query points
//    knn = new KNearestNeighbors(xs, ys, cacheDir, "-merged");
//    Map allFeatures = new HashMap<Tuple2,Tensor>();
//    <build allFeatures from APNs and xs>
//    for (apn, date : crossProduct(allAPNs, allDates)) {
//        query = makeQuery(xs, apn, date)
//        double estimate = knn.estimate(query, bestK);
//        write(apn, date, estimate)
//    }

import java.util.ArrayList;

import com.roylowrance.util.Tensor;

public class KNearestNeighbors {
	private Nearest256Ys nearest256Ys;
	
	// construct
	// always initialize the nearest-neighbors cache from the specified disk file unless path is NULL
	// if NULL, there is no cache
	public KNearestNeighbors(Tensor xs, Tensor ys, String cacheDirPath, String cacheFileNameOriginalSuffix) {
	    IAE.is2D(xs, "xs");
	    IAE.is1D(ys,  "ys");
	    //IAE.isNotNull(cacheDirPath, "pathToCacheDir");
	    IAE.isNotNull(cacheFileNameOriginalSuffix, "cacheFileNameOriginalSuffix");

	    this.nearest256Ys = new Nearest256Ys(xs, ys, cacheDirPath, cacheFileNameOriginalSuffix);
	}
	
	// merge a cache on disk with current cache
	// return number of records added from disk
	public int cacheMerge(String fileNameSuffix) {
	    return nearest256Ys.cacheMerge(fileNameSuffix);
	}
	
	// write the cache 
	// return number of data records written
	public int cacheWrite() {
	    return nearest256Ys.cacheWrite();
	}
	
	// estimate using constructed xs as the potential neighbors
	// if 0 <= xsRowIndexToOmit < xs.getSize(0) then don't use that row as a potential neighbor
	public double estimate(int k, Tensor query, int xsRowIndexToOmit) {
	    IAE.positive(k, "k");
	    IAE.lessEqual(k, Nearest256Ys.K_MAX, "k", "maximum pre-computed k value");
	    IAE.notNull(query, "query");
	    
	    ArrayList<Double> nearestYs = nearest256Ys.apply(query, xsRowIndexToOmit);
	    IAE.lessEqual(k, nearestYs.size(), "k", "number of pre-computed neighbors for this query");
	    
        double sumYs = 0;
        for (int i = 0; i < k; i++) {
            sumYs += nearestYs.get(i);
        }
        return sumYs / (double) k;
	}
	

}
