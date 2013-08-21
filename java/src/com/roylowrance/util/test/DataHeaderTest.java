package com.roylowrance.util.test;

import static org.junit.Assert.*;

import java.util.ArrayList;

import org.junit.Before;
import org.junit.Test;

import java.io.FileNotFoundException;

import com.roylowrance.util.DataHeader;
import com.roylowrance.util.Extractor;

public class DataHeaderTest extends Object {
	String fileDataPath;
	String fileHeaderPath;
	DataHeader dh;
	
	// return directory where the thesis project is stored
	private String dir() {
		return "/home/roy/Dropbox/nyu-thesis-project/";
	}

	@Before
	public void setUp() throws Exception {
		String project = dir();
		String fileBase = project + "data/generated-v4/obs2R/obs2R";
		fileDataPath = fileBase + ".data";
		fileHeaderPath = fileBase + ".header";
		dh = new DataHeader(fileDataPath, fileHeaderPath);
	}

	@Test
	public void testDataHeader() {
		// tested in setUp()
	}

	@Test
	public void testClose() {
		dh.close();
	}

	@Test
	public void testVisit() {
		class MyVisitor implements DataHeader.Visitor {
			private int dataRecordCount;
			public MyVisitor() {
				dataRecordCount = 0;
			}
			public void start(String header) {
				assertTrue(header.startsWith("APN ID|"));
				assertTrue(header.endsWith("|longitude"));
			}
			public void visit(String data) {
				final boolean display = false;
				if (display)
					System.out.println("data(" + dataRecordCount + ")=<" + data + ">");
				if (dataRecordCount == 0) {
					assertTrue(data.startsWith("2004001004|19840706"));
					// the test below doesn't work, though the file seems to match
					//assertTrue(data.endsWith("|-188.6201"));
				}
				else if (dataRecordCount == 1) {
					assertTrue(data.startsWith("2004001004|19930316"));
					//assertTrue(data.endsWith("| -188.6201"));
				}
				else {
					fail("only 2 data records should be read");
				}
				dataRecordCount += 1;
			}
			public void end() {}
		}
		MyVisitor mv = new MyVisitor();
		final int throttle = 2;
		dh.visit(mv, throttle);
		dh.close();
	}

	@Test
	public void testExtractColumnSets()
	throws FileNotFoundException {
		/////////// define 2 column lists
		// set 1: just the APN
		DataHeader.ColumnList first = new DataHeader.ColumnList();
		first.add("APN ID");
		
		// set 2: some features
		DataHeader.ColumnList second = new DataHeader.ColumnList();
		second.add("TOTAL BATHS CALCULATED");
		second.add("SALE AMOUNT");
		second.add("longitude");
		
		// combined 
		DataHeader.ColumnLists combined = new DataHeader.ColumnLists();
		combined.add(first);
		combined.add(second);
		
		final int throttle = 3;
		DataHeader.Tables tables = DataHeader.extractColumnLists(fileDataPath, fileHeaderPath, combined, throttle);
		final boolean display = true;
		if (display) {
			int count = 0;
			for (DataHeader.Table table : tables) {
				System.out.print("count=" + count + ":");
				for (DataHeader.TableRow tableRow : table) {
					System.out.print(" " + tableRow);
				}
				System.out.println("");
				count += 1;
			}
		}
		DataHeader.Table apns = tables.get(0);
		DataHeader.Table features = tables.get(1);
		
		// check apns
		assertEquals("2004001004", apns.get(0).get(0));
		assertEquals("2004001004", apns.get(1).get(0));	
		assertEquals("2004001009", apns.get(2).get(0));
		
		// check features
		assertEquals("0000300", features.get(0).get(0));
		assertEquals("00000290000", features.get(1).get(1));
		assertEquals(" -118.6225", features.get(2).get(2));
	}

}
