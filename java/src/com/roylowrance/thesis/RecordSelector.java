package com.roylowrance.thesis;

import java.util.HashMap;
import java.util.Map;

import com.roylowrance.util.Counters;
import com.roylowrance.util.Date;
import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;
import com.roylowrance.util.Report;
import com.roylowrance.util.Represents;

// maybe select a record and if so, return a possibly recoded version
public class RecordSelector {
	private FieldDefinitions definitions = null;
	// private int numberFields = 0;
	private Extractor extractor = null;
	private InvalidValueTracker invalidValueTracker = new InvalidValueTracker();

	private class InvalidValueTracker {
		HashMap<String, Counters<String>> bad = new HashMap<String, Counters<String>>();

		public InvalidValueTracker() {
		}

		public void remember(String fieldName, String invalidValue) {
			if (!bad.containsKey(fieldName))
				bad.put(fieldName, new Counters<String>());
			bad.get(fieldName).increment(invalidValue);
		}

		public void report(Report.Section reportSection) {
			for (Map.Entry<String, Counters<String>> entry : bad.entrySet()) {
				reportSection.println("bad entries for key: " + entry.getKey());
				Counters<String> counters = entry.getValue();
				for (String counterKey : counters.keySet())
					reportSection
							.println(" invalid value:<" + counterKey
									+ "> occurs " + counters.get(counterKey)
									+ " times");
			}
		}
	}

	public void report(Report.Section reportSection) {
		invalidValueTracker.report(reportSection);
	}

	public RecordSelector(FieldDefinitions definitions, Extractor extractor) {
		this.definitions = definitions;
		this.extractor = extractor;
	}

	// thrown when the record is not selected
	public class RecordSelectorException extends RuntimeException {
		private String fieldName;
		private String fieldValue;

		public RecordSelectorException(String fieldName, String fieldValue) {
			super("invalid value (" + fieldValue + ") in field " + fieldName);
			this.fieldName = fieldName;
			this.fieldValue = fieldValue;
		}

		public String getFieldName() {
			return fieldName;
		}

		public String getFieldValue() {
			return fieldValue;
		}
	}

	// return recoded fields if the record passes all the filters
	// otherwise throw RecordSelectorException
	// filter line ::= <field name> <filter name> [<recoding name>]
	public String[] select(String record) throws RecordSelectorException {
		final boolean debugging = true;
		final boolean logging = false;
		Log log = new Log("RecordSelector.select", logging);
		String[] answer = new String[definitions.getNumberFields()];
		int i = 0;
		for (String fieldName : definitions.getFieldNames()) {
			if (debugging && fieldName.equals("PRIOR SALES AMOUNT"))
				System.out.println("found PRIOR SALES AMOUNT FIELD");
			String fieldValue = extractor.extract(record, fieldName);
			boolean isValidValue = isValidField(
					definitions.getValidValuesDefinition(fieldName), fieldValue);

			log.println("fieldName:" + fieldName + " fieldValue:" + fieldValue
					+ " isValidValue:" + isValidValue);
			if (!isValidValue) {
				log.println("invalid fieldNames:" + fieldName + " fieldValue:<"
						+ fieldValue + ">");
				invalidValueTracker.remember(fieldName, fieldValue);
				throw new RecordSelectorException(fieldName, fieldValue);
			}
			answer[i] = recode(definitions.getRecodeDefinition(fieldName),
					fieldValue);
			if (logging)
				log.println("recoded answer[" + i + "]:" + answer[i]);

			if (debugging && fieldName.equals("PRIOR SALES AMOUNT")) {
				System.out.println("PRIOR SALES AMOUNT string=" + fieldValue
						+ " isValidValue=" + isValidValue + " answer[i]="
						+ answer[i]);
				if (!answer[i].equals("0"))
					throw new RuntimeException("PRIOR SALE AMOUNT not zero");
			}

			i++;
		}
		log.println("answer:" + answer);
		log.println("answer.length:" + answer.length);
		return answer;
	}

	// all conditions imply is present
	private boolean isValidField(String filterName, String fieldValue) {
		Log log = new Log("RecordSelector.isValidField", false);
		log.println("filterName:" + filterName + " fieldValue:<" + fieldValue
				+ ">");
		boolean answer;

		if (filterName.equals("Y N space emtpy"))
			answer = fieldValue.length() == 0 || fieldValue.equals("Y")
					|| fieldValue.equals("N") || fieldValue.equals(" ");

		else if (filterName.equals("long"))
			answer = Represents.long_(fieldValue);

		else if (filterName.equals("int or empty"))
			answer = fieldValue.length() == 0 || Represents.int_(fieldValue);

		else if (filterName.equals("string"))
			answer = fieldValue.length() > 0;

		else if (filterName.equals("string or empty"))
			answer = true;

		else if (filterName.equals("string not empty"))
			answer = fieldValue.length() != 0;

		else if (filterName.equals("long or empty"))
			answer = fieldValue.length() == 0 || Represents.long_(fieldValue);

		else if (filterName.equals("long > 0")) {
			if (!Represents.long_(fieldValue))
				answer = false;
			else
				answer = Long.valueOf(fieldValue) > 0;
		}

		else if (filterName.equals("long > 1775")) {
			if (!Represents.long_(fieldValue))
				answer = false;
			else
				answer = Long.valueOf(fieldValue) > 1775;
		}

		else if (filterName.equals("long in [0, 4]"))
			answer = filterLongRange(fieldValue, 0, 4);

		else if (filterName.equals("long in [1, 5]"))
			answer = filterLongRange(fieldValue, 1, 5);

		else if (filterName.equals("long in [100, 400]"))
			answer = filterLongRange(fieldValue, 100, 400);

		else if (filterName.equals("long in [572, 18898]"))
			answer = filterLongRange(fieldValue, 572, 18898);

		else if (filterName.equals("long in [597, 5133]"))
			answer = filterLongRange(fieldValue, 597, 5133);

		else if (filterName.equals("long in [1000,10000000]"))
			answer = filterLongRange(fieldValue, 1000, 10000000);

		else if (filterName.equals("long in [7975, 809657]"))
			answer = filterLongRange(fieldValue, 7975, 809657);

		else if (filterName.equals("long in [9799, 1353247]"))
			answer = filterLongRange(fieldValue, 9799, 1353247);

		else if (filterName.equals("Y N space empty"))
			answer = fieldValue.length() == 0 || fieldValue.equals("Y")
					|| fieldValue.equals("N") || fieldValue.equals(" ");

		else if (filterName.equals("date"))
			answer = Represents.date(fixDate(fieldValue));

		else if (filterName.equals("date fixed in [1979,2009]")) {
			String fieldValueFixed = fixDate(fieldValue);
			if (!Represents.date(fieldValueFixed))
				answer = false;
			else {
				try {
					Date date = new Date(fieldValueFixed);
					int year = date.getYear();
					answer = 1979 <= year && year <= 2009;
				} catch (IllegalArgumentException e) {
					answer = false;
				}
			}
		}

		else {
			System.out.println("filterName:" + filterName);
			throw new RuntimeException("invalid filter name");
		}

		log.println("answer:" + answer);
		return answer;
	}

	private boolean filterLongRange(String fieldValue, long low, long high) {
		if (!Represents.long_(fieldValue))
			return false;
		long value = Long.valueOf(fieldValue);
		return low <= value && value <= high;
	}

	private String recode(String recodingName, String fieldValue) {
		Log log = new Log("RecordSelector.recode", true);
		if (recodingName.equals(""))
			return fieldValue;
		if (recodingName.equals("date fix"))
			return fixDate(fieldValue);
		if (recodingName.equals("Y N space empty indicator"))
			return (fieldValue.length() == 0 || fieldValue.equals("N") || fieldValue
					.equals(" ")) ? "0" : "1";
		if (recodingName.equals("empty to zero"))
			return (fieldValue.length() == 0 ? "0" : fieldValue);
		if (recodingName.equals("new construction indicator"))
			return (fieldValue.equals("3") || fieldValue.equals("003")) ? "1"
					: "0";
		log.println("filterName:" + recodingName + " fieldValue:" + fieldValue);
		throw new RuntimeException("recoding name not implemented");
	}

	// convert YYYYMM00 to YYYYMM01 and YYYY-MM-DD to YYYYMMDD
	// nothing before us has validated the String date, so it might be anything
	// including empty
	private String fixDate(String date) {
		Log log = new Log("RecordSelector.fixDate", false);
		if (date.length() == 8) {
			log.println("date.substring(6,8):" + date.substring(6, 8));
			if (date.substring(6, 8).equals("00"))
				return date.substring(0, 6) + "01";
			else
				return date;
		}
		if (date.length() == 10)
			return fixDate(date.replace("-", ""));
		return date;
	}

}
