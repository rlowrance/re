package com.roylowrance.thesis;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.HashMap;

import com.roylowrance.util.Extractor;

// provide access to data from US Census bureau
public class Census {

	private class CensusRecord {
		private double avgCommuteMinutes;
		private double fractionOwnerOccupied;
		private double medianHouseholdIncome;

		public CensusRecord(double avgCommuteMinutes,
				double fractionOwnerOccupied, double medianHouseholdIncome) {
			this.avgCommuteMinutes = avgCommuteMinutes;
			this.fractionOwnerOccupied = fractionOwnerOccupied;
			this.medianHouseholdIncome = medianHouseholdIncome;
		}

		public double getAvgCommuteMinutes() {
			return this.avgCommuteMinutes;
		}

		public double getMedianHouseholdIncome() {
			return this.medianHouseholdIncome;
		}

		public double getFractionOwnerOccupied() {
			return this.fractionOwnerOccupied;
		}
	}

	private HashMap<String, CensusRecord> recordFor = new HashMap<String, CensusRecord>();

	public Census() throws FileNotFoundException, IOException {
		String projectDir = Dir.project();
		String fileDir = projectDir + "data/raw/neighborhood-data/";
		String filePath = fileDir + "census.csv";
		makeRecordFor(filePath);
	}

	public Double getAvgCommuteMinutes(String fipsCode, String censusTract) {
		CensusRecord cr = recordFor.get(fipsCode + censusTract);
		if (cr == null)
			return null;
		return cr.getAvgCommuteMinutes();
	}

	public Double getFractionOwnerOccupied(String fipsCode, String censusTract) {
		CensusRecord cr = recordFor.get(fipsCode + censusTract);
		if (cr == null)
			return null;
		return cr.getFractionOwnerOccupied();
	}

	public Double getMedianHouseholdIncome(String fipsCode, String censusTract) {
		CensusRecord cr = recordFor.get(fipsCode + censusTract);
		if (cr == null)
			return null;
		return cr.getMedianHouseholdIncome();
	}

	class MyVisitor implements FileLineVisitor.Visitor {
		int inputLineNumber;
		Extractor extractor;
		int dataRecordsUsed;

		public MyVisitor() {
			inputLineNumber = 0;
			dataRecordsUsed = 0;
		}

		public void start() {
		}

		public void visit(String line) {
			inputLineNumber++;
			if (inputLineNumber == 1) {
				// ignore the first line, which is not the header!
				return;
			}
			if (inputLineNumber == 2) {
				// the second line is the header
				final String separator = "\t";
				extractor = new Extractor(line, separator);
				return;
			}
			// process a data line
			String fipsPlusCensusTract = extractor.extract(line,
					"\"Geography Identifier2\""); // fipsCode + censusTract
			Double avgCommuteMinutes = makeAvgCommuteMinutes(line, extractor);
			if (avgCommuteMinutes == null)
				return;
			int medianHouseholdIncome = Integer.valueOf(extractor.extract(line,
					"\"Households: Median household income in 1999\""));
			int housingUnits = Integer.valueOf(extractor.extract(line,
					"\"Occupied housing units: Total\""));
			int ownerOccupied = Integer.valueOf(extractor.extract(line,
					"\"Occupied housing units: Owner occupied\""));
			if (housingUnits == 0)
				return;
			double fractionOwnerOccupied = 1.0 * ownerOccupied / housingUnits;
			recordFor.put(fipsPlusCensusTract, new CensusRecord(
					avgCommuteMinutes, fractionOwnerOccupied,
					medianHouseholdIncome));
			dataRecordsUsed++;
		}

		public void end() {
		}
	}

	private void makeRecordFor(String inPath) throws FileNotFoundException,
			IOException {
		MyVisitor mv = new MyVisitor();
		FileLineVisitor flv = new FileLineVisitor(inPath);
		final int throttle = 0; // read all lines
		flv.visit(mv, throttle);
		flv.close();

		// Scanner in = new Scanner(new File(inPath));
		// String header = in.nextLine();
		// final String separator = "\t";
		// // the second line describes the fields
		// // verify that we use the correct field names
		// String description = in.nextLine();
		// Extractor extractor = new Extractor(description, separator);
		//
		// // the remaining lines have actual data
		// while (in.hasNext()) {
		// String line = in.nextLine();
		// String fipsPlusCensusTract = extractor.extract(line,
		// "\"Geography Identifier2\""); // fipsCode + censusTract
		// Double avgCommuteMinutes = makeAvgCommuteMinutes(line, extractor);
		// if (avgCommuteMinutes == null)
		// continue;
		// int medianHouseholdIncome = Integer.valueOf(extractor.extract(line,
		// "\"Households: Median household income in 1999\""));
		// int housingUnits = Integer.valueOf(extractor.extract(line,
		// "\"Occupied housing units: Total\""));
		// int ownerOccupied = Integer.valueOf(extractor.extract(line,
		// "\"Occupied housing units: Owner occupied\""));
		// if (housingUnits == 0)
		// continue;
		// double fractionOwnerOccupied = 1.0 * ownerOccupied / housingUnits;
		// recordFor.put(fipsPlusCensusTract, new
		// CensusRecord(avgCommuteMinutes,
		// fractionOwnerOccupied,
		// medianHouseholdIncome));
		//
		// }
		// in.close();
	}

	private Double makeAvgCommuteMinutes(final String line,
			final Extractor extractor) {

		class Tabulate {
			private double totalCommuters = 0;
			private double totalMinutes = 0;

			public Tabulate() {
			}

			public void tabulate(String fieldName, double avgCommuteTime) {
				String valueAsString = extractor.extract(line, fieldName);
				int commuters = Integer.valueOf(valueAsString);
				totalCommuters += commuters;
				totalMinutes += commuters * avgCommuteTime;
			}

			public Double avgCommute() {
				if (totalCommuters == 0)
					return null;
				return totalMinutes / totalCommuters;
			}
		}

		Tabulate t = new Tabulate();

		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; Less than 5 minutes\"",
				3.0); // less than 5
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 5 to 9 minutes\"",
				7.0); // 5 to 9
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 10 to 14 minutes\"",
				12.0); // 10 to 14
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 15 to 19 minutes\"",
				17.0); // 15 to 10
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 20 to 24 minutes\"",
				22.0); // 20 to 24
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 25 to 29 minutes\"",
				27.0); // 25 to 29
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 30 to 34 minutes\"",
				32.0); // 30 to 34
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 35 to 39 minutes\"",
				37.0); // 35 to 39
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 40 to 44 minutes\"",
				42.0); // 40 to 44
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 45 to 59 minutes\"",
				52.0); // 45 to 49
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 60 to 89 minutes\"",
				74.5); // 50 to 54
		t.tabulate(
				"\"Workers 16 years and over: Did not work at home; Travel time to work; 90 or more minutes\"",
				120.0);// 90+
		return t.avgCommute();
	}

}
