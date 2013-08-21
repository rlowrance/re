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
public class DiskCache<K,V> {
	private String filePath;
	
	// constructor
	public DiskCache(String filePath) {
		this.filePath = filePath;
	}
	
	// return the map stored on disk or an empty map if nothing is store
	public TreeMap<K,V> loadFromDisk()
	throws FileNotFoundException, IOException, ClassNotFoundException {
		File file = new File(filePath);
		if (!file.exists()) {
			return new TreeMap<K,V>();
		}
		// deserialize the file into a new map
		FileInputStream fis = new FileInputStream(file);
		ObjectInputStream ois = new ObjectInputStream(fis);
		TreeMap<K,V> map = (TreeMap<K,V>) ois.readObject();
		ois.close();
		return map;
	}
	
	// store the map into the disk file
	public void storeToDisk(TreeMap<K,V> map)
	throws FileNotFoundException, IOException {
		Log log = new Log("DiskCache", true);
		FileOutputStream fos = new FileOutputStream(filePath);
		ObjectOutputStream oos = new ObjectOutputStream(fos);
//		// debug by writing each element individually
//		for (K key : map.keySet()) {
//			log.println("about to write key:" + key);
//			oos.writeObject(key);
//			log.println("about to write value:" + map.get(key));
//			oos.writeObject(map.get(key));
//		}
		log.println("about to write to cache:" + map);
		oos.writeObject(map);
		oos.close();
	}

}
