package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Test;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;

import com.roylowrance.util.Extractor;
import com.roylowrance.util.Log;
import com.roylowrance.util.Exception;

public class ExtractorTest {

	@Test
	public void test() {
		final String regex = "\\|";
		final String header = "abc | 12 times | x y z";
		Extractor extractor = new Extractor(header, regex);
		
		final String input = "12-45 | many | 27";
		assertEquals("12-45 ", extractor.extract(input, "abc "));
		assertEquals(" many ", extractor.extract(input, " 12 times "));
		assertEquals(" 27", extractor.extract(input, " x y z"));
	}
	
	@Test // test dates in deeds files CAC06027F?.txt
	public void testFiles() throws FileNotFoundException {
		for (int suffix = 1; suffix <= 8; suffix++) {
			testFile(suffix);
		}
	}
	
	// test on one deeds file
	public void testFile(int suffix) throws FileNotFoundException {
		Log log = new Log("ExtractorTest.testFile", true);
		log.println("suffix:" + suffix);
		if (suffix != 8)
			return;
		String thesisProjectDir = "/home/roy/Dropbox/nyu-thesis-project/";
		String filePath = thesisProjectDir + "data/raw/deeds-all-columns/copy of CAC06037F" + String.valueOf(suffix) + ".txt";
		log.println("filePath:" + filePath);
		Scanner scanner = new Scanner(new File(filePath));
		String header = scanner.nextLine().replaceAll("\\\t", "|");
		final String regex = "\\|";
		Extractor extractor = new Extractor(header, regex);
		int count = 0;
		long found = 0;
		int selected = 0;
		int withWrongNumberFields = 0;
		String specialApn = "8510021012";
		while (scanner.hasNextLine()) {
			String dataLine = scanner.nextLine()/*.replaceAll("\\\t", "|")*/;
			found++;
			if (//dataLine.contains("06037") &&
			    //dataLine.contains("000") &&
			    //dataLine.contains("NOTHING")
				//dataLine.length() > 300
				found == 295641 || found == 295640
			    ){
				selected++;
				log.println("selected:" + dataLine);
			}
				
			//log.println("dataLine:" + dataLine);
//			if (/*dataLine.contains("ROCHELLE") && dataLine.contains("MONROVIA") &&*/ dataLine.contains("8510-02") ) {
//				log.println("dataLine:" + dataLine);
//				try {
//					String saleDate = extractor.extract(dataLine, "SALE DATE");
//					log.println("SALE DATE:" + saleDate);
//				}
//				catch (Extractor.Exception e) {
//					log.println("wrong number fields");
//				}
//			}
//			try {
//				String apnUnformatted = extractor.extract(dataLine, "APN UNFORMATTED");
//				if (apnUnformatted.contains("8510021")) {
//					//log.println("line with key:" + dataLine);
//					log.println(" apnUnformatted:" + apnUnformatted);
//				}
//			}
//			catch (Extractor.Exception e) {
//				log.println("dataLine with wrong number fields:" + dataLine);
//				log.println("e:" + e);
//				withWrongNumberFields++;
//			}
//			found++;
//			try {
//				String apnUnformatted = extractor.extract(dataLine, "APN UNFORMATTED");
//				String saleDate = extractor.extract(dataLine, "SALE DATE");
//				if (apnUnformatted.contains("851002"))
//					log.println("apnUnformatted:" + apnUnformatted + " saleDate:" + saleDate);
//				found += 1;
//			}
//			catch (Extractor.Exception e) {
//				withWrongNumberFields += 1;
//			}

				//throw new UtilException("found it");
//			if (dataLine.contains("06037"))
//				throw new RuntimeException("found FIPS");
//			if (dataLine.contains("8309005028"))
//				throw new RuntimeException("first apn");
//			String fipsCode = null;
//			String apnUnformatted = null;
//			String apnFormatted = null;
//			String saleDate = null;
//			String recordingDate = null;
//			try {
//				fipsCode = extractor.extract(dataLine, "FIPS CODE");
//				apnUnformatted = extractor.extract(dataLine, "APN UNFORMATTED");
//				apnFormatted = extractor.extract(dataLine, "APN FORMATTED");
//				saleDate = extractor.extract(dataLine, "SALE DATE");
//				recordingDate = extractor.extract(dataLine, "RECORDING DATE");
//			}
//			catch (Extractor.Exception e) {
//				//log.println("wrong number of fields in:" + dataLine);
//				continue;
//			}
//			if (false) {
//				System.out.print("fipsCode:" + fipsCode);
//				System.out.print(" apnUnformatted:" + apnUnformatted);
//				System.out.print(" apnFormatted:" + apnFormatted);
//				System.out.print(" saleDate:" + saleDate);
//				System.out.print(" recordingDate:" + recordingDate);
//				System.out.println("");
//				System.out.println("apnUnformatted.length():" + apnUnformatted.length());
//			}
//			//if (saleDate.length() > 0 && saleDate.startsWith("200"))
////			if (saleDate.length() == 0)
////				continue;
////			System.out.print(saleDate + " ");
////			count += 1;
////			if (count % 15 == 0)
////				System.out.println("");
//			//if (saleDate.equals("20041228") || saleDate.equals("19861100"))
//			//if (apnUnformatted.equals("8309005028") || apnUnformatted.equals("8510021012") || saleDate.startsWith("200") || recordingDate.startsWith("1984"))
//			//if (saleDate.startsWith("200") || recordingDate.startsWith("200"))
//			if (apnUnformatted.length() == 0)
//				continue;
////			if (apnUnformatted.length() != 10 && apnUnformatted.length() != 12) {
////				throw new RuntimeException("apnUnformatted.length:" + apnUnformatted.length() + "value=<" + apnUnformatted + ">");
////			}
//			if (apnUnformatted.contains("8510021012") || dataLine.contains("8510021012")) {
//				found += 1;
//				log.println("suffix:" + suffix +
//						    " apnUnformatted:<" + apnUnformatted + ">" + 
//						    " saleDate:<" + saleDate + ">" + 
//						    " recordingDate:<" + recordingDate + ">" 
//						    );
//			}
		}
		//System.out.println("withWrongNumberFields:" + withWrongNumberFields);
		System.out.println("testFile completed; found " + found + " selected " + selected);

	}

}
