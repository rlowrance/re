package com.roylowrance.thesis.test;

import java.io.FileNotFoundException;
import static org.junit.Assert.*;

import org.junit.Test;

import com.roylowrance.thesis.GeocodingOLD;

public class GeocodingOLDTest {

	@Test
	public void test() throws FileNotFoundException {
		GeocodingOLD geocoding = new GeocodingOLD();

		// NOTE: the latitude and longitude fields in the geocoding.tsv file
		// contain a prefixed blank
		// first record
		assertEquals(" 34.22", geocoding.getLatitude("2004001004"));
		assertEquals(" -118.6201", geocoding.getLongitude("2004001004"));

		// last record
		assertEquals(" 33.9821", geocoding.getLatitude("8765022045"));
		assertEquals(" -117.8521", geocoding.getLongitude("8765022045"));

		// extreme values
		assertEquals(" 33.8679", geocoding.getLatitude("3008015032"));
		assertEquals(" -117.8981", geocoding.getLongitude("3008010019"));

		// apn present but value is 0
		assertEquals(null, geocoding.getLatitude("3008010021"));
		assertEquals(null, geocoding.getLongitude("3008010021"));

		// non-existent record
		assertEquals(null, geocoding.getLatitude("2004001003"));
		assertEquals(null, geocoding.getLongitude("2004001003"));

	}

}
