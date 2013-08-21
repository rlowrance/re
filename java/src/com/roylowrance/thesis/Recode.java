package com.roylowrance.thesis;

import com.roylowrance.util.Log;
import com.roylowrance.util.Represents;

// recode various fields in the input file to supposedly better values
public class Recode {

	// return best APN string or null if neither is valid
	public static String apn(String apnFormatted, String apnUnformatted) {
		final boolean logging = false;
		Log log = new Log("Recode.apn", logging);
		if (isValidApn(apnUnformatted)) {
			log.println("apn unformatted is valid apn");
			return prependZeroes(apnUnformatted);
		}

		String apnUnformattedCleaned = cleanApn(apnUnformatted);
		if (isValidApn(apnUnformattedCleaned)) {
			log.println("apn unformatted cleaned is valid apn");
			return prependZeroes(apnUnformattedCleaned);
		}

		String apnFormattedCleaned = cleanApn(apnFormatted);
		if (isValidApn(apnFormattedCleaned)) {
			log.println("apn formatted clean is valid apn");
			return prependZeroes(apnFormattedCleaned);
		}

		return null;
	}

	private static String prependZeroes(String s) {
		if (s.length() == 10)
			return s;
		if (s.length() < 10)
			return prependZeroes("0" + s);
		else
			throw new RuntimeException("s.length:" + s.length());
	}

	private static boolean isValidApn(String s) {
		// MaxInt for 32 bits is 2,147,483,647, which is 9 digits
		// the APN is 10 digits, so a long is needed to hold it
		return Represents.long_(s) && s.length() <= 10;
	}

	private static String cleanApn(String s) {
		return s.replaceAll("\\-", "").replaceAll(" ", "").replaceAll("_", "");
	}

	// return best data string; remove any hyphens, replace training 00 with 01
	public static String date(String recordingDate, String saleDate) {
		if (Represents.date(saleDate))
			return cleanDate(saleDate);

		if (Represents.date(recordingDate))
			return cleanDate(recordingDate);

		return null;
	}

	private static String cleanDate(String s) {
		return s.replaceAll("\\-", "");
	}

}
