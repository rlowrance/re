package com.roylowrance.thesis; // 14Jan 15:51

import java.io.FileNotFoundException;
import java.io.IOException;

import com.roylowrance.util.LineScanner;
import com.roylowrance.util.Log;

// visit each observation using the Visitor interface
public class ObsVisit {
	private LineScanner dataScanner;
	private String header;

	public interface Visitor {
		public void start(String header); // called before first visit

		public void visit(String record); // called once for each record

		public void end(); // called after last record
	}

	// construct using paths the data and header
	public ObsVisit(String fileDataPath, String fileHeaderPath)
			throws FileNotFoundException, IOException {
		Log log = new Log("ObsVisit.ObsVisit", false);
		log.println("fileDataPath:" + fileDataPath);
		log.println("fileHeaderPath:" + fileHeaderPath);

		dataScanner = new LineScanner(fileDataPath);

		LineScanner headerScanner = new LineScanner(fileHeaderPath);
		header = headerScanner.nextLine();
		headerScanner.close();
	}

	// close file associated with the data
	public void close() throws IOException {
		dataScanner.close();
	}

	// visit each observation in the file
	public void visit(Visitor visitor, int throttle) throws IOException {
		visitor.start(header);
		int recordsRead = 0;
		while (dataScanner.hasNextLine()) {
			String obsRecord = dataScanner.nextLine();
			visitor.visit(obsRecord);
			recordsRead += 1;
			if (throttle > 0 && recordsRead >= throttle)
				break; // out of the while loop
		}
		visitor.end();
	}
}
