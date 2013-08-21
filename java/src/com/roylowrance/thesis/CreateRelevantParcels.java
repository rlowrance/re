package com.roylowrance.thesis;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;

import com.roylowrance.util.Extractor;
import com.roylowrance.util.Report;

// create file parcels-relevant.* in generated-v4 
// Read data/raw/taxroll-all-columns/*
// Write data/generated-v4/relevant-parcels.* with APN RECODED field pre-pended
//
// The relevant parcels are those that
// - are in a record with the correct number of fields
// - have a valid formatted or unformatted APN
// - have UNIVERSAL LAND USE CODE as 163, meaning SFR
public class CreateRelevantParcels {

	public static void main(String args[]) throws FileNotFoundException,
			IOException {
		String projectDir = Dir.project();
		String inputDir = projectDir + "data/raw/taxroll-all-columns/";
		String outputDir = projectDir + "data/generated-v4/";
		String baseName = "relevant-parcels";
		String dataPath = outputDir + baseName + ".data";
		String headerPath = outputDir + baseName + ".header";
		String errorPath = outputDir + baseName + ".errors";
		PrintWriter dataWriter = new PrintWriter(dataPath);
		PrintWriter headerWriter = new PrintWriter(headerPath);
		Report errorReport = new Report(errorPath);

		// the input is partitioned into 8 csv files
		// The headers in the 8 input files do not match character for character
		// but the fields line up nonetheless.
		String firstInputHeader = null;
		// the values below came from running >wc <FILE> on the input files
		int[] expectedNumberLines = { 306603, 313723, 305651, 307619, 303696,
				302785, 303177, 233441 };
		for (int suffix = 1; suffix <= 8; suffix++) {
			String inputPath = inputDir + "CAC06037F" + suffix + ".txt";
			String header = processInputFile(inputPath, dataWriter,
					errorReport, firstInputHeader,
					expectedNumberLines[suffix - 1]);
			if (firstInputHeader == null) {
				firstInputHeader = new String(header);
				headerWriter.println("APN RECODED|" + header);
			} else if (!firstInputHeader.equals(header)) {
				inconsistentSubsequentHeader(firstInputHeader, header, suffix);
			}
		}

		dataWriter.close();
		headerWriter.close();
		errorReport.close();

		System.out.println("CreateParcelsRelevant completed");
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
	// add field: APN RECODED
	// return the file header
	private static String processInputFile(final String inputPath,
			PrintWriter outputWriter, Report errorReport,
			final String firstInputHeader, int expectedNumberRecords)
			throws FileNotFoundException, IOException {
		System.out.println("processing input file:" + inputPath);

		final String separatorRegex = "\\|";
		final String separator = "|"; // must match separatorRegex
		MyVisitor myVisitor = new MyVisitor(separatorRegex, separator,
				outputWriter, errorReport);
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

		// Scanner inputScanner = new Scanner(new File(inputPath));
		// Extractor extractor = null;
		// String firstInputLine = null;
		// int inputLineNumber = 0;
		// while (inputScanner.hasNext()) {
		// // process header
		// String rawInputLine = inputScanner.nextLine();
		// String inputLine = rawInputLine.replace('\t', '|'); // convert tabs
		// to |s
		// inputLineNumber++;
		// final int REPORTING_FREQUENCY = 100000;
		// if (inputLineNumber % REPORTING_FREQUENCY == 0)
		// System.out.println("processing line " + inputLineNumber);
		// if (firstInputLine == null) {
		// firstInputLine = inputLine;
		// final String separatorRegex = "\\|";
		// extractor = new Extractor(inputLine, separatorRegex);
		// }
		// else {
		// final String separator = "|"; // MUST MATCH separtorRegex
		// processDataLine(extractor, inputLine, outputWriter, separator,
		// errorReport);
		// }
		// }
		// inputScanner.close();
		// return firstInputLine;
	}

	// if the data line is relevant, write it to the outputWriter
	// prepend recoded apns
	private static void processDataLine(Extractor extractor, String dataLine,
			PrintWriter outputWriter, String separator, Report errorReport) {
		String apnUnformatted = null;
		String apnFormatted = null;
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
		String apnRecoded = Recode.apn(apnFormatted, apnUnformatted);
		if (apnRecoded == null) {
			errorReport.println(" ");
			errorReport.println("deed without a valid APN");
			errorReport.println("apnFormatted:" + apnFormatted);
			errorReport.println("apnUnformatted:" + apnUnformatted);
			errorReport.println("deed:" + dataLine);
			return;
		}

		// test if record is relevant
		String uluc = extractor.extract(dataLine, "UNIVERSAL LAND USE CODE");
		if (!uluc.equals("163"))
			return;

		// record is relevant
		String prependedRecord = apnRecoded + separator + dataLine;
		outputWriter.println(prependedRecord);
	}

}
