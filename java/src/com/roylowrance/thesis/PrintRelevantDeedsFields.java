package com.roylowrance.thesis;

import java.io.FileNotFoundException;

import com.roylowrance.util.DataHeader;
import com.roylowrance.util.Extractor;

public class PrintRelevantDeedsFields {
	
//	public static void main(String[] arg) {
//		System.out.println("hi");
//	}

	// print every occurrence of field PRIOR SALES AMOUNT in the
	// relevant-deeds.* file
	public static void main(String[] args) throws FileNotFoundException {
		String fieldName = "PRIOR SALES AMOUNT";
		String basePath = Dir.project() + "data/generated-v4/relevant-deeds";

		DataHeader dh = new DataHeader(basePath + ".data", basePath + ".header");
		final int throttle = 0;
		dh.visit(new Visitor(fieldName), throttle);
		dh.close();
		throw new RuntimeException("I am finished");
	}

	static class Visitor implements DataHeader.Visitor {
		Extractor extractor;
		String fieldName;

		public Visitor(String fieldName) {
			this.fieldName = fieldName;
		}

		public void start(String header) {
			String separatorRegex = "\\|";
			extractor = new Extractor(header, separatorRegex);
		}

		public void end() {
		}

		public void visit(String record) {
			String value = extractor.extract(record, fieldName);
			if (value.isEmpty()) return;
			System.out.println(fieldName + "=" + value);
		}
	}
}
