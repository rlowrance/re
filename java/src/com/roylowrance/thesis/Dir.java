package com.roylowrance.thesis;

import com.roylowrance.util.Log;

// locations of directories
public class Dir {
	public static String project() {
		Log log = new Log("Dir.projct", false);
		String osName = System.getProperty("os.name");
		log.println("osName" + osName);

		// determine the root directory where the user files systems are stored
		String userDir = null;
		if (osName.equals("Linux"))
			userDir = "/home/";
		else if (osName.equals("Mac OS X"))
			userDir = "/Users/";
		else {
			throw new RuntimeException("unrecognized os.name (" + osName
					+ ") from System.getProperty()");
		}

		return userDir + "roy/Dropbox/nyu-thesis-project/";
	}

}
