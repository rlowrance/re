package com.roylowrance.thesis;

import java.util.HashMap;
import java.util.Set;

// define field names, valid values, and how to recode value in file
public class FieldDefinitions {
	private HashMap<String, String> validValuesDescription;
	private HashMap<String, String> recodeDescription;

	// // MAYBE: implement this; now it is not used
	// // is the value in the file both present and valid?
	// public enum ValidCriterion {
	// LONG_IN_1000_10MILLION, LONG_OR_EMPTY, NOT_EMPTY_DATE, NOT_EMPTY_LONG,
	// NOT_EMPTY_STRING, Y_N_OR_EMPTY
	// }
	//
	// public boolean isValid(ValidCriterion criterion, String fieldValue) {
	// switch (criterion) {
	// case LONG_IN_1000_10MILLION:
	// if (!Represents.long_(fieldValue))
	// return false;
	// final long value = Long.valueOf(fieldValue);
	// return 1000 <= value && value <= 10000000;
	// case LONG_OR_EMPTY:
	// return fieldValue.length() == 0 || Represents.long_(fieldValue);
	// case NOT_EMPTY_DATE:
	// return fieldValue.length() > 0 && Represents.date(fieldValue);
	// case NOT_EMPTY_LONG:
	// return Represents.long_(fieldValue);
	// case NOT_EMPTY_STRING:
	// return fieldValue.length() > 0;
	// case Y_N_OR_EMPTY:
	// return fieldValue.length() == 0 | fieldValue.equals("Y") ||
	// fieldValue.equals("N");
	// default:
	// System.out.println("criterion:" + criterion);
	// throw new RuntimeException("criterion value not implemented");
	// }
	//
	// }

	// constructors
	public FieldDefinitions() {
	}

	// { {"field name in file header", "description of valid values",
	// "<empty String> or description of how to recoded String value" }
	// TODO: extent to include kind in {id, numeric, indicator (0/1),
	// categorical, date (convert to day # past epoch)}]
	public FieldDefinitions(String[][] array) {
		validValuesDescription = new HashMap<String, String>();
		recodeDescription = new HashMap<String, String>();

		for (int i = 0; i < array.length; ++i) {
			String fieldName = array[i][0];
			validValuesDescription.put(fieldName, array[i][1]);
			recodeDescription.put(fieldName, array[i][2]);
		}
	}

	// accessors
	public int getNumberFields() {
		return validValuesDescription.size();
	}

	public Set<String> getFieldNames() {
		return validValuesDescription.keySet();
	}

	public String getValidValuesDefinition(String fieldName) {
		if (validValuesDescription.containsKey(fieldName))
			return validValuesDescription.get(fieldName);
		throw new IllegalArgumentException("field name (" + fieldName
				+ ") is not known");
	}

	public String getRecodeDefinition(String fieldName) {
		if (recodeDescription.containsKey(fieldName))
			return recodeDescription.get(fieldName);
		throw new IllegalArgumentException("field name (" + fieldName
				+ ") is not known");
	}

	public static FieldDefinitions parcels(String obs) {
		if (obs.equals("1A") || obs.equals("all used"))
			return parcelsObs1A();
		else if (obs.equals("2R"))
			return parcelsObs2R();
		else
			throw new RuntimeException("obs=" + obs + " not implemented");
	}

	private static FieldDefinitions parcelsObs1A() {
		String[][] table = {
				{ "APN RECODED", "long", "" }, // APN must be first
				{ "CENSUS TRACT", "long", "" }, // CENSUS TRACT must be second
				{ "ACRES", "long > 0", "" },
				{ "BEDROOMS", "long", "" },
				{ "FOUNDATION CODE", "string not empty", "" },
				{ "HEATING CODE", "string not empty", "" },
				{ "IMPROVEMENT VALUE CALCULATED", "long > 0", "" },
				{ "LAND VALUE CALCULATED", "long > 0", "" },
				{ "LIVING SQUARE FEET", "long > 0", "" },
				{ "LOCATION INFLUENCE CODE", "string not empty", "" }, // Sumit's
																		// Site
																		// Influence
				{ "PROPERTY ZIPCODE", "long > 0", "" },
				{ "PARKING SPACES", "long", "" },
				{ "PARKING TYPE CODE", "string not empty", "" },
				{ "POOL FLAG", "Y N space empty", "Y N space empty indicator" },
				{ "ROOF TYPE CODE", "string not empty", "" },
				{ "SALES TRANSACTION TYPE CODE", "string not empty", "" }, // Sumit's
																			// new
																			// construction,
																			// if
																			// value
																			// 003
																			// (found
																			// in
																			// CreateObs)
				{ "TOTAL BATHS CALCULATED", "long > 0", "" },
				{ "YEAR BUILT", "long > 0", "" } };
		return new FieldDefinitions(table);
	}

	private static FieldDefinitions deedsObsAll() {
		String[][] table = {
				{ "DATE RECODED", "date", "date fix" }, // the range restriction
														// is to be implemented
														// in the estimation
														// procedure
				// {"SALE AMOUNT", "long in [1000,10000000]", ""}, //TODO: put
				// this restiction in Obs 1R
				{ "SALE AMOUNT", "long > 0", "" },
				{ "PRIOR SALES AMOUNT", "long or empty", "empty to zero" },
				{ "TRANSACTION TYPE CODE", "long", "" } };
		return new FieldDefinitions(table);
	}

	private static FieldDefinitions parcelsObs2R() {
		// restrict values to be in (1st percentile, 99th percentile)
		// percentiles are given in file master.analysis
		String[][] table = {
				{ "APN RECODED", "long", "" }, // APN must be first
				{ "CENSUS TRACT", "long", "" }, // CENSUS TRACT must be second
				{ "ACRES", "long in [572, 18898]", "" }, // has 4 implied
															// decimal points;
															// in (0;
															// 119,800.4200)
				{ "BEDROOMS", "long in [1, 5]", "" }, // in (0,99)
				{ "IMPROVEMENT VALUE CALCULATED", "long in [7975, 809657]", "" }, // in
																					// (0;
																					// 95,539,932)
				{ "LAND VALUE CALCULATED", "long in [9799, 1353247]", "" }, // in
																			// (0;
																			// 53,985,309)
				{ "LIVING SQUARE FEET", "long in [597, 5133]", "" }, // in (0;
																		// 57,600)
				{ "PROPERTY ZIPCODE", "long > 0", "" }, // no restrictions on
														// zip codes (which are
														// 9 digits)
				{ "PARKING SPACES", "long in [0, 4]", "" }, // in (0, 800) NOTE:
															// first percentile
															// cutoff not used
															// as 0 is
															// reasonable number
															// of parking spaces
				{ "POOL FLAG", "Y N space empty", "Y N space empty indicator" },
				{ "TOTAL BATHS CALCULATED", "long in [100, 400]", "" }, // has 2
																		// implied
																		// decimal
																		// points;
																		// in
																		// (0,
																		// 99.00)
				{ "YEAR BUILT", "long > 0", "" } // in 0 union (1801,2009)
		};
		return new FieldDefinitions(table);
	}

	public static FieldDefinitions deeds(String obs) {
		if (obs.equals("1A") || obs.equals("all used") || obs.equals("2R"))
			return deedsObsAll();
		else if (obs.equals("2R"))
			return deedsObs2R();
		else
			throw new RuntimeException("obs=" + obs + " not implemented");
	}

	private static FieldDefinitions deedsObs2R() {
		String[][] table = { { "DATE RECODED", "date", "date fix" }, // the
																		// range
																		// restriction
																		// is to
																		// be
																		// implemented
																		// in
																		// the
																		// estimation
																		// procedure
				// {"SALE AMOUNT", "long in [1000,10000000]", ""}, //TODO: put
				// this restiction in Obs 1R
				{ "SALE AMOUNT", "long > 0", "" },
				// {"PRIOR SALES AMOUNT", "long or empty", "empty to zero"},
				{ "TRANSACTION TYPE CODE", "long", "" } };
		return new FieldDefinitions(table);
	}

	public static FieldDefinitions geocodings(String obs) {
		if (obs.equals("1A") || obs.equals("all used") || obs.equals("2R"))
			return geocodingsObsAll();
		else
			throw new RuntimeException("obs=" + obs + " not implemented");
	}

	private static FieldDefinitions geocodingsObsAll() {
		String[][] table = { { "Latitude", "float", "" },
				{ "Longitude", "float", "" } };
		return new FieldDefinitions(table);
	}
}
