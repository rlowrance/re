package com.roylowrance.thesis.test;

import java.io.FileNotFoundException;
import java.io.IOException;

import static org.junit.Assert.*;

import org.junit.Test;

import com.roylowrance.thesis.Census;

public class CensusTest {

	@Test
	public void test() throws FileNotFoundException, IOException {
		Census cd = new Census();

		// first record
		String fipsCode = "6037";
		String censusTract = "101110";
		assertEquals(31.4, cd.getAvgCommuteMinutes(fipsCode, censusTract), 0.1); // not
																					// hand-calculated
		assertEquals(0.51, cd.getFractionOwnerOccupied(fipsCode, censusTract),
				0.01); // not hand-calculated
		assertEquals(41577.0,
				cd.getMedianHouseholdIncome(fipsCode, censusTract), 0.1); // value
																			// is
																			// in
																			// the
																			// file

		// last record
		fipsCode = "6037";
		censusTract = "930200";
		assertEquals(27.6, cd.getAvgCommuteMinutes(fipsCode, censusTract), 0.1); // not
																					// hand
																					// calculated
		assertEquals(0.66, cd.getFractionOwnerOccupied(fipsCode, censusTract),
				0.1); // not hand calculated
		assertEquals(39728.0,
				cd.getMedianHouseholdIncome(fipsCode, censusTract), 0.1); // value
																			// is
																			// in
																			// the
																			// file
	}

}
