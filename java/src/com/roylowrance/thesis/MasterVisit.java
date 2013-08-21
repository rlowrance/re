package com.roylowrance.thesis;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.LinkedList;

import com.roylowrance.util.Log;
import com.roylowrance.util.LineScanner;

// visit each parcel and related deeds in the master file
// There may be zero or more related deeds
public class MasterVisit {
	private LineScanner master = null;

	private String deedHeader = null;
	private String geocodingHeader = null;
	private String parcelHeader = null;

	public MasterVisit(String fileDataPath, String fileHeaderPath)
			throws FileNotFoundException, IOException {
		master = new LineScanner(fileDataPath);

		// read and save the headers
		LineScanner headers = new LineScanner(fileHeaderPath);
		deedHeader = headers.nextLine();
		parcelHeader = headers.nextLine();
		geocodingHeader = headers.nextLine();
		headers.close();
	}

	public void close() throws IOException {
		master.close();
	}

	public interface Visitor {
		public void start(String parcelHeader, String deedHeader,
				String geocodingHeader); // called before first visit

		public void visit(String parcelRecord, LinkedList<String> deedRecords,
				LinkedList<String> geocodingRecords);

		public void end(); // called after last visit
	}

	// visit each parcel and related deeds and geocodings in the master file
	public void visit(Visitor visitor, int throttle) throws IOException {
		Log log = new Log("VisitMaster.visit", false);
		visitor.start(deedHeader, parcelHeader, geocodingHeader);
		String parcelRecord = null;
		LinkedList<String> deedRecords = new LinkedList<String>();
		LinkedList<String> geocodingRecords = new LinkedList<String>();
		int recordsRead = 0;
		while (master.hasNextLine()) {
			String record = master.nextLine();
			String recordKind = record.substring(0, 1);
			recordsRead++;
			if (recordKind.equals("A")) {
				// parcel record found
				// flush any groups found
				if (parcelRecord != null) {
					log.println("about to visit, having read " + recordsRead
							+ " from master file");
					visitor.visit(parcelRecord, deedRecords, geocodingRecords);
				}
				parcelRecord = record;
				deedRecords = new LinkedList<String>();
				geocodingRecords = new LinkedList<String>();
				if (throttle != 0 && recordsRead >= throttle) {
					System.out
							.println("stopped reading master because hit throttle limit");
					break;
				}
			} else if (recordKind.equals("B")) {
				// deed record found
				deedRecords.add(record);
			} else if (recordKind.equals("C")) {
				// geocoding record found
				geocodingRecords.add(record);
			}
		}
		// flush any group found
		if (parcelRecord != null)
			visitor.visit(parcelRecord, deedRecords, geocodingRecords);
		visitor.end();
	}
}
