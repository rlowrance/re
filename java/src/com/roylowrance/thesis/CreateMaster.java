package com.roylowrance.thesis;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;

import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;
import com.roylowrance.util.Report;
import com.roylowrance.util.Represents;
import com.roylowrance.util.LineScanner;

// create sorted files master.data master.headers master.errors from the files
// - deeds-relevant.*
// - parcels-relevant.*
// - geocodings-relevant.*
//
// master.data file layout
// A | <APN> | ...                   # parcel record
// B | <APN> | <date> | ...          # zero or more deeds records
// C | <APN> | ... # zero or one geocoding record
// 
// NOTE: allowing zero deeds records and zero geocodings records builds a complete set of parcels
public class CreateMaster {

	/**
	 * @param args
	 */
	public static void main(String[] args) throws FileNotFoundException,
			IOException {
		String projectDir = Dir.project();

		String generatedDir = projectDir + "data/generated-v4/";

		String deedsDataPath = generatedDir + "relevant-deeds-sorted.data";
		String deedsHeaderPath = generatedDir + "relevant-deeds.header";

		String geocodingsDataPath = generatedDir
				+ "relevant-geocodings-sorted.data";
		String geocodingsHeaderPath = generatedDir
				+ "relevant-geocodings.header";

		String parcelsDataPath = generatedDir + "relevant-parcels-sorted.data";
		String parcelsHeaderPath = generatedDir + "relevant-parcels.header";

		// just worry about the data for now
		// TODO: also write the master.headers file

		// create the extractors for deeds and parcels
		final String separatorRegex = "\\|";

		String deedsHeader = readHeader(deedsHeaderPath);
		Extractor deedsExtractor = new Extractor(deedsHeader, separatorRegex);
		LineScanner deedsLineScanner = new LineScanner(deedsDataPath);

		String geocodingsHeader = readHeader(geocodingsHeaderPath);
		Extractor geocodingsExtractor = new Extractor(geocodingsHeader,
				separatorRegex);
		LineScanner geocodingsLineScanner = new LineScanner(geocodingsDataPath);

		String parcelsHeader = readHeader(parcelsHeaderPath);
		Extractor parcelsExtractor = new Extractor(parcelsHeader,
				separatorRegex);
		LineScanner parcelsLineScanner = new LineScanner(parcelsDataPath);

		String masterDataPath = generatedDir + "master.data";
		String masterHeadersPath = generatedDir + "master.headers"; // there are
																	// 3
		String masterReportPath = generatedDir + "master.report";
		final String fieldSeparator = "|";
		writeMasterHeaders(masterHeadersPath, deedsHeader, geocodingsHeader,
				parcelsHeader, fieldSeparator);

		String errorsPath = generatedDir + "master.errors";

		processInput(deedsLineScanner, deedsExtractor, geocodingsLineScanner,
				geocodingsExtractor, parcelsLineScanner, parcelsExtractor,
				masterDataPath, errorsPath, fieldSeparator, masterReportPath);

		deedsLineScanner.close();
		geocodingsLineScanner.close();
		parcelsLineScanner.close();

		System.out.println("CreateMaster completed");
	}

	private static String readHeader(String filePath)
			throws FileNotFoundException, IOException {
		LineScanner LineScanner = new LineScanner(filePath);
		String header = LineScanner.nextLine();
		LineScanner.close();
		return header;
	}

	private static void writeMasterHeaders(String masterHeadersPath,
			String deedsHeader, String geocodingHeader, String parcelsHeader,
			String fieldSeparator) throws FileNotFoundException {
		PrintWriter masterHeaders = new PrintWriter(masterHeadersPath);
		masterHeaders.println("Master Kind" + fieldSeparator + parcelsHeader);
		masterHeaders.println("Master Kind" + fieldSeparator + deedsHeader);
		masterHeaders.println("Master Kind" + fieldSeparator + geocodingHeader);
		masterHeaders.close();
	}

	// match records in the two input files and append census and
	// ref:
	// http://cs.uni.edu/~east/teaching/cobol/topics/seq_update/algorithms.html
	private static void processInput(LineScanner deedsLineScanner,
			Extractor deedsExtractor, LineScanner geocodingLineScanner,
			Extractor geocodingExtractor, LineScanner parcelsLineScanner,
			Extractor parcelsExtractor, String masterDataPath,
			String errorsPath, String fieldSeparator, String masterReportPath)
			throws FileNotFoundException, IOException {
		final int throttle = 0; // set to zero to not throttle; > 0 to stop
								// after throttle records
		final boolean logging = false;
		Log log = new Log("CreateMaster.processInput", logging);
		final Report errors = new Report(errorsPath);

		PrintWriter master = new PrintWriter(masterDataPath);

		class FileState {
			private String apnFieldName = null;
			private Long apn = null;
			private String record = null;
			private LineScanner lineScanner = null;
			private Extractor extractor = null;
			private boolean firstRecord = true;
			// The APN field has 9 digits
			private final static long maxSentinel = 9999999999L + 1L; // Larger
																		// than
																		// the
																		// largest
																		// APN
																		// value
			private Long lastApn = null;

			// constructor
			public FileState(LineScanner lineScanner, Extractor extractor,
					String apnFieldName) {
				this.lineScanner = lineScanner;
				this.extractor = extractor;
				this.apnFieldName = apnFieldName;
			}

			// accessors
			public long getApn() {
				return apn;
			} // Must not be a Long or comparison in while loop will fail

			public String getRecord() {
				return record;
			}

			public int getNumberRecordsRead() {
				return lineScanner.getNumberLinesRead();
			}

			// public boolean hasNext() {return LineScanner.hasNext();}
			public boolean hasNext() {
				return lastApn != null && lastApn < maxSentinel;
			}

			public void nextRecord() throws IOException {
				Log log = new Log("CreateMaster.FileState.nextRecord", false);
				if (!firstRecord && record == null) {
					throw new RuntimeException(
							"attempt to read past final record");
				}
				firstRecord = false;
				if (!lineScanner.hasNextLine()) {
					record = null;
					apn = maxSentinel;
					lastApn = apn;
					return;
				}
				record = lineScanner.nextLine();
				log.println("record:" + record);
				// check that record has the expected number of fields
				// if not, reject it
				try {
					extractor.checkNumberOfFields(record);
				} catch (Extractor.Exception e) {
					System.out.println(e);
					nextRecord();
				}
				String apnString = extractor.extract(record, apnFieldName);
				// assure the APN is a Long, less than our max sentinel value,
				// and in exceed previous
				if (!Represents.long_(apnString)) {
					System.out.println("ANP <" + apnString
							+ "> is not a long integer");
					return;
					// the invalid value is in the file because the
					// CreateParcelsRelevant code fails to remove headers after
					// the first one
					// throw new RuntimeException("APN <" + apnString +
					// "> is not a long integer");
				}
				apn = Long.valueOf(apnString);
				if (apn > maxSentinel)
					throw new RuntimeException(
							"APN "
									+ apn
									+ " is a long integer, but exceeds the allowed max, which is 9,999,999,999");
				if (lastApn == null)
					lastApn = apn;
				else {
					if (lastApn > apn) {
						throw new RuntimeException(
								"File not sorted on APNs; lastApn:" + lastApn
										+ " apn:" + apn);
					}
					lastApn = apn;
				}
			}

			public void closeLineScanner() throws IOException {
				lineScanner.close();
			}
		}

		FileState deeds = new FileState(deedsLineScanner, deedsExtractor,
				"APN RECODED");
		FileState geocodings = new FileState(geocodingLineScanner,
				geocodingExtractor, "APN");
		FileState parcels = new FileState(parcelsLineScanner, parcelsExtractor,
				"APN RECODED");

		int parcelsWritten = 0;
		int deedsWritten = 0;
		int geocodingsWritten = 0;
		deeds.nextRecord();
		geocodings.nextRecord();
		parcels.nextRecord();
		int recordCount = 0;
		while (parcels.hasNext()) {
			if (logging)
				log.format("APNS deeds %,d parcels %,d geocoding %,d %n",
						deeds.getApn(), parcels.getApn(), geocodings.getApn());
			recordCount++;
			if (throttle != 0 && recordCount >= throttle) {
				System.out.println("hit throttle limit");
				break;
			}
			final int REPORTING_FREQUENCY = 100000;
			if (recordCount % REPORTING_FREQUENCY == 0)
				System.out
						.format("processing parcel record %,d%n", recordCount);
			// write the parcel
			master.println("A" + fieldSeparator + parcels.getRecord());
			parcelsWritten++;
			// write 0 or more deed records
			while (deeds.getApn() < parcels.getApn()) {
				deeds.nextRecord();
			}
			while (deeds.getApn() == parcels.getApn()) {
				log.println("deeds apn:" + deeds.getApn() + " parcels apn:"
						+ parcels.getApn());
				master.println("B" + fieldSeparator + deeds.getRecord());
				deedsWritten++;
				deeds.nextRecord();
			}
			// write 0 or more geocoding records
			while (geocodings.getApn() < parcels.getApn()) {
				geocodings.nextRecord();
			}
			while (geocodings.getApn() == parcels.getApn()) {
				master.println("C" + fieldSeparator + geocodings.getRecord());
				geocodingsWritten++;
				log.println("about to read next geocoding record");
				geocodings.nextRecord();
			}
			log.println("about to read next parcels record");
			parcels.nextRecord();
		}

		// at this point, all the parcels records have been read
		// there may be remaining records in the deeds and geocodings files
		// because this program checks record counts, we need to read all the
		// remaining records in these files
		int extraDeedsRecords = 0;
		while (deeds.hasNext()) {
			deeds.nextRecord();
			extraDeedsRecords++;
		}
		System.out.println("number of deeds records that were not examined:"
				+ extraDeedsRecords);

		int extraParcelsRecords = 0;
		while (parcels.hasNext()) {
			parcels.nextRecord();
			extraParcelsRecords++;
		}
		System.out.println("number of parcel records that were not examined:"
				+ extraParcelsRecords);

		int extraGeocodingsRecords = 0;
		while (geocodings.hasNext()) {
			geocodings.nextRecord();
			extraGeocodingsRecords++;
		}
		System.out
				.println("number of geocoding records that were not examined:"
						+ extraGeocodingsRecords);

		master.close();
		errors.close();

		// check record counts
		final int deedsExpectedRecords = 3014014;
		final int deedsActualRecords = deeds.getNumberRecordsRead();
		if (deedsExpectedRecords != deedsActualRecords)
			throw new RuntimeException("expecting " + deedsExpectedRecords
					+ " deeds records, but read " + deedsActualRecords);

		final int geocodingsExpectedRecords = 1820844;
		final int geocodingsActualRecords = geocodings.getNumberRecordsRead();
		if (geocodingsExpectedRecords != geocodingsActualRecords)
			throw new RuntimeException("expecting " + geocodingsExpectedRecords
					+ " geocoding records, but read " + geocodingsActualRecords);

		final int parcelsExpectedRecords = 1423616;
		final int parcelsActualRecords = parcels.getNumberRecordsRead();
		if (parcelsExpectedRecords != parcelsActualRecords)
			throw new RuntimeException("expecting " + parcelsExpectedRecords
					+ " parcels records, but read " + parcelsActualRecords);

		deeds.closeLineScanner();
		geocodings.closeLineScanner();
		parcels.closeLineScanner();

		// write the report
		PrintWriter masterReport = new PrintWriter(new File(masterReportPath));
		masterReport.format("Number of parcel records written: %,d%n",
				parcelsWritten);
		masterReport.format("Number of deeds records written: %,d%n",
				deedsWritten);
		masterReport.format("Number of geocodings records written: %,d%n",
				geocodingsWritten);
		masterReport.close();
	}
}
