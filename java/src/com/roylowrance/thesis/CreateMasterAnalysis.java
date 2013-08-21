package com.roylowrance.thesis;

// provide info useful in designing models and observation sets

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;

import java.util.LinkedList;
import java.util.Map;

import java.util.TreeMap;

import com.roylowrance.util.Counters;
import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;

// create file master.analysis containing
// - distribution of deeds per parcel
// - distributions of values in selected deeds and parcels fields
public class CreateMasterAnalysis {

	/**
	 * @param args
	 */
	public static void main(String[] args) throws FileNotFoundException,
			IOException {
		String projectDir = Dir.project();
		String generatedDir = projectDir + "data/generated-v4/";

		String analysisPath = generatedDir + "master.analysis";

		String masterDataPath = generatedDir + "master.data";
		String masterHeadersPath = generatedDir + "master.headers";

		class MyRecordVisitor {
			private Extractor extractor;
			private PrintWriter analysisWriter;
			private FieldDefinitions fieldDefinitions;

			final class MyCounters extends TreeMap<String, Counters<String>> {
			};

			private MyCounters counters;

			// private TreeMap<String,Counters<String>> counters;

			public MyRecordVisitor(Extractor extractor,
					PrintWriter analysisWriter,
					FieldDefinitions fieldDefinitions) {
				this.extractor = extractor;
				this.analysisWriter = analysisWriter;
				this.fieldDefinitions = fieldDefinitions;
			}

			public void start() {
				// counters = new TreeMap<String,Counters<String>>();
				counters = new MyCounters();
			}

			public void end() {
				// write the results
				for (String fieldName : counters.keySet()) {
					analysisWriter.println(" ");
					analysisWriter.println("fieldName:" + fieldName);
					Counters<String> counter = counters.get(fieldName);

					// determine number of observations
					int numberObservations = 0;
					for (String value : counter.keySet())
						numberObservations += counter.get(value);

					// print analysis of each observed value
					double cumulativeCount = 0.0;
					analysisWriter.format("Number of observations = %d%n",
							counters.size());
					for (String value : counter.keySet()) {
						int count = counter.get(value);
						cumulativeCount += count;
						analysisWriter
								.format("Value %s occurs %,5d times percentile = %.4f%n",
										value, count, 1.0 * cumulativeCount
												/ numberObservations);
					}
					analysisWriter.println("above analysis is for fieldName:"
							+ fieldName);
				}
			}

			private void countEmptyAndValue(MyCounters counters,
					String fieldName, String fieldValue) {
				if (fieldValue.length() == 0)
					counters.get(fieldName).increment("<empty>");
				else
					counters.get(fieldName).increment(fieldValue);

			}

			private void visitDateFixed(MyCounters counters, String fieldName,
					String fieldValue) {
				if (fieldValue.length() == 0)
					counters.get(fieldName).increment("<empty>");
				else
					counters.get(fieldName).increment(
							fieldValue.substring(0, 4)); // year portion of date
			}

			private void visitDate(MyCounters counters, String fieldName,
					String fieldValue) {
				countEmptyAndValue(counters, fieldName, fieldValue);
			}

			private void visitLong(MyCounters counters, String fieldName,
					String fieldValue) {
				if (fieldValue.length() == 0)
					counters.get(fieldName).increment("<empty>");
				else if (fieldName.equals("ACRES")
						|| fieldName.equals("BEDROOMS")
						|| fieldName.equals("LIVING SQUARE FEET")
						|| fieldName.equals("PARKING SPACES")
						|| fieldName.equals("TOTAL BATHS CALCULATED")
						|| fieldName.equals("YEAR BUILT")
						|| fieldName.equals("LAND VALUE CALCULATED")
						|| fieldName.equals("IMPROVEMENT VALUE CALCULATED"))
					counters.get(fieldName).increment(fieldValue);
				else if (fieldName.equals("PRIOR SALES AMOUNT")) {
					if (Integer.valueOf(fieldValue) == 0)
						counters.get(fieldName).increment(fieldValue);
					else
						counters.get(fieldName).increment(
								"<some non-zero value>");
				} else
					counters.get(fieldName).increment("<some non-empty value>");
			}

			private void visitString(MyCounters counters, String fieldName,
					String fieldValue) {
				if (fieldValue.length() == 0)
					counters.get(fieldName).increment("<empty>");
				else
					counters.get(fieldName).increment(fieldValue);
			}

			private void visitYNSpaceEmpty(MyCounters counters,
					String fieldName, String fieldValue) {
				if (fieldValue.length() == 0)
					counters.get(fieldName).increment("<empty>");
				else if (fieldValue.startsWith(" "))
					counters.get(fieldName).increment("<" + fieldValue + ">");
				else
					counters.get(fieldName).increment("fieldValue");
			}

			public void visit(String record) {
				for (String fieldName : fieldDefinitions.getFieldNames()) {
					String fieldValue = extractor.extract(record, fieldName);
					String validDef = fieldDefinitions
							.getValidValuesDefinition(fieldName);
					if (!counters.containsKey(fieldName))
						counters.put(fieldName, new Counters<String>());
					if (validDef.equals("date fixed in [1979,2009]"))
						visitDateFixed(counters, fieldName, fieldValue);
					else if (validDef.equals("date"))
						visitDate(counters, fieldName, fieldValue);
					else if (validDef.startsWith("long"))
						visitLong(counters, fieldName, fieldValue);
					else if (validDef.startsWith("string"))
						visitString(counters, fieldName, fieldValue);
					else if (validDef.equals("Y N space empty"))
						visitYNSpaceEmpty(counters, fieldName, fieldValue);
					else {
						throw new IllegalArgumentException(
								"unexpected validDef=" + validDef);
					}
				}
			}
		}

		class MyMasterVisitor implements MasterVisit.Visitor {
			private String separatorRegex;
			private String fieldSeparator;
			private PrintWriter analysisWriter;
			private MyRecordVisitor parcelVisitor;
			private MyRecordVisitor deedVisitor;
			private int parcelCount;
			private int deedCount;
			private Counters<Integer> deedsPerParcel;

			private MyMasterVisitor(String separatorRegex,
					String fieldSeparator, String analysisPath)
					throws FileNotFoundException {
				this.separatorRegex = separatorRegex;
				this.fieldSeparator = fieldSeparator;
				this.analysisWriter = new PrintWriter(analysisPath);
			}

			public void start(String parcelHeader, String deedHeader,
					String geocodingHeader) {
				parcelVisitor = new MyRecordVisitor(new Extractor(parcelHeader,
						separatorRegex), analysisWriter,
						FieldDefinitions.parcels("all used"));
				parcelVisitor.start();

				deedVisitor = new MyRecordVisitor(new Extractor(deedHeader,
						separatorRegex), analysisWriter,
						FieldDefinitions.deeds("all used"));
				deedVisitor.start();

				deedsPerParcel = new Counters();

			}

			public void end() {
				analysisWriter.println(" ");
				analysisWriter.println("Read " + parcelCount + " parcels");
				analysisWriter.println("Read " + deedCount + " deeds");

				for (Map.Entry<Integer, Integer> entry : deedsPerParcel
						.entrySet()) {
					analysisWriter.format("%,d deeds occurred %,d times%n",
							entry.getKey(), entry.getValue());
				}

				analysisWriter.println(" ");
				analysisWriter.println("Results from parcel records");
				parcelVisitor.end();

				analysisWriter.println(" ");
				analysisWriter.println("Results from deed records");
				deedVisitor.end();
				analysisWriter.close();
			}

			public void visit(String parcelRecord,
					LinkedList<String> deedRecords,
					LinkedList<String> geocodingRecords) {
				Log log = new Log("CreateObs1.visit", true);
				parcelCount++;
				parcelVisitor.visit(parcelRecord);

				int deedsForThisParcel = 0;
				for (String deedRecord : deedRecords) {
					deedsForThisParcel++;
					deedCount++;
					deedVisitor.visit(deedRecord);
				}

				deedsPerParcel.increment(deedsForThisParcel);
				if (parcelCount % 100000 == 0)
					System.out.format("read parcel %,d%n", parcelCount);
			}
		}

		final String separatorRegex = "\\|";
		final String fieldSeparator = "|";
		MyMasterVisitor mvm = new MyMasterVisitor(separatorRegex,
				fieldSeparator, analysisPath);
		MasterVisit vm = new MasterVisit(masterDataPath, masterHeadersPath);
		final int throttle = 0;
		vm.visit(mvm, throttle);
		System.out.println("CreateMasterAnalysis completed");
	}

}