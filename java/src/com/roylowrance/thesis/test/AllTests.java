package com.roylowrance.thesis.test;

import org.junit.runner.RunWith;
import org.junit.runners.Suite;
import org.junit.runners.Suite.SuiteClasses;

@RunWith(Suite.class)
@SuiteClasses({
		CensusTest.class,
		CreateObs2RFeaturesTest.class, // this test takes a long time
		//CreateObs2RKnnSearchRandomTest.class, CreateRelevantDeedsTest.class,
		DistanceEuclideanTest.class, FileLineVisitorTest.class, HpTest.class,
		KernelGaussianTest.class, KernelWeightedAverageTest.class,
		KNearestNeighborsTest.class,
		// MasterVisitTest.class, not coded as a Junit test, so must be run by
		// hand
		ObsVisitTest.class, RecodeTest.class, })
public class AllTests {

}
