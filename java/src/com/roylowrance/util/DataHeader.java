package com.roylowrance.util;

import java.io.File;
import java.io.FileNotFoundException;

import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;

// support reading and maybe writing of csv files in which the data and 
// header are in separate files. The separation allows the data file to
// be sorted.
public class DataHeader {
	private Scanner dataScanner;
	private String header;
	
	public interface Visitor {
		public void start(String header); // called before first visit
		public void visit(String record); // called once for each record
		public void end();                // called after last record
	}
	
	public DataHeader(String filePathData, String filePathHeader)
	throws FileNotFoundException {
		Scanner headerScanner = new Scanner(new File(filePathHeader));
		header = headerScanner.nextLine();
		headerScanner.close();
		
		dataScanner = new Scanner(new File(filePathData));
	}
	
	// close file associated with the data
	public void close() {
		dataScanner.close();
	}
	
	// visit each observation in the file
	public void visit(Visitor visitor, int throttle) {
		visitor.start(header); 
		int recordsVisited = 0;
		while (dataScanner.hasNext()) {
			String obsRecord = dataScanner.nextLine();
			visitor.visit(obsRecord);
			recordsVisited += 1;
			if (throttle != 0 && recordsVisited >= throttle)
				break; // out of the while loop
		}
		visitor.end();
	}
	
	// return sets of columns as specified by their names, using the Extractor
	// do this in one pass over the data
	public static class TableRow extends ArrayList<String> {}
	public static class Table extends ArrayList<TableRow> {}
	public static class Tables extends ArrayList<Table> {}
	public static class ColumnList extends ArrayList<String> {}
	public static class ColumnLists extends ArrayList<ColumnList> {}
	public static Tables extractColumnLists(String fileDataPath, String fileHeaderPath,
			                               ColumnLists columnSets,
			                               int throttle)
	throws FileNotFoundException {
		class MyVisitor implements Visitor {
			DataHeader.ColumnLists columnLists;
			private Extractor extractor;
			//private ArrayList<ArrayList<ArrayList<String>>> results;
			private Tables results;
			int numberResultsSets;
			
			public MyVisitor(DataHeader.ColumnLists columnSets) {
				this.columnLists = columnSets;
				numberResultsSets = columnSets.size();
				//results = new ArrayList<ArrayList<ArrayList<String>>>();
				results = new Tables();
				for (int i = 0; i < numberResultsSets; i++) 
					results.add(new Table());
			}
			
			public void start(String header) {
				String separatorRegex = "\\|";
				extractor = new Extractor(header, separatorRegex);
			}
			
			public void end() {}
			
			public void visit(String dataRecord) {
				Log log = new Log("DataHeader.extractColumnSets.visit", true);
				
				// create the new row that will get appended
				ArrayList<TableRow> nextRows = new ArrayList<TableRow>();
				for (List<String> columnNames : columnLists) {
					TableRow tableRow = new TableRow();
					for (String columnName : columnNames) {
						tableRow.add(extractor.extract(dataRecord, columnName));
					}
					nextRows.add(tableRow);
					log.println("columnValues:" + tableRow);
				}
				
				// append each element of tableRow to each Table in results
				int index = 0;
				for(TableRow element : nextRows) {
					results.get(index).add(element);
					index += 1;
				}
				log.println("results so far:" + results);
			}
			
			public Tables getResults() {
				return results;
			}
			
		}
		
		DataHeader hd = new DataHeader(fileDataPath, fileHeaderPath);
		MyVisitor mv = new MyVisitor(columnSets);
		hd.visit(mv, throttle);
		return mv.getResults();
	}	
}
