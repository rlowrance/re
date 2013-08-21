package com.roylowrance.util;

import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

// a bunch of counters each identified with a T as its identifier
public class Counters<T> {
	private TreeMap<T,Integer> map = new TreeMap<T,Integer>();
	
	public Counters() {}
	
	public void increment(T name) {
		if (map.containsKey(name))
			map.put(name, map.get(name) + 1); 
		else
			map.put(name,  1);
	}
	
	public Set<T> keySet() {
		return map.keySet();
	}
	
	public Set<Map.Entry<T,Integer>> entrySet() {
		return map.entrySet();
	}
	
	public int get(T name) {
		if (map.containsKey(name))
			return map.get(name);
		return 0;
	}

}
