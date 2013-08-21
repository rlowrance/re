package com.roylowrance.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;

import java.util.TreeMap;

// maintain type T in a disk file
public class DiskCache3 {

	// return the map stored on disk or an empty map if nothing is store
	public static <T> T loadFromDisk(String filePath)
	throws FileNotFoundException, IOException, ClassNotFoundException{
		File file = new File(filePath);
		if (!file.exists())
			return (T) new Object();
		// deserialize the file into a new T
		FileInputStream fis = new FileInputStream(file);
		ObjectInputStream ois = new ObjectInputStream(fis);
		T result = (T) ois.readObject();
		ois.close();
		return result;
	}

	// store the map into the disk file
	public static <T> void storeToDisk(T thing, String filePath)
	throws FileNotFoundException, IOException {
		Log log = new Log("DiskCache.storeToDisk", true);
		FileOutputStream fos = new FileOutputStream(filePath);
		ObjectOutputStream oos = new ObjectOutputStream(fos);
//		// debug by writing each element individually
//		for (K key : map.keySet()) {
//			log.println("about to write key:" + key);
//			oos.writeObject(key);
//			log.println("about to write value:" + map.get(key));
//			oos.writeObject(map.get(key));
//		}
		log.println("about to write to cache:" + thing);
		oos.writeObject(thing);
		oos.close();
	}

}
