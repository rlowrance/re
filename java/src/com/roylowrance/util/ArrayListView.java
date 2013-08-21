package com.roylowrance.util;

import java.util.ArrayList;
import java.util.Collection;

// provide a read-only view of an ArrayList<E> in which one element is not visible
// implement only a subset of the ArrayList<E> methods
public class ArrayListView<E> extends ArrayList<E> {
	private ArrayList<E> arrayList;
	private int missingElementIndex; // this element is logically deleted

	// constructor
	public ArrayListView(ArrayList<E> arrayList, int missingElementIndex) {
		this.arrayList = arrayList;
		this.missingElementIndex = missingElementIndex;
	}
	
	// add: disabled
	@Override public boolean add(E o) {
		disabled("add");
		return false;
	}
	
	@Override public void add(int index, E element) {
		disabled("add");
		return;
	}
	
	@Override public boolean addAll(Collection<? extends E> c) {
		disabled("addAll");
		return false;
	}
	
	@Override public void clear() {
		disabled("clear");
	}
	
	@Override public Object clone() {
		disabled("clone");
		return null;
	}
	
	@Override public boolean contains(Object elem) {
		notImplemented("contains");
		return false;
	}
	
	@Override public void ensureCapacity(int minCapacity) {
		disabled("ensureCapacity");
	}
	
	// return element at specified position
	@Override public E get(int index) {
		if (index < missingElementIndex)
			return arrayList.get(index);
		else
			return arrayList.get(index + 1);
	}
	
	// search for first occurence of given argument, testing with equals method
	@Override public int indexOf(Object elem) {
		notImplemented("indexOf");
		return -1;
	}
	
	@Override public boolean isEmpty() {
		notImplemented("isEmpty");
		return false;
	}
	
	@Override public int lastIndexOf(Object elem) {
		notImplemented("lastIndexOf");
		return -1;
	}
	
	@Override public E remove(int index) {
		disabled("remove");
		return null;
	}
	
	@Override public boolean remove(Object o) {
		disabled("remove");
		return false;
	}
	
	@Override protected void removeRange(int fromIndex, int toIndex) {
		disabled("removeRange");
	}
	
	@Override public E set(int index, E element) {
		disabled("set");
		return null;
	}
	
	// return number of elements
	public int size() {
		return arrayList.size() - 1;
	}
	
	@Override public Object[] toArray() {
		notImplemented("toArray");
		return null;
	}
	
	@Override public <T> T[] toArray(T[] a) {
		notImplemented("toArray");
		return null;
	}
	
	@Override public void trimToSize() {
		disabled("trimToSize");
	}
	
	//////////////////  
	// throw exception, because operation is mutating and is hence disabled
	private void disabled(String opName) {
		throw new RuntimeException("attempting operation " + opName + " which is mutating and hence disabled");
	}
	
	// operation is not mutating, but also not implemented, to keep API small
	// and reduce testing requirements
	private void notImplemented(String opName) {
		throw new RuntimeException("attempting operation " + opName + " which is not yet implemented");
	}
}
