package com.roylowrance.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.Set;
import java.util.TreeMap;

/**
 * A TreeMap<K,V> that is cached to a disk file
 * @author roy
 *
 * @param <K> The type of the key of the TreeMap
 * @param <V> The type of the value of the Treemap
 */
public class TreeMapCacheable<K,V> {
	private TreeMap<K,V> map;
	
	// construct from a file
	// if the file does not exists, create it
	/**
	 * Construct from the contents of a file.
	 * 
	 * If the file does not exist, create it and load it with an empty TreeMap
	 * @param filePath
	 * @throws FileNotFoundException can be thrown if file is write protected
	 * @throws IOException
	 * @throws ClassNotFoundException
	 */
	public TreeMapCacheable(String filePath)
	throws FileNotFoundException, IOException, ClassNotFoundException {
		File file = new File(filePath);
		if (!file.exists()) {
			map = new TreeMap<K,V>();
			storeToDisk(filePath);
			return;
		}
		// deserialize the file and over-write this.map
		FileInputStream fis = new FileInputStream(file);
		ObjectInputStream ois = new ObjectInputStream(fis);
		TreeMap<K,V> newMap = (TreeMap<K,V>) ois.readObject();
		this.map = newMap;
		ois.close();
	}

	/**
	 * Return true if and only if the TreeMap contains the specified key
	 * @param key the key to check for
	 * @return true if the key is the the map; otherwise false
	 */
	public boolean containsKey(K key) {
		return map.containsKey(key);
	}
	
	public V get(K key) {
		return map.get(key);
	}

	public Set<K> keySet() {
		return map.keySet();
	}
	
	public V put(K key, V value) {
		return map.put(key, value);
	}
	
	public int size() {
		return map.size();
	}
	

	/**
	 * Write the map to the specified file
	 * @param filePath path to the file
	 * @throws FileNotFoundException can be thrown if caller does not have write permission
	 * @throws IOException
	 */
	public void storeToDisk(String filePath)
	throws FileNotFoundException, IOException {
		Log log = new Log("TreeMapCacheable.storeToDisk", false);
		log.println("filePath:" + filePath);
		FileOutputStream fos = new FileOutputStream(filePath);
		ObjectOutputStream oos = new ObjectOutputStream(fos);
		log.println("about to write to cache:" + map);
		oos.writeObject(map);
		oos.close();
	}

}
