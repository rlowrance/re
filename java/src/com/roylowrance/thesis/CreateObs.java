package com.roylowrance.thesis;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;

import java.util.LinkedList;
import java.util.Random;

import com.roylowrance.util.CommandLine;
import com.roylowrance.util.Counters;
import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;
import com.roylowrance.util.Report;

// main program to create
// Read master.data,  and create ObsXY/ObsXY.data
public class CreateObs {

	/**
	 * @param args
	 */
	public static void main(String[] args) throws FileNotFoundException,
			IOException {
		// parse --obs==<String> to determine which field definitions to use
		CommandLine cl = new CommandLine(args);
		String obs = cl.getOptionValue("--obs");

		String projectDir = Dir.project();
		String generatedDir = projectDir + "data/generated-v4/";

		String obsDir = generatedDir + "obs" + obs + "/";
		String obsDataPath = obsDir + "obs" + obs + ".data";
		String obsHeaderPath = obsDir + "obs" + obs + ".header";
		String obsReportPath = obsDir + "obs" + obs + ".report";

		String masterDataPath = generatedDir + "master.data";
		String masterHeadersPath = generatedDir + "master.headers";

		class MyVisitor implements MasterVisit.Visitor {
			private String obs;
			private Random random;
			private int parcelCount = 0;
			private int deedCount = 0;
			private int geocodingCount = 0;
			private int visitCount = 0;
			private Census census = null;
			private Extractor parcelExtractor = null;
			private Extractor deedExtractor = null;
			private Extractor geocodingExtractor = null;
			private String separatorRegex = null;
			private String fieldSeparator = null;
			private RecordSelector deedSelector = null;
			private RecordSelector parcelSelector = null;
			// private RecordSelector geocodingSelector = null; NOT NEEDED, AS
			// ALL THE FIELDS ARE KNOWN TO BE VALID
			private PrintWriter obsData = null;
			private Report obsReport = null;
			// Section declarations commented out, since these take memory
			// Instead, create individual report files
			private Report deedReport = null;
			private Report geocodingReport = null;
			private Report parcelReport = null;
			private Counters<String> reasonsParcelRejected;
			private Counters<String> reasonsDeedRejected;
			private int transactionCount;

			// constructor
			public MyVisitor(String obs, Census censusData,
					String separatorRegex, String fieldSeparator,
					String obsDataPath, String obsHeaderPath,
					String obsReportPath, Random random)
					throws FileNotFoundException {
				this.obs = obs;
				this.census = censusData;
				this.separatorRegex = separatorRegex;
				this.fieldSeparator = fieldSeparator;
				writeObsHeader(obsHeaderPath, fieldSeparator, obs);
				obsData = new PrintWriter(new File(obsDataPath));
				final boolean echoLines = false;
				obsReport = new Report(obsReportPath, echoLines);
				deedReport = new Report(obsReportPath + "-deeds", echoLines);
				geocodingReport = new Report(obsReportPath + "-geocoding",
						echoLines);
				parcelReport = new Report(obsReportPath + "-parcel", echoLines);

				this.random = random;
				reasonsParcelRejected = new Counters<String>();
				reasonsDeedRejected = new Counters<String>();
			}

			public void start(String parcelHeader, String deedHeader,
					String geocodingHeader) {
				final boolean logging = true;
				Log log = new Log("CreateObs.MyVisitor.start", logging);
				log.println("obs:" + obs);
				parcelExtractor = new Extractor(parcelHeader, separatorRegex);
				FieldDefinitions fdParcels = FieldDefinitions.parcels(obs);
				if (logging) {
					String s = "fdParcels field names:";
					for (String fieldName : fdParcels.getFieldNames())
						s += " " + fieldName;
					log.println(s);
				}
				parcelSelector = new RecordSelector(
						FieldDefinitions.parcels(obs), parcelExtractor);

				deedExtractor = new Extractor(deedHeader, separatorRegex);
				deedSelector = new RecordSelector(FieldDefinitions.deeds(obs),
						deedExtractor);

				geocodingExtractor = new Extractor(geocodingHeader,
						separatorRegex);
			}

			public void end() {
				obsData.close();
				obsReport.format("Obs=" + obs);
				obsReport.format(
						"Found %,d parcels %,d deeds, %,d geocodings%n",
						parcelCount, deedCount, geocodingCount);
				obsReport.format("Wrote %,d transactions", transactionCount);

				// print reasons why records were rejected

				obsReport.println(" ");
				obsReport.println("Reaons parcels were not selected");
				printReasonsRejected(obsReport, reasonsParcelRejected);
				// parcelSelector.report(obsReportSectionParcels);
				// obsReport.println(" ");
				// obsReport.println("Reasons parcel records were rejected:");
				// printReasonsRejected(obsReport, reasonsParcelRejected);

				obsReport.println(" ");
				obsReport.println("Reaons deeds were not selected");
				printReasonsRejected(obsReport, reasonsDeedRejected);
				// deedSelector.report(obsReportSectionDeeds);
				// obsReport.println(" ");
				// obsReport.println("Reasons deed records were rejected");
				// printReasonsRejected(obsReport, reasonsDeedRejected);

				obsReport.close(); // will print the sections, which contain the
									// details on the reasons parcels and deeds
									// were rejected
			}

			public void visit(String parcelRecord,
					LinkedList<String> deedRecords,
					LinkedList<String> geocodingRecords) {
				final boolean logging = false;
				Log log = new Log("CreateObs.visit", logging);
				log.println("parcelRecord:" + parcelRecord);
				log.println("deedRecords:" + deedRecords);
				log.println("geocodingRecords:" + geocodingRecords);

				parcelCount += 1;
				deedCount += deedRecords.size();
				geocodingCount += geocodingRecords.size();

				// check that the master file has at least 1 deed record

				if (deedRecords.size() == 0) {
					reasonsParcelRejected.increment("no deeds for the parcel");
					deedReport.println("parcel with no deeds:"
							+ head(parcelRecord));
					return;
				}

				// check that the master file has exactly 1 geocoding record

				if (geocodingRecords.size() == 0) {
					reasonsParcelRejected
							.increment("no geocoding for the parcel");
					geocodingReport.println("parcel with no geocoding:"
							+ head(parcelRecord));
					return;
				}

				if (geocodingRecords.size() > 1) {
					reasonsParcelRejected
							.increment("more than 1 geocoding for the parcel");
					geocodingReport
							.println("parcel with more than 1 geocoding:"
									+ head(parcelRecord));
				}

				// extract the parcel fields
				String[] selectedParcelFields = null;
				try {
					selectedParcelFields = parcelSelector.select(parcelRecord);
					log.println("selected Parcel Fields set");
					if (logging) {
						// print selectedParcelFields
						for (String field : selectedParcelFields)
							log.println("selectedParcelFields element:" + field);

					}
				} catch (RecordSelector.RecordSelectorException e) {
					reasonsParcelRejected.increment(e.getMessage());
					parcelReport.println("rejected parcel field:"
							+ e.getFieldName() + " field value:<"
							+ e.getFieldValue() + ">");
					return;
				}
				log.println("selected parcel fields:" + selectedParcelFields);

				// check that the parcel record contains the keys to the census
				// file

				String apn = parcelExtractor.extract(parcelRecord,
						"APN RECODED");
				if (apn == null) {
					reasonsParcelRejected.increment("apn missing");
					parcelReport.println("parcel with missing apn:"
							+ head(parcelRecord));
					return;
				}

				String fipsCode = parcelExtractor.extract(parcelRecord,
						"FIPS CODE");
				if (fipsCode == null) {
					reasonsParcelRejected.increment("fips code missing");
					parcelReport.println("parcel with missing fips code:"
							+ head(parcelRecord));
					return;
				}

				String censusTract = parcelExtractor.extract(parcelRecord,
						"CENSUS TRACT");
				if (censusTract == null) {
					reasonsParcelRejected.increment("census tract missing");
					parcelReport.println("parcel with missing census tract:"
							+ head(parcelRecord));
					return;
				}

				// pull in the census data
				log.println("fipsCode:" + fipsCode + " censusTrace:"
						+ censusTract);
				if (!fipsCode.substring(0, 1).equals("0"))
					throw new RuntimeException("fips code (" + fipsCode
							+ " ) doesn't begin with leading zero");
				final String fipsCodeModed = fipsCode.substring(1, 5); // drop
																		// leading
																		// 0
				Double avgCommute = census.getAvgCommuteMinutes(fipsCodeModed,
						censusTract);
				Double ownership = census.getFractionOwnerOccupied(
						fipsCodeModed, censusTract);
				Double income = census.getMedianHouseholdIncome(fipsCodeModed,
						censusTract);
				if (avgCommute == null || ownership == null || income == null) {
					reasonsParcelRejected
							.increment("fips code + census tract not found in census file");
					parcelReport
							.println("parcel with fips + census tract not in census file:"
									+ head(parcelRecord));
					return;
				}

				// pull in the geocoding
				String latitude = null;
				String longitude = null;
				for (String geocodingRecord : geocodingRecords) {
					// we know there is exactly one geocoding record
					// we know all the values are valid, so no need to run the
					// record selector
					latitude = geocodingExtractor.extract(geocodingRecord,
							"Latitude");
					longitude = geocodingExtractor.extract(geocodingRecord,
							"Longitude");
					if (latitude == null || longitude == null) {
						System.out.println("latitude:" + latitude);
						System.out.println("longitude:" + longitude);
						throw new RuntimeException(
								"latitude or longitude is null");
					}
				}

				for (String deedRecord : deedRecords) {
					String[] selectedDeedFields = null;
					try {
						selectedDeedFields = deedSelector.select(deedRecord);
						log.println("deed record was selected");
						if (logging)
							for (String field : selectedDeedFields)
								log.println("selected deed field:" + field);
					} catch (RecordSelector.RecordSelectorException e) {
						reasonsDeedRejected.increment(e.getMessage());
						deedReport.println("deed field " + e.getFieldName()
								+ " had invalid value <" + e.getFieldValue()
								+ ">");
						continue; // don't process this deed
					}
					String dateRecoded = deedExtractor.extract(deedRecord,
							"DATE RECODED");

					log.println("selectedParcelFields:" + selectedParcelFields);
					String transactionRecord = apn + fieldSeparator
							+ dateRecoded + fieldSeparator
							+ String.valueOf(random.nextFloat())
							+ fieldSeparator
							+ concatenate(selectedParcelFields, fieldSeparator)
							+ fieldSeparator
							+ concatenate(selectedDeedFields, fieldSeparator)
							+ fieldSeparator + avgCommute + fieldSeparator
							+ ownership + fieldSeparator + income
							+ fieldSeparator + latitude + fieldSeparator
							+ longitude;
					log.println("transactionRecord:" + transactionRecord);
					obsData.println(transactionRecord);
					transactionCount++;
				}
				visitCount++;
				if (visitCount % 1000 == 0) {
					System.out.println("visits: " + visitCount + " parcels:"
							+ parcelCount + " deeds:" + deedCount);
				}
			}
		}

		System.out.println("CreateObs started");
		MasterVisit visitMaster = new MasterVisit(masterDataPath,
				masterHeadersPath);
		Census census = new Census(); // the class knows where the census data
										// are in the file system
		String separatorRegex = "\\|";
		String fieldSeparator = "|";
		final long randomSeed = 27L;
		Random random = new Random(randomSeed);
		final int throttle = 0; // throttle = 3 picks up first transaction
								// record that is written
		visitMaster.visit(new MyVisitor(obs, census, separatorRegex,
				fieldSeparator, obsDataPath, obsHeaderPath, obsReportPath,
				random), throttle);
		System.out.println("CreateObs ended");
		System.out.print("command line: ");
		for (String arg : args)
			System.out.print(arg + " ");
		System.out.println("");
	}

	// intersperse the fieldSeparator in the elements of s, returning a single
	// string
	private static String concatenate(String[] s, String fieldSeparator) {
		Log log = new Log("CreateObs.concatentate", false);
		log.println("s:" + s);
		String answer = "";
		if (s == null)
			throw new RuntimeException("input s should not be null");
		for (int i = 0; i < s.length; i++) {
			String fieldValue = s[i];
			if (i == 0)
				answer += fieldValue;
			else
				answer += fieldSeparator + fieldValue;
		}
		return answer;
	}

	// return first few fields in a record
	private static String head(String s) {
		final int FIRST_FEW = 20;
		if (s.length() <= FIRST_FEW)
			return s;
		return s.substring(0, FIRST_FEW);
	}

	// write the obs header file
	// this must align with the definitions tables
	private static void writeObsHeader(String filePath, String fieldSeparator,
			String obs) throws FileNotFoundException {
		PrintWriter obsHeader = new PrintWriter(new File(filePath));
		// this code assumes that all obs sets include the census and geocoding
		// fields
		obsHeader.println("APN ID"
				+ fieldSeparator
				+ // avoid using same names as in parcels or deeds or census
				"DATE ID" + fieldSeparator + "random" + fieldSeparator
				+ fieldNames(FieldDefinitions.parcels(obs), fieldSeparator)
				+ fieldSeparator
				+ fieldNames(FieldDefinitions.deeds(obs), fieldSeparator)
				+ fieldSeparator + "census avg commute" + fieldSeparator
				+ "census ownership" + fieldSeparator + "census income"
				+ fieldSeparator + "latitude" + fieldSeparator + "longitude");
		obsHeader.close();
	}

	private static String fieldNames(FieldDefinitions definitions,
			String fieldSeparator) {
		String answer = "";
		int i = 0;
		for (String fieldName : definitions.getFieldNames()) {
			if (i == 0)
				answer += fieldName;
			else
				answer += fieldSeparator + fieldName;
			i++;
		}
		return answer;
	}

	private static void printReasonsRejected(Report report,
			Counters<String> reasons) {
		for (String reason : reasons.keySet()) {
			report.println(" " + reason + ": " + reasons.get(reason) + " times");
		}
	}
}