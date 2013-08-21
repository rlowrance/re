package com.roylowrance.thesis;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;

import java.util.NoSuchElementException;

import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;
import com.roylowrance.util.Report;
import com.roylowrance.util.Represents;

// create file deeds-relevant.* in generated-v4 
// Read data/raw/deeds-all-columns/*
// Write data/generated-v4/relevant-deeds.* with added APN RECODED and DATE RECODED fields
// The relevant deeds are those that
// - have every field
// - have either an APN UNFORMATTED or an APN FORMATTED that is a long integer
// - have either a SALE DATE or RECORDING DATE that is of the form YYYYMMDD or YYYYMM00 (recoded as YYYYMM01)
// - have DOCUMENT TYPE CODE == "G" or "T", meaning Grant deed (sale) or Trust (mortgage)
// - have MULTI APN COUNT == 0 or 1, meaning one parcel or not coded
// - have MULTI APN FLAG CODE missing or 0, meaning not flagged as a transaction with more than one APN
// - have PRI CAT CODE as A, meaning an arm-length transaction
// - have a SALE AMOUNT > 0
// - have a SALE CODE that does not indicate a lease (L) or partial sale (P)
// - have a TRANSACTION TYPE CODE of 1 (resale) or 3 (subdivision/new construction)
public class CreateRelevantDeeds {

	public static void main(String args[]) throws FileNotFoundException,
			IOException {
		final boolean debugging = true;
		String projectDir = Dir.project();
		String inputDir = projectDir + "data/raw/deeds-all-columns/";
		String outputDir = projectDir + "data/generated-v4/";
		String baseName = "relevant-deeds";
		String outputDataPath = outputDir + baseName + ".data";
		String outputHeaderPath = outputDir + baseName + ".header";
		String errorPath = outputDir + baseName + ".errors";
		PrintWriter dataWriter = new PrintWriter(outputDataPath);
		PrintWriter headerWriter = new PrintWriter(outputHeaderPath);
		final boolean echoErrors = !debugging;
		Report errorReport = new Report(errorPath, echoErrors);

		// the input is partitioned into 8 csv files

		String firstInputHeader = null;
		// the values below came from running >wc <FILE> on the input files
		int[] expectedNumberLines = { 2204005, 2027842, 1819211, 1845017,
				2025306, 1962187, 1912841, 2269343, 16065752 };
		for (int suffix = 1; suffix <= 8; suffix++) {
			String inputPath = inputDir + "CAC06037F" + suffix + ".txt";
			String header = processInputFile(inputPath, dataWriter,
					errorReport, expectedNumberLines[suffix - 1]);
			if (firstInputHeader == null) {
				firstInputHeader = new String(header);
				headerWriter.println("APN RECODED|DATE RECODED|" + header);
			} else if (!firstInputHeader.equals(header)) {
				inconsistentSubsequentHeader(firstInputHeader, header, suffix); // throws
			}
		}
		dataWriter.close();
		headerWriter.close();
		errorReport.close();
		System.out.println("CreateRelevantDeeds completed");
	}

	private static void inconsistentSubsequentHeader(String firstInputHeader,
			String nextHeader, int suffix) {
		String[] headers = nextHeader.split("\\|");
		String[] firsts = firstInputHeader.split("\\|");
		System.out.println(" ");
		System.out.println("Found header not equal to first header");
		System.out.println("headers.length:" + headers.length
				+ " firsts.length:" + firsts.length);
		System.out.println("Fields that are not equal:");
		for (int i = 0; i < headers.length; ++i) {
			// if (headers[i].equals(firsts[i]))
			// continue;
			System.out.println("header/first:" + headers[i] + "/" + firsts[i]);
		}
		System.out.println("suffix:" + suffix);
		throw new RuntimeException("headers not same in each input file");
	}

	static class MyVisitor implements FileLineVisitor.Visitor {
		private int numberRecordsRead;
		private String separatorRegex;
		private Extractor extractor;
		private PrintWriter dataWriter;
		private String separator;
		private Report errorReport;
		private String firstInputLine;

		// constructor
		public MyVisitor(String separatorRegex, String separator,
				PrintWriter dataWriter, Report errorReport) {
			numberRecordsRead = 0;
			this.separatorRegex = separatorRegex;
			this.separator = separator;
			this.dataWriter = dataWriter;
			this.errorReport = errorReport;
		}

		public void start() {
		}

		public void visit(String rawInputLine) {
			numberRecordsRead += 1;
			String inputLine = rawInputLine.replace('\t', '|'); // convert tabs
																// to |s

			if (numberRecordsRead == 1) {
				extractor = new Extractor(inputLine, separatorRegex);
				firstInputLine = new String(inputLine);
			} else {
				processDataLine(extractor, inputLine, dataWriter, separator,
						errorReport);
			}
		}

		public void end() {
		}

		public String getFirstInputLine() {
			return firstInputLine;
		}

		public int getNumberRecordsRead() {
			return numberRecordsRead;
		}
	}

	// process a CAC06037F<suffix>.txt file, writing relevant deeds to
	// outputWriter
	// add two fields: APN RECODED, SALE DATE RECODED
	// return the file header
	private static String processInputFile(final String inputPath,
			PrintWriter dataWriter, Report errorReport,
			int expectedNumberRecords) throws FileNotFoundException,
			IOException {
		System.out.println("processing input file:" + inputPath);

		final String separatorRegex = "\\|";
		final String separator = "|"; // must match separatorRegex
		MyVisitor myVisitor = new MyVisitor(separatorRegex, separator,
				dataWriter, errorReport);
		FileLineVisitor flv = new FileLineVisitor(inputPath);
		final int throttle = 0; // read all the input
		flv.visit(myVisitor, throttle);
		flv.close();

		final int actualNumberRecords = myVisitor.getNumberRecordsRead();
		if (actualNumberRecords != expectedNumberRecords)
			throw new ExceptionOLD("expected " + expectedNumberRecords
					+ " records but found " + actualNumberRecords
					+ " records in input file\n" + inputPath);
		return myVisitor.getFirstInputLine(); // return the header
	}

	// if the data line is relevant, write it to the outputWriter
	// prepend recoded apns and sale dates
	private static void processDataLine(Extractor extractor, String dataLine,
			PrintWriter dataWriter, String separator, Report errorReport) {
		final boolean debugging = true;
		final boolean logging = false;
		Log log = new Log("CreateRelevantDeeds.processDataLine", logging);
		String apnUnformatted = null;
		String apnFormatted = null;

		// check number of fields and extract the two APNs
		try {
			extractor.checkNumberOfFields(dataLine);
			apnUnformatted = extractor.extract(dataLine, "APN UNFORMATTED");
			apnFormatted = extractor.extract(dataLine, "APN FORMATTED");
		} catch (Extractor.Exception e) {
			// the input record had the wrong number of field
			errorReport.println(" ");
			errorReport.println("wrong number of fields in input record");
			errorReport.println(e.getMessage());
			errorReport.println("dataLine:" + dataLine);
			return;
		}
		
		if (debugging) {
			String priorSalesAmount = extractor.extract(dataLine, "PRIOR SALES AMOUNT");
			//System.out.println("PRIOR SALES AMOUNT =<" + priorSalesAmount + ">");
			if (!priorSalesAmount.isEmpty())
				throw new RuntimeException("PRIOR SALES AMOUNT not empty");
		}
		// debugging
		if (false && apnUnformatted.equals("8106020009")) {
			System.out.println("found it");
		}
		String apnRecoded = Recode.apn(apnFormatted, apnUnformatted);
		if (apnRecoded == null) {
			errorReport.println(" ");
			errorReport.println("deed without a valid APN");
			errorReport.println("APN UNFORMATTED:<" + apnUnformatted + ">");
			errorReport.println("APN FORMATTED:<" + apnFormatted + ">");
			errorReport.println("APN recoded:<" + apnRecoded + ">");
			errorReport.println("deed:" + dataLine);
			return;
		}

		try {
			String saleDate = cleanDate(extractor
					.extract(dataLine, "SALE DATE"));
			String recordingDate = cleanDate(extractor.extract(dataLine,
					"RECORDING DATE"));
			if (debugging) {
				if (saleDate.equals("20041228")
						|| recordingDate.equals("20041218"))
					log.println("saleDate:" + saleDate + " recordingDate:"
							+ recordingDate + "apnRecoded:" + apnRecoded);
				if (false && saleDate.startsWith("200"))
					log.println("saleDate in 200x:" + saleDate);
			}
			String dateRecoded = Recode.date(recordingDate, saleDate);

			if (dateRecoded == null) {
				errorReport.println(" ");
				errorReport.println("deed without a valid date");
				errorReport.println("date recoded:<" + dateRecoded + ">");
				errorReport.println("deed:" + dataLine);
				return;
			}

			if (debugging) {
				if (dateRecoded.startsWith("2009")) {
					log.println("dateRecord in 200x:" + dateRecoded);
				}
			}

			if (recordIsRelevant(dataLine, extractor)) {
				String prependedRecord = apnRecoded + separator + dateRecoded
						+ separator + dataLine;
				dataWriter.println(prependedRecord);
				if (logging && !debugging)
					log.println("line written:" + prependedRecord);
			}
			return;

		} catch (NoSuchElementException e) {
			// this happens if the request field is beyond the end of the record
			errorReport.println(" ");
			errorReport
					.println("Input line malformed: too few fields to contain SALE DATE or RECORDING DATE");
			errorReport.println("input line: " + dataLine);
			return; // ignore corrupted input record
		}
	}

	private static boolean recordIsRelevant(String dataLine, Extractor extractor) {
		final boolean logging = false;
		Log log = new Log("recordIsRelevant");
		if (logging)
			log.println("dataLine:" + dataLine);

		// a Grant deed or Trust deed (trust deeds are used with mortgages)
		String dtc = extractor.extract(dataLine, "DOCUMENT TYPE CODE"); // DEEDC
		if (logging)
			log.println("dtc:" + dtc);
		if (!(dtc.equals("G") || dtc.equals("T")))
			return false;

		// Number of parcels sold is 1 or 0 (only 1 record has a 0 value)
		String mac = extractor.extract(dataLine, "MULTI APN COUNT");
		if (logging)
			log.println("mac:" + mac);
		if (!Represents.int_(mac))
			return false;
		int value = Integer.valueOf(mac);
		if (!(value == 0 || value == 1))
			return false;

		// Any code explains the kind of multiple apn sale
		// The only relevant value is hence an empty string
		String mafc = extractor.extract(dataLine, "MULTI APN FLAG CODE"); // SLMLT
		if (logging)
			log.println("mafc:" + mafc);
		if (mafc.length() > 0)
			return false;

		// Keep A (Arms Length Transaction) only
		// Reject
		// - non arms-length
		// - non purchase
		// - timeshare
		// - notice of default
		// - assignment
		// - release
		String pcc = extractor.extract(dataLine, "PRI CAT CODE"); // PRICATCODE
		if (logging)
			log.println("pcc:" + pcc);
		if (!pcc.equals("A"))
			return false;

		// supplied and not zero
		String sa = extractor.extract(dataLine, "SALE AMOUNT");
		if (logging)
			log.println("sa:" + sa);
		if (sa.length() == 0)
			return false;
		if (!Represents.int_(sa))
			return false;
		if (Integer.valueOf(sa) == 0)
			return false;

		// Reject L (partial) P (partial) L (lease)
		String sc = extractor.extract(dataLine, "SALE CODE"); // SCODE
		if (logging)
			log.println("sc:" + sc);
		if (sc.equals("L") || sc.equals("P"))
			return false;

		// Keep 001 (Resale) 003 (subdivision/new construction)
		// Reject refinance, timeshar, construction loan, seller carryback,
		// nominal
		String ttc = extractor.extract(dataLine, "TRANSACTION TYPE CODE"); // TRNTP
		if (logging)
			log.println("ttc:" + ttc);
		if (!(ttc.equals("1") || ttc.equals("001") || ttc.equals("3") || ttc
				.equals("003")))
			return false;

		return true;
	}

	// replace any final 00 with 01
	public static String cleanDate(String s) {
		if (s.endsWith("00"))
			return s.substring(0, s.length() - 2) + "01";
		else
			return s;
	}

}
