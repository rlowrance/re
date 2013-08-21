package com.roylowrance.thesis;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.HashMap;
import java.util.Scanner;

import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;
import com.roylowrance.util.Represents;

// provide access to the geocoding data
public class GeocodingOLD {

	private class GeocodingRecord {
		private float latitude;
		private float longitude;

		public GeocodingRecord(String latitude, String longitude) {
			if (!Represents.float_(latitude))
				throw new IllegalArgumentException("Latitude (" + latitude
						+ ") does not represent a float");
			if (!Represents.float_(longitude))
				throw new IllegalArgumentException("Longitude (" + longitude
						+ ") does not represent a float");
			this.latitude = Float.valueOf(latitude);
			this.longitude = Float.valueOf(longitude);
		}

		public String getLatitude() {
			return String.valueOf(latitude);
		}

		public String getLongitude() {
			return String.valueOf(longitude);
		}
	}

	private HashMap<Long, GeocodingRecord> recordFor = new HashMap<Long, GeocodingRecord>();

	public GeocodingOLD() throws FileNotFoundException {
		Log log = new Log("Geocoding.Geocoding", true);

		String projectDir = Dir.project();
		String fileDir = projectDir + "data/raw/";
		String filePath = fileDir + "geocoding.tsv";
		makeRecordsFor(filePath);
	}

	public String getLatitude(String apn) {
		GeocodingRecord gr = recordFor.get(apn);
		if (gr == null)
			return null;
		return gr.getLatitude();
	}

	public String getLongitude(String apn) {
		GeocodingRecord gr = recordFor.get(apn);
		if (gr == null)
			return null;
		return gr.getLongitude();
	}

	private void makeRecordsFor(String inPath) throws FileNotFoundException {
		Log log = new Log("Geocoding.makeRecordsFor", true);
		Scanner in = new Scanner(new File(inPath));
		String header = in.nextLine();
		final String separatorRegex = "\t";
		Extractor extractor = new Extractor(header, separatorRegex);

		// read each data line
		int countRead = 0;
		while (in.hasNext()) {
			String line = in.nextLine();
			countRead++;
			if (countRead % 100000 == 0)
				log.println("read geocoding record # " + countRead);
			String apn = extractor.extract(line, "G APN");
			if (apn.equals("9999999999")) {
				// the sentinel for the last record
				break;
			}
			makeRecordFor(apn, extractor, line);
		}
		in.close();
	}

	private void makeRecordFor(String apn, Extractor extractor, String line) {
		String latitudeString = extractor.extract(line, "G LATITUDE");
		String longitudeString = extractor.extract(line, "G LONGITUDE");
		try {
			recordFor.put(Long.valueOf(apn), new GeocodingRecord(
					latitudeString, longitudeString));
		} catch (IllegalArgumentException e) {
			System.out.println("Latitude or longitude not a float: "
					+ e.getMessage());
		}
	}
}
