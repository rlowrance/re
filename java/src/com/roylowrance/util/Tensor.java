package com.roylowrance.util;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.io.Serializable;

import com.roylowrance.util.Log;

// follow the Torch5.Tensor protocol
// - implements a double tensor only with a special provision for storing and retrieving longs that have not lost precision
// - implements 1 and 2 dimensions only for now
// - changes API to conform to java expectations about getters and setters
// - instead of providing copy, java classes want to provide clone; however, clone is badly broken
//   - instead this implementation provides static factory method newInstance(existingTensor) to return a deep copy 
public class Tensor implements Serializable, Comparable<Tensor> {
    private double[] storage;
    private int nDimensions;
    private int offset;
    // sizes and dimensions are scalars, not arrays, because using arrays slows everything down
    // probably because of java's bounds checking
    private int size0;
    private int size1;
    private int stride0;
    private int stride1;
    
    private final static long serialVersionUID = 1;
    
    ////////////////// comparing
    
    // ref http://docs.oracle.com/javase/6/docs/api/java/lang/Comparable.html
    // totally order based on (1) dimensions (2) size (3) elements
    public int compareTo(Tensor that) {
        final int LESS = -1;
        final int EQUAL = 0;
        final int GREATER = 1;
        
        // first order on number of dimensions
        if (this.nDimensions < that.nDimensions) return LESS;
        if (this.nDimensions > that.nDimensions) return GREATER;
        
        // then order on sizes
        if (this.nDimensions == 1) {
            if (this.size0 < that.size0) return LESS;
            if (this.size0 > that.size0) return GREATER;
        }
        else if (this.nDimensions == 2) {
            if (this.size0 < that.size0) return LESS;
            if (this.size0 > that.size0) return GREATER;
            
            if (this.size1 < that.size1) return LESS;
            if (this.size1 > that.size1) return GREATER;
            
            return EQUAL;
        }
        
        // then order on element by element comparison
        if (this.nDimensions == 1) {
            for (int index = 0; index < this.size0; index++) {
                double thisElement = this.get(index);
                double thatElement = that.get(index);
                if (thisElement < thatElement) return LESS;
                if (thisElement > thatElement) return GREATER;
            }
            return EQUAL;
        }
        else if (this.nDimensions == 2) {
            // use fortran ordering for comparison (as if we raveled the arguments)
            for (int columnIndex = 0; columnIndex < this.size1; columnIndex++)
                for (int rowIndex = 0; rowIndex < this.size0; rowIndex++) {
                    double thisElement = this.get(rowIndex, columnIndex);
                    double thatElement = that.get(rowIndex, columnIndex);
                    if (thisElement < thatElement) return LESS;
                    if (thisElement > thatElement) return GREATER;
                }
            return EQUAL;
        }
        else
            throw new RuntimeException("bad Tensors; this=" + this + " ; that=" + that);
                
    }
    
    ////////////////// displaying
    
    public String toString() {
        if (nDimensions == 1 && offset == 0 && size0 > 0 && size1 == 0 && stride0 == 1  && stride1 == 0) {
            // return an abbreviated string for a common case
            String s = "Tensor-1D@" + Integer.toHexString(hashCode());
            s += "[";
            final int limit = 10;
            for (int i = 0; i < limit && i < size0; i++) {
                if (i != 0) 
                    s += ", ";
                s += get(i);
            }
            if (storage.length > limit)
                s += "...";
            s += "]";
            return s;
        }
        String s = "Tensor@" + Integer.toHexString(hashCode());

        s += "(nDimensions=" + nDimensions;
        s += ",offset=" + offset;
        s += ",size0=" + size0;
        s += ",size1=" + size1;
        s += ",stride0=" + stride0;
        s += ",stride1=" + stride1;
        if (nDimensions == 0) {
            s += ",storage@" + storage;
        }
        else {
            s += ",storage@" + Integer.toHexString(storage.hashCode()) + "=";
            final int limit = 10;
            for (int i = 0; i < limit && i < storage.length; i++) {
                if (i != 0) 
                    s += ", ";
                s += storage[i];
            }
            if (storage.length > limit)
                s += "...";
        }
        return s + ")";
    }
    
    ////////////////// exceptions
    
    // Many methods are stubs in the current implementation.
    // If invoked, each stub throws a NotYetImplemented exception
    public static class NotYetImplemented extends RuntimeException {
        String explanation;
        static final long serialVersionUID = 1;
        
        public NotYetImplemented(String methodName) {
            explanation = "Method " + methodName + " has not yet been implemented";
        }
        
        public NotYetImplemented() {}
    }
    
    // If user attempts to store or retrieve a long without loss of precision using
    // methods getLong(int[,int]): void or setLong(int[,int]): void, this
    // exception is thrown
    public static class LossOfPrecision extends RuntimeException {
        String explanation;
        static final long serialVersionUID = 1;
        
        public LossOfPrecision(String explanation) {
            this.explanation = explanation;
        }
        
        public LossOfPrecision() {}
    }
    
    // helper class to index through a 2D tensor
    private static class Index2Visitor {
        private int nextIndex0;
        private int nextIndex1;
        private int size0;
        
        public Index2Visitor(Tensor x) {
            if (x.getNDimensions() != 2)
                throw new IllegalArgumentException("x must be 2D; x=" + x);
            nextIndex0 = 0;
            nextIndex1 = 0;
            size0 = x.getSize(0);
        }
        
        // set index0 and index1 to next values
        // throw if called too many times
        public void next(Integer index0, Integer index1) {
            index0 = nextIndex0;
            index1 = nextIndex1;
            nextIndex1++;
            if (nextIndex1 == size0) {
                nextIndex1 = 0;
                nextIndex0++;
                if (nextIndex0 == size0)
                    throw new IllegalArgumentException("invoked next past end of elements");
            }
        }
        
        
    }
    
    ////////////////// serialization
    
    // write internal structure to file using specified format
    public void serialize(String filePath, String fileFormat, String[] fieldNames) 
    throws FileNotFoundException, IOException {
        if (fileFormat.equals("javaSerializeDefault"))
            serializeJavaSerializeDefault(filePath);
        else if (fileFormat.equals("csvDelimiterPipe"))
            serializeAsCsv(filePath, fieldNames, "|");
        else 
            throw new IllegalArgumentException("unknown format; fileFormat=" + fileFormat);
    }
    
    private void serializeJavaSerializeDefault(String filePath) throws FileNotFoundException, IOException {
        FileOutputStream fos = new FileOutputStream(filePath);
        ObjectOutputStream oos = new ObjectOutputStream(fos);
        oos.writeObject(this);
        oos.close();
        fos.close();
    }
    
    // write this as a csv file (in ASCII encoding) with the specified delimiter and field name
    // first record is: <field name 1> DELIMITER <field name 2> ...
    // other records are: <double value> DELIMITER <double value> ...
    private void serializeAsCsv(String filePath, String[] fieldNames, String delimiter) throws FileNotFoundException {
        Log log = new Log("Tensor.serializeAsCsv", false);
        CsvWriter csvWriter = new CsvWriter(filePath, delimiter);
        csvWriter.writeRow(fieldNames);
        log.format("%17.15f%n", this.get(0));
        csvWriter.writeRows(this); // write the data rows
        csvWriter.close();
    }
    
    // return new Tensor build from content of a file
    public static Tensor deserialize(String filePath, String fileFormat)
    throws FileNotFoundException, IOException, ClassNotFoundException {
        if (fileFormat.equals("javaSerializeDefault"))
            return deserializeJavaSerializeDefault(filePath);
        else if (fileFormat.equals("csvDelimiterPipe"))
            return deserializeCsv(filePath, "|");
        else 
            throw new IllegalArgumentException("unknown format; fileFormat=" + fileFormat);
    }
    
    // return a new Tensor built from the content of a file
    private static Tensor deserializeJavaSerializeDefault(String filePath) 
    throws FileNotFoundException, IOException, ClassNotFoundException {
        FileInputStream fis = new FileInputStream(filePath);
        ObjectInputStream ois = new ObjectInputStream(fis);
        Tensor tensor = (Tensor) ois.readObject();
        ois.close();
        fis.close();
        return tensor;
    }
    

    
    // return new Tensor build from a csv file
    private static Tensor deserializeCsv(String filePath, String delimited) {
        throw new RuntimeException("stub");
    }
    
    ////////////////// constructors
    
    // return empty tensor
    public Tensor() {
        this.storage = null;
        this.nDimensions = 0;
        this.offset = 0;
        this.size0 = 0;
        this.size1 = 0;
        this.stride0 = 0;
        this.stride1 = 0;
    }
    
    // return new tensor sharing storage, sizes, and strides with another tensor
    // copy constructor
    public Tensor(Tensor that) {
        this.storage = that.storage;
        this.nDimensions = that.nDimensions;
        this.offset = that.offset;
        this.size0 = that.size0;
        this.size1 = that.size1;
        this.stride0 = that.stride0;
        this.stride1 = that.stride1;
    }
    
    // return 1D tensor with specified dimensions
    public Tensor(int size0) {
        this.storage = new double[size0];
        this.nDimensions = 1;
        this.offset = 0;
        this.size0 = size0;
        this.size1 = 0;
        this.stride0 = 1;
        this.stride1 = 0;
    }
    
    // return 2D tensor with specified dimensions
    public Tensor(int size0, int size1) {
        this.storage = new double[size0 * size1];
        this.nDimensions = 2;
        this.offset = 0;
        this.size0 = size0;
        this.size1 = size1;
        this.stride0 = size1;
        this.stride1 = 1;
    }
    
    // return 3D tensor with specified dimensions
    public Tensor(int size0, int size1, int size2) {
        throw new NotYetImplemented();
    }
    
    // return 4D tensor with specified dimensions
    public Tensor(int size0, int size1, int size2, int size3) {
        throw new NotYetImplemented();
    }
      
    // construct 1D from an array
    // Not in torch.Tensor, but added in this implementation
    public static Tensor newInstanceFromArray (double[] array) {
        Tensor result = new Tensor(array.length);
        for (int i = 0; i  < array.length; i++) 
            result.set(i, array[i]);
        return result;
    }
    
    // construct 2D from an array
    // added in this implementation
    public static Tensor newInstanceFromArray(double[][] array) {
        Tensor result = new Tensor(array.length, array[0].length);
        for (int i = 0; i  < array.length; i++) 
            for (int j = 0; j < array[0].length; j++)
                result.set(i, j, array[i][j]);
        return result;
    }

    // return tensor with any number of dimensions
    public Tensor(int[] sizes) {
        throw new NotYetImplemented();
    }
 
    // return tensor with specified dimensions and strides
    public Tensor(int[] sizes, int strides[]) {
        throw new NotYetImplemented();
    }
    
    // return tensor using existing storage [offset sizes [stride]]
    public Tensor(double[] storage) {throw new NotYetImplemented();}
    public Tensor(double[] storage, int offset, int[] sizes) {throw new NotYetImplemented(); }
    public Tensor(double[] storage, int offset, int[] sizes, int[] strides) {throw new NotYetImplemented();}
    
    
    // not in Torch.Tensor; added for convenience
    public Tensor(double[] storage, int nDimensions, int offset, int size0, int size1, int stride0, int stride1) {
        this.storage = storage;
        this.nDimensions = nDimensions;
        this.offset = offset;
        this.size0 = size0;
        this.size1 = size1;
        this.stride0 = stride0;
        this.stride1 = stride1;
    }
    
    // return tensor using existing storage
    public Tensor(double[] storage, int offset, int size0) {throw new NotYetImplemented();}
    public Tensor(double[] storage, int offset, int size0, int size1) {throw new NotYetImplemented();}
    
    // assure contigous allocation
    // - if that is continous, return that
    // - otherwise, return a deep copy (that does not share storage)
    public static Tensor continuous(Tensor that) {throw new NotYetImplemented();}
    
    ///////////////////// inquiring and changing type
    // torch7.tensor implements methods to return the name of the type
    // none of these are implemented here, as java has methods for determining class name
    //
    // torch7.tensor provides typeAs(Tensor): Tensor for conversion among Tensor types
    // not implemented here, as there is only one Tensor double, a doubleStorage type
    
    /////////////////////  querying size and structure
    // use the java conventions for getter and setter names, resulting in names
    // that differ from the torch7.Tensor API
    
    // return number of dimensions
    public int getNDimensions() {return nDimensions;}
    
    // return size of specified dimension
    public int getSize(int dim) {
        if (nDimensions == 0) {
            throw new IllegalArgumentException("0D tensor has no sizes; this=" + this);
        }
        if (nDimensions == 1) {
            if (dim == 0)
                return size0;
            throw new IllegalArgumentException("illegal dim=" + dim + " this=" + this);
        }
        if (nDimensions == 2) {
            if (dim == 0)
                return size0;
            if (dim == 1)
                return size1;
            throw new IllegalArgumentException("illegal dim=" + dim + " this=" + this);
        }
        throw new RuntimeException("bad Tensor; this=" + this);
    }
    
    // return array of sizes
    public int[] getSize() {
        int[] result = new int[nDimensions];
        if (nDimensions == 1) {
            result[0] = size0;
        }
        else if (nDimensions == 2) {
            result[0] = size0;
            result[1] = size1;
        }
        else 
            throw new RuntimeException("bad Tensor; this=" + this);
        return result;
    }
    
    // return jump necessary to go from one element to next in the specified dimension
    public int getStride(int dim) {
        if (nDimensions == 1) {
            if (dim == 0)
                return stride0;
            throw new IllegalArgumentException("illegal dim=" + dim + " this=" + this);
        }
        if (nDimensions == 2) {
            if (dim == 0)
                return stride0;
            if (dim == 1)
                return stride1;
            throw new IllegalArgumentException("illegal dim=" + dim + " this=" + this);
        }
        throw new RuntimeException("bad Tensor; this=" + this);
    }
    
    // return all the strides
    public int[] getStride() {
        int[] result = new int[nDimensions];
        if (nDimensions == 1) {
            result[0] = stride0;
        }
        else if (nDimensions == 2) {
            result[0] = stride0;
            result[1] = stride1;
        }
        else 
            throw new RuntimeException("bad Tensor; this=" + this);
        return result;
    }
    
    // return reference to underlying storage (not a copy of the storage)
    public double[] getStorage() {
        return storage;
    }
    
    // return true iff elements are contiguous in the storage
    public boolean isContinguous() {throw new NotYetImplemented();}
    
    // return number of elements
    // this may differ from the size of the underlying storage
    public int getNElements() {
        if (nDimensions == 1)
            return size0;
        if (nDimensions == 2)
            return size0 * size1;
        throw new RuntimeException("bad Tensor; this=" + this);
    }
    
    // return offset
    public int getOffset() {
        return offset;
    }
    
    //////////////////// querying elements
    // java does not have C++'s operator overloading
    // hence this implementation follows the java getter and setter naming rules
    //
    // Only double storage is implemented. A double has 53 or 54 bits of precision, sufficient
    // to store all the java primitive types except for long, which can need 64 bits, but may
    // need less.
    // 
    // This implementation provides setLong() and getLong() that store and retrieve long values
    // that can be stored in doubles without loss of precision. If the user attempts to store 
    // or retrieve another kind of long, a LossOfPrecision exception is thrown
    
    public void set(int index0, double value) {
        if (nDimensions != 1)
            throw new IllegalArgumentException("nDimensions != 1; this=" + this);
        
        if (index0 < 0)
            throw new IllegalArgumentException("negative index0=" + index0 + " ; this=" + this);
        if (index0 >= size0)
            throw new IllegalArgumentException("index0 exceeds dimension; index0=" + index0 + " ; this=" + this);

        final int index = offset + stride0 * index0;
        if (index >= storage.length)
            throw new IllegalArgumentException(
                    "index into storage exceeds storage length; index=" + index +
                    " ; size0=" + size0 +
                    " ; this=" + this);
        
        storage[index] = value;
    }
    
    public void setLong(int index, long value) {
        double previousValue = get(index);
        set(index, (double) value);
        if (value == (long) get(index))
            return;
        set(index, previousValue);
        throw new LossOfPrecision("value (" + value + ") is not exactly representable as a double");
    }
    
    public double get(int index0) {
        if (nDimensions != 1)
            throw new IllegalArgumentException("nDimensions != 1; this=" + this);
        
        if (index0 < 0)
            throw new IllegalArgumentException("negative index0=" + index0 + " ; this=" + this);
        if (index0 >= size0)
            throw new IllegalArgumentException("index0 exceeds dimension; index0=" + index0 + " ; this=" + this);

        final int index = offset + stride0 * index0;
        if (index >= storage.length)
            throw new IllegalArgumentException(
                    "index into storage exceeds storage length; index=" + index +
                    " ; size0=" + size0 +
                    " ; this=" + this);
        
        return storage[index];
    }
    
    public long getLong(int index) {
        double doubleValue = get(index);
        long longValue = (long) doubleValue;
        double value = (double) doubleValue;
        if (value == doubleValue)
            return longValue;
        throw new LossOfPrecision("double value ( " + doubleValue + ") is not exactly representable as a long");
    }
    
    public double get(int index0, int index1) {
        if (nDimensions != 2)
            throw new IllegalArgumentException("nDimensions != 1; this=" + this);
        
        if (index0 < 0)
            throw new IllegalArgumentException("negative index0=" + index0 + " ; this=" + this);
        if (index0 >= size0)
            throw new IllegalArgumentException("index0 exceeds dimension; index0=" + index0 + " ; this=" + this);

        if (index1 < 0)
            throw new IllegalArgumentException("negative index1=" + index1 + " ; this=" + this);
        if (index1 >= size1)
            throw new IllegalArgumentException("index1 exceeds dimension; index1=" + index1 + " ; this=" + this);
        
        final int index = offset + stride0 * index0 + stride1 * index1;
        if (index >= storage.length)
            throw new IllegalArgumentException(
                    "index into storage exceeds storage length; index=" + index + 
                    " ; size0=" + size0 +
                    " ; size1=" + size1 +
                    " ; this=" + this);
        
        return storage[index];
    }
    
    // get a long value without loss of precision
    public long getLong(int index0, int index1) {
        double doubleValue = get(index0, index1);
        long longValue = (long) doubleValue;
        double value = (double) doubleValue;
        if (value == doubleValue)
            return longValue;
        throw new LossOfPrecision("double value ( " + doubleValue + ") is not exactly representable as a long");
    }
    
    // set a long value without loss of precision
    public void setLong(int index0, int index1, long value) {
        double previousValue = get(index0, index1);
        set(index0, index1, (double) value);
        if (value == (long)get(index0, index1))
            return;
        set(index0, index1, previousValue);
        throw new LossOfPrecision("value (" + value + ") is not exactly representable as a double");
    }
    
    
    public void set(int index0, int index1, double value) {
        final boolean logging = false;
        Log log = new Log("Tensor.set", logging);
        if (nDimensions != 2)
            throw new IllegalArgumentException("nDimensions != 1; this=" + this);
        
        if (index0 < 0)
            throw new IllegalArgumentException("negative index0=" + index0 + " ; this=" + this);
        if (index0 >= size0)
            throw new IllegalArgumentException("index0 exceeds dimension; index0=" + index0 + " ; this=" + this);

        if (index1 < 0)
            throw new IllegalArgumentException("negative index1=" + index1 + " ; this=" + this);
        if (index1 >= size1)
            throw new IllegalArgumentException("index0 exceeds dimension; index1=" + index1 + " ; this=" + this);
        
        final int index = offset + stride0 * index0 + stride1 * index1;
        if (logging)
            log.println("index0:" + index0 + " index1:" + index1 + " index:" + index);
        if (index >= storage.length)
            throw new IllegalArgumentException(
                    "index into storage exceeds storage length; index=" + index + 
                    " ; size0=" + size0 +
                    " ; size1=" + size1 +
                    " ; this=" + this);
        
        storage[index] = value;
    }
    
    ///////////////// referencing a tensor to existing tensor
    
    // the Torch name for this method is "set"
    public Tensor setStorage(Tensor that) {
        this.storage = that.storage;
        return this;
    }
    
    public Tensor setStorage(double[] array, int offset, int[] sizes, int strides[]) {
        throw new NotYetImplemented();
    }
 
    public Tensor setStorage(double[] array, int size0) {
        throw new NotYetImplemented();
    }
    
    public Tensor setStorage(double[] array, int size0, int size1) {
        throw new NotYetImplemented();
    }
    
    ////////////////////// copying and initializing
    
    // return new instance construct from argument list
    public static Tensor new1DInstance(Double...values) {
        Tensor result = new Tensor(values.length);
        for (int index = 0; index < values.length; index++)
            result.set(index, values[index]);
        return result;
    }
    
    // Torch offers method copy
    // Instead, we offer a static factory method that returns a deep copy
    // as this is the preferred java idiom
    public static Tensor newInstance(Tensor that){
        if (that.nDimensions == 1) {
            final int size0 = that.getSize(0);
            Tensor result = new Tensor(size0);
            for (int i = 0; i < size0; i++)
                result.set(i, that.get(i));
            return result;
        }
        else if (that.nDimensions == 2) {
            final int size0 = that.getSize(0);
            final int size1 = that.getSize(1);
            Tensor result = new Tensor(size0,size1);
            for (int i = 0; i < size0; i++)
                for (int j = 0; j < size1; j++)
                    result.set(i, j, that.get(i,j));
            return result;
        }
        else
            throw new RuntimeException("bad Tensor; that=" + that);
    }
    
    // fill with specified value
    public Tensor fill(double value) {
        final int nDimensions = this.getNDimensions();
        if (nDimensions == 1) {
            for (int i = 0; i < this.getSize(0); i++)
                this.set(i, value);
        }
        else if (nDimensions == 2) {
            for (int i = 0; i < this.getSize(0); i++)
                for (int j = 0; j < this.getSize(1); j++)
                    this.set(i, j, value);
        }
        else 
            throw new RuntimeException("bad Tensor; this=" + this);
        return this;
    }
    
    // fill with zeroes; not that if a new storage was created, java has already set it to zeroes
    public Tensor zero() {
        return this.fill(0);
    }
    
    /////////////////////// resizing
    // When resizing to a larger size, the underlying storage is resized to fit all elements.
    // When resizing to a smaller size, the underlying storage is not resized.
    // After resizing, the strides may have changed completely.
    
    public Tensor resizeAs(Tensor that) {throw new NotYetImplemented();}
    
    public Tensor resize(int size0) {throw new NotYetImplemented();}
    
    public Tensor resize(int size0, int size1) {throw new NotYetImplemented();}
    
    public Tensor resize(int[] sizes) {throw new NotYetImplemented();}
    
    ////////////////// extracting sub-tensors
    // Use the same storage
    
    // return new tensor with narrowed version of current one:
    // dimension dim is narrowed from index to index+size-1
    // NOTE: perhaps implement narrowRows(..) and narrowColumns(...) for 2D tensors
    public Tensor narrow(int dimension, int index, int size) {throw new NotYetImplemented();}
    
    // return result of a series of narrows
    public Tensor sub(int dimesion0start, int dimension0end) {throw new NotYetImplemented();}
    
    public Tensor sub(
            int dimesion0start, int dimension0end,
            int dimenion1start, int dimenions1end) {
        throw new NotYetImplemented();
    }
    
    // return new tensor that is a slice at given index in dimension dim
    // returned tensor has one less dimension
    // cannot select on a 1D tensor
    public Tensor select(int dimension, int index) {
        if (nDimensions == 1)
            throw new IllegalArgumentException("cannot select on 1D tensor; this=" + this);
        if (nDimensions == 2) {
            if (dimension == 0)
                return this.selectRow(index);
            else if (dimension == 1) 
                return this.selectColumn(index);
            else
                throw new IllegalArgumentException("dimension exceeds number of dimensions; dimension=" + dimension + " ; this=" + this);
        }
        throw new IllegalArgumentException("only 1D and 2D implemented so far; dimension=" + dimension + " ; this=" + this);
    }
    
    // return row view of underlying storage
    // not in Torch.Tensor
    public Tensor selectRow(int index) {
        Log log = new Log("Tensor.selectRow", false);
        log.println("this:" + this);
        log.println("index:" + index);
        if (this.nDimensions != 2)
            throw new IllegalArgumentException("this is not 2D; this=" + this);
        if (index < 0)
            throw new IllegalArgumentException("index < 0; index=" + index);
        if (index >= size0)
            throw new IllegalArgumentException("index exceeds first dimension limit; index=" + index);
        Tensor result = new Tensor(this.storage, 1, this.offset + this.stride0 * index, this.size1, 0, this.stride1, 0);
        log.println("result:" + result);
        return result;
    }
    
    // return row view of underlying storage
    // not in Torch.Tensor
    public Tensor selectColumn(int index) {
        final int numElements = this.getSize(0);
        Tensor result = new Tensor(numElements);
        for (int i = 0 ; i < numElements; i++) 
            result.set(i, this.get(i, index));
        return result;
    }
    
    ///////////////// manipulating tensor view
    // return a Tensor with another view of the same storage
    
    // return Tensor with dim1 and dim2 swapped
    public Tensor transpose(int dim1, int dim2) {throw new NotYetImplemented();}
    
    // return transpose of a 2D tensor
    public Tensor t() {
        if (nDimensions != 2)
            throw new IllegalArgumentException("must be a 2D tensor; this=" + this);
        
        final int rows = this.getSize(0);
        final int columns = this.getSize(1);
        
        return new Tensor(this.getStorage(), this.nDimensions, this.offset, columns, rows, 1, columns);
    }
    
    // return tensor that contains all slices of given size in given dimension
    // step between two slices is given by step
    public Tensor unfold(int dimension, int size, int step) {throw new NotYetImplemented();}
    
    /////////////////// applying function (functor) to tensor

    
    // mutate this by applying function to each element
    interface Functor {
        double apply(double element);
    }
    
    public Tensor apply(Functor f) {throw new NotYetImplemented();}
    
    // mutate this by applying function paired elements of this and that
    // number of elements of both tensors must match, but sizes do not matter
    interface Functor2 {
        public double apply(double element1, double element2);
    }
    
    public Tensor map(Tensor that, Functor2 f) {throw new NotYetImplemented();}
    
    // mutate this by applying function paired elements of this and that and other
    // number of elements of both tensors must match, but sizes do not matter
    interface Functor3 {
        double apply(double element1, double element2, double element3);
    }
    
    public Tensor map(Tensor that, Functor3 f) {throw new NotYetImplemented();}
    
    ///////////////// math functions: construction and extraction
    
    // concatenate x1 and x2 and specified dimension (default 1)
    public static Tensor cat(Tensor x1, Tensor x2){throw new NotYetImplemented();}
    public static Tensor cat(Tensor x1, Tensor x2, int dimension) {throw new NotYetImplemented();}
    
    // return diagonal matrix constructed from elements of x
    public static Tensor diag(Tensor x) {throw new NotYetImplemented();}
    
    // return identity matrix with ones on diagonals and zeroes elsewhere
    public static Tensor eye(int n) {throw new NotYetImplemented();}
    public static Tensor eye(int m, int n) {throw new NotYetImplemented();}
    
    // return 1D tensor with n (default 100) equally spaces points between a and b
    public static Tensor linSpace(int a, int b) {throw new NotYetImplemented();}
    public static Tensor linSpace(int a, int b, int n) {throw new NotYetImplemented();}
    
    // return 1D tensor with n (default 50) equally spaced points between a and b
    public static Tensor logSpace(int a, int b) {throw new NotYetImplemented();}
    public static Tensor logSpace(int a, int b, int n) {throw new NotYetImplemented();}
    
    // return tensor filled with ones
    public static Tensor ones(int n)  {throw new NotYetImplemented();}
    public static Tensor ones(int m, int n)  {throw new NotYetImplemented();}
    
    // return tensor filled with random number sampled uniformly from [0,1]
    public static Tensor rand(int n)  {throw new NotYetImplemented();}
    public static Tensor rand(int m, int n)  {throw new NotYetImplemented();}
    
    // return tensor filled with random number sampled from normal distribution with mean 0, std dev 1
    public static Tensor randn(int n)  {throw new NotYetImplemented();}
    public static Tensor randn(int m, int n)  {throw new NotYetImplemented();}
    
    // return tensor with values in range [a,b]
    public static Tensor /* 1D */ range(int a, int b){throw new NotYetImplemented();}
    public static Tensor /* 2D */ range(int a, int b, int increment){throw new NotYetImplemented();}
    
    // return random permutation
    public static Tensor randPerm(int n)  {throw new NotYetImplemented();}
    
    // reshape, copying elements into new Tensor
    // reuse existing storage
    // note: assumed right-most (!) index varies most rapidly
    // this is different from the element-by-element operations where shapes differ
    // TODO: figure out if these should be unified (examine torch7 source code for this)
    public void reshape(int m, int n) {
        // must have same number of elements before and after
        int newNElements = m * n;
        if (this.getNElements() != newNElements)
            throw new IllegalArgumentException("different number of elements; nElements =" + this.getNElements() + "; m=" + m + "; n=" + n);
        this.nDimensions = 2;
        this.size0 = m;
        this.size1 = n;
        this.stride0 = n;
        this.stride1 = 1;
        // Does the above work with offsets?
    }
    
    public static Tensor reshape(Tensor that, int m, int n) {
        throw new NotYetImplemented();
    }
    
    // return lower and upper triangular parts of that
    public static Tensor tril(Tensor that) {throw new NotYetImplemented();}
    public static Tensor triu(Tensor that) {throw new NotYetImplemented();}
    
    // return tensor of zeros
    public static Tensor zeros(int n)  {throw new NotYetImplemented();}
    public static Tensor zeros(int m, int n)  {throw new NotYetImplemented();} 
    
    ///////////////// math functions: element-wise operations
    // apply only to elements in the view, not to every element in the storage
    // don't implement torch7's (result,OTHER_PARAMETERS), as java is call be value
    // and the work-around is obscure
    
    public Tensor abs() {throw new NotYetImplemented();}  
    public static Tensor abs(Tensor x) {throw new NotYetImplemented();}
    
    public Tensor acos() {throw new NotYetImplemented();}
    public static Tensor acos(Tensor x) {throw new NotYetImplemented();} 
    
    
    public Tensor asin() {throw new NotYetImplemented();}
    public static Tensor asin(Tensor x) {throw new NotYetImplemented();}  
    
    public Tensor atan() {throw new NotYetImplemented();}
    public static Tensor atan(Tensor x) {throw new NotYetImplemented();}    
    
    public Tensor tan() {throw new NotYetImplemented();}
    public static Tensor tan(Tensor x) {throw new NotYetImplemented();}  
    
    public Tensor ceil() {throw new NotYetImplemented();}
    public static Tensor ceil(Tensor x) {throw new NotYetImplemented();}  
    
    public Tensor cos() {throw new NotYetImplemented();}
    public static Tensor cos(Tensor x) {throw new NotYetImplemented();}    
    
    public Tensor cosh() {throw new NotYetImplemented();}
    public static Tensor cosh(Tensor x) {throw new NotYetImplemented();}    
    
    public Tensor exp() {throw new NotYetImplemented();}
    public static Tensor exp(Tensor x) {throw new NotYetImplemented();}    
    
    public Tensor floor() {throw new NotYetImplemented();}
    public static Tensor floor(Tensor x) {throw new NotYetImplemented();}  
    
    // mutate this = log(this)
    public Tensor log() {
        Tensor result = log(this);
        setEachElement(this, result);
        return this;
    }
    
    // return log(x)
    public static Tensor log(Tensor x) {
        Log log = new Log("Tensor.log(Tensor)", false);
        final int dimensions = x.getNDimensions();
        Tensor result;
        if (dimensions == 1) {
            final int size0 = x.getSize(0);
            result = new Tensor(size0);
            for (int i = 0; i < size0; i++)
                result.set(i, Math.log(x.get(i)));
        }
        else if (dimensions == 2) {
            final int size0 = x.getSize(0);
            final int size1 = x.getSize(1);
            log.format("size0=%d size1=%d%n", size0, size1);
            result = new Tensor(size0,size1);
            for (int i = 0; i < size0; i++)
                for (int j = 0; j < size1; j++) {
                    result.set(i, j, Math.log(x.get(i, j)));
                    log.format("result[%d,%d]=%f%n", i, j, result.get(i,j));
                }
        }
        else
            throw new RuntimeException("bad tensor; x=" + x);
        log.println("result:" + result);
        return result;
    }
    
    // log (x + 1) with more precision that standard log()
    // Q: how is this implemented?
    public Tensor log1p() {throw new NotYetImplemented();}  
    public static Tensor log1b(Tensor x) {throw new NotYetImplemented();}
    
    public Tensor pow(double value) {throw new NotYetImplemented();}
    public static Tensor pow(Tensor x) {throw new NotYetImplemented();}
    
    public Tensor sin() {throw new NotYetImplemented();}
    public static Tensor sin(Tensor x) {throw new NotYetImplemented();}    
    
    public Tensor sinh() {throw new NotYetImplemented();}
    public static Tensor sinh(Tensor x) {throw new NotYetImplemented();} 
    
    public Tensor sqrt() {throw new NotYetImplemented();}
    public static Tensor sqrt(Tensor x) {throw new NotYetImplemented();}  
    
    public Tensor tanh() {throw new NotYetImplemented();}
    public static Tensor tanh(Tensor x) {throw new NotYetImplemented();}   

    //////////////////// basic operations
    // element wise
    // torch7.tensor provides mutating version that update this
    // this implementation does as well, but only for operations where a name clash would not result
    // torch7.tensor provides API that set the first parameter, but this implementation does not
    
    //// add
    
    static class Add implements Functor2 {
        public double apply(double x, double y) {
            return x + y;
        }
    }
    
    // mutate this  this + value
    public Tensor add(double value) { // mutate this
        Log log = new Log("Tensor.add(double)", false);
        setEachElement(this, add(this, value));
        log.println("this:" + this);
        return this;
        }
    
    // mutate this += value * x
    public Tensor add(double value, Tensor x) {throw new NotYetImplemented();}
    
    // return x + value
    public static Tensor add(Tensor x, double value) {
        return applyCorresponding(x, value, new Add());
    }
    
    // return x + y
    public static Tensor add(Tensor x, Tensor y) {
        Log log = new Log("Tensor.add", false);
        log.println("x:" + x);
        log.println("y:" + y);
        Tensor result = applyCorresponding(x, y, new Add());
        log.println("result:" + result);
        return result;
    }
    
    // return x + (value * y)
    public static Tensor add(Tensor x, double value, Tensor y){throw new NotYetImplemented();} 
    
    //// mul
    
    // mutate this = this * mul
    public Tensor mul(double value) {throw new NotYetImplemented();}
    
    // return x * value
    public static Tensor mul(Tensor x, double value) {throw new NotYetImplemented();}
    
    //// cmul
    
    // mutate this = this / x
    public Tensor cmul(Tensor x) {throw new NotYetImplemented();}
    
    // return x * y
    public static Tensor cmul(Tensor x, Tensor y) {throw new NotYetImplemented();}
    
    //// addcmul
    
    // return value * x * y
    public static Tensor addcmul(double value, Tensor x, Tensor y) {throw new NotYetImplemented();}
    
    //// div
    
    static class Div implements Functor2 {
        public double apply(double x, double y) {
            return x / y;
        }
    }
    
    // mutate this = this / value
    public Tensor div(double value) {
        setEachElement(this, add(this, value));
        return this;
    }
    
    // return x / value
    public static Tensor div(Tensor x, double value) {
        Log log = new Log("Tensor.div", false);
        Tensor result = applyCorresponding(x, value, new Div());
        log.println("result:" + result);
        return result;
    }
    
    //// cdiv
    
    // this /= x
    public Tensor cdiv(Tensor x) {throw new NotYetImplemented();}
    
    // return x / y
    public static Tensor cdiv(Tensor x, Tensor y) {
        Log log = new Log("Tensor.cdiv", false);
        final int nElements = x.getNElements();
        if (nElements != y.getNElements())
            throw new IllegalArgumentException("x and y must have same number elements; x=" + x + " ;y=" + y);
        class Cdiv implements Functor2 {
            public double apply(double x, double y) {return x / y;}
        }
        Tensor result = applyCorresponding(x, y, new Cdiv());
        log.println("result:" + result);
        return result;
    }
    
    //// addcdiv
    
    // mutate this = this / y
    public Tensor addcdiv(Tensor x) {throw new NotYetImplemented();}
    
    // return value * (x / y)
    public static Tensor addcdiv(double value, Tensor x, Tensor y) {throw new NotYetImplemented();}
    
    //// dot
    
    // dotProduct(this, x)
    public double dot(Tensor x) {
        return dot(x, this);
    }
    
    public static double dot(Tensor x, Tensor y) {
        if (x.getNDimensions() != 1) 
            throw new IllegalArgumentException("x must be 1D; x=" + x);
        if (y.getNDimensions() != 1) 
            throw new IllegalArgumentException("y must be 1D; y=" + y);
        
        final int nElements = x.getNElements();
        if (nElements != y.getNElements())
            throw new IllegalArgumentException("x and y must have same number of elements; x=" + x + " ;y=" + y);
        
        double result = 0;
        for (int i = 0; i < nElements; i++)
            result += x.get(i) * y.get(i);
        
        return result;
    }
    
    ////// tensor-tensor multiplication
    
    //// matrix-vector multiplications: return v1 * vec1 + v2 * mat * vec2
    public static Tensor addmv(double v1, Tensor vec1, double v2, Tensor mat, Tensor vec2) {throw new NotYetImplemented();}
    
    // matrix-vector multiplication: this += value * mat * vec
    // Note: historic version in torch5.Tensor, retained because some code uses it
    public Tensor addT2DotT1(double value, Tensor mat, Tensor vec){
        Log log = new Log("Tensor.addT2DotT1", false);
        if (mat.getNDimensions() != 2)
            throw new IllegalArgumentException("mat must have dim 2; mat=" + mat);
        if (vec.getNDimensions() != 1)
            throw new IllegalArgumentException("vec must have dim 1; vec=" + vec);
        
        // mat is m x p
        final int m = mat.getSize(0);
        final int p = mat.getSize(1);
        
        // vec is conceived of as p x 1
        if (vec.getSize(0) != p)
            throw new IllegalArgumentException("vec must have " + p + " elements; vec=" + vec);
        
        // this must be m x 1 or a vector with m elements
        log.println("this:" + this);
        log.println("nDimensions:" + this.getNDimensions());
        final boolean thisIsVector = this.getNDimensions() == 1;
        if (thisIsVector && this.getSize(0) != m)
            throw new IllegalArgumentException("this must have " + m + " elements; this=" + this);
        else if (!thisIsVector && !(this.getSize(0) == m && this.getSize(1) == 1))
            throw new IllegalArgumentException("this must be " + m + " x 1; this=" + this);

        
        for (int i = 0; i < m; i++) {
                double sum = 0;
                for (int k = 0; k < p; k++)
                    sum += mat.get(i,k) * vec.get(k);
                if (thisIsVector)
                    this.set(i, this.get(i) + value * sum);
                else
                    this.set(i, 0, this.get(i, 0) + value * sum);
            }
        return this;
    }
    
    // outer product: this += v1 * mat_ij + v2 * vec1_i * vec2_j
    public static Tensor addr(double v1, Tensor mat, double v2, Tensor vec1, Tensor vec2) {throw new NotYetImplemented();}
    
    // matrix-matrix multiplication: this v1 * m + v2 * mat1 * mat2
    public static Tensor addmm(double v1, Tensor m, double v2, Tensor mat1, Tensor mat2) {throw new NotYetImplemented();}
    
    // matrix-matrix multiplication: this += value * mat1 * mat2; return this
    // historic version, based on torch5.Tensor
    // retained because it is used
    public Tensor addT2DotT2(double value, Tensor mat1, Tensor mat2){
        final boolean logging = false;
        Log log = new Log("Tensor.addT2DotT2", logging);
        if (mat1.getNDimensions() != 2)
            throw new IllegalArgumentException("mat1 must have dim 2; mat1=" + mat1);
        if (mat2.getNDimensions() != 2)
            throw new IllegalArgumentException("mat2 must have dim 2; mat2=" + mat2);
        
        // mat is m x p
        final int m = mat1.getSize(0);
        final int p = mat1.getSize(1);
        
        // mat is p x n
        if (mat2.getSize(0) != p)
            throw new IllegalArgumentException("mat2 must be " + p + " x n; mat2" + mat2);
        final int n = mat2.getSize(1);
        
        // this must be m x n
        if (this.getSize(0) != m)
            throw new IllegalArgumentException("this must be " + m + " x " + n + " ; this=" + this);
        if (this.getSize(1) != n)
            throw new IllegalArgumentException("this must be " + m + " x " + n + " ; this=" + this);
        
        for (int i = 0; i < m; i++)
            for (int j = 0; j < n; j++) {
                double sum = 0;
                for (int k = 0; k < p; k++) {
                    if (logging)
                        log.format("mat1[%d,%d]= %5.2f mat2[%d,%d]= %5.2f%n", i, k, mat1.get(i,k), k, j, mat2.get(k, j));
                    sum += mat1.get(i,k) * mat2.get(k, j);
                }
                if (logging) {
                    log.format("sum[%d,%d]=%5.2f%n", i, j, sum);
                    log.format("this[%d,%d]=%5.2f%n", i, j, this.get(i,j));
                }
                this.set(i, j, this.get(i, j) + value * sum);
                
            }
        return this;
    }
    
    // matrix-vector multiplication: this = mat * vec
    public Tensor mv(Tensor mat, Tensor vec) {throw new NotYetImplemented();}
    
    // matrix-matrix multiplication: this = mat1 * mat2
    public Tensor mm(Tensor mat1, Tensor mat2) {throw new NotYetImplemented();}
    
    // outer product: this = outerProduct(vec1, vec2)
    public Tensor ger(Tensor vec1, Tensor vec2) {throw new NotYetImplemented();}
    
    ///////////////////////// column-wise, row-wise, and dimension-wise operations
    
    // cross-product: vec1 and vec2 must be 3 element vectors
    public static Tensor cross(Tensor vec1, Tensor vec2) {throw new NotYetImplemented();}
    
    // cumulative sum of elements of x of dimension d (default is first dimension, numbered 0)
    public static Tensor cumsum(Tensor x) {throw new NotYetImplemented();}
    public static Tensor cumSum(Tensor x, int d) {throw new NotYetImplemented();}
    
    // maximum element in dimension d or over all elements if d not supplied
    public static double max(Tensor x) {throw new NotYetImplemented();}
    public static double max(Tensor x, int d) {throw new NotYetImplemented();} // d=0 ==> across rows
    
    // mean element
    public static double mean(Tensor x) {
        double sum = 0;
        if (x.nDimensions == 1) {
            for (int i = 0; i < x.size0; i++)
                sum += x.get(i);
        }
        else if (x.nDimensions == 2) {
            for (int i = 0; i < x.size0; i++)
                for (int j = 0; j < x.size1; j++)
                    sum += x.get(i,j);
        }
        else 
            throw new RuntimeException("bad Tensor; x=" + x);
        return sum / x.getNElements();
    }
    
    // mean across elements in dimension d
    public static double mean(Tensor x, int d) {throw new NotYetImplemented();}
    
    // minimum element in dimension d or of all if d not supplied
    public static double min(Tensor x) {throw new NotYetImplemented();}
    public static double min(Tensor x, int d) {throw new NotYetImplemented();}
    
    // product of all elements
    public static double prod(Tensor x) {throw new NotYetImplemented();}
    public static double prod(Tensor x, int d) {throw new NotYetImplemented();}
    
    // sort(x) return new Tensor of sorted rows of x
    // sortIndex(x) returns new Tensor of sorted indices of x
    public static Tensor sort(Tensor x) {throw new NotYetImplemented();}
    public static Tensor sortIndices(Tensor x) {throw new NotYetImplemented();}
    
    // standard deviation: torch7 version
    // useNWeighting: if true, weight by n
    //                if false, weight by n - 1
    public static double std(Tensor x) {
        return Math.sqrt(Tensor.var(x));
    } 
    public static double std(Tensor x, boolean useWeightingN) {throw new NotYetImplemented();}
    public static double std(Tensor x, boolean useWeightingN, int d) {throw new NotYetImplemented();}
    
    // sum over elements
    public static double sum(Tensor x) {throw new NotYetImplemented();}
    public static double sum(Tensor x, int d) {throw new NotYetImplemented();}
    
    // variance:
    public static double var(Tensor x) {
        Log log = new Log("Tensor.var", false);
        final double mean = Tensor.mean(x);
        // compute E(this - mean)^2)
        double sumSquaredDeviations = 0;
        if (x.nDimensions == 1) {
            for (int i = 0; i < x.size0; i++) {
                final double deviation = x.get(i) - mean;
                log.println("i:" + i + " deviation:" + deviation);
                sumSquaredDeviations += deviation * deviation;
            }

        }
        else if (x.nDimensions == 2) {
            for (int i = 0; i < x.size0; i++)
                for (int j = 0; j < x.size1; j++) {
                    final double deviation = x.get(i,j) - mean;
                    sumSquaredDeviations += deviation * deviation;
                }
        }
        else 
            throw new RuntimeException("bad Tensor; x=" + x);
        log.println("sumSquaredDeviations:" + sumSquaredDeviations);
        log.println("getNElements():" + x.getNElements());
        return sumSquaredDeviations / x.getNElements();
    }
    
    /////////////////////// tensor-wide operations
    
    // return 2 norm
    public static double norm(Tensor x) {throw new NotYetImplemented();}
    
    // return p norm
    public static double norm(Tensor x, double p){throw new NotYetImplemented();}
    

    private static class DistVisitor implements Visitor {
        private double norm;
        private double oneOverNorm;
        private double sumPoweredDifferences;
        
        public DistVisitor(double norm) {
            if (norm <= 0)
                throw new IllegalArgumentException("norm must be positive; norm=" + norm);
            this.norm = norm;
            this.oneOverNorm = 1.0 / norm;
        }
        
        @Override public void start(int dimensions, int size0, int size1) {
            this.sumPoweredDifferences = 0;
        }
        
        @Override public void visit(int i0, int i1, double x, double y) {
            Log log = new Log("Tensor.DistVisitor.visit", false);
            final double difference = Math.abs(x - y);
            log.format("x %f y %f abs difference %f%n", x, y, difference);
            sumPoweredDifferences += (oneOverNorm == 0.5) ? difference * difference : Math.pow(difference, norm);
        }
        
        @Override public void end() {}
        
        public double getDist() {
            Log log = new Log("Tensor.DistVisitor.getDist", false);
            log.format("sum powered differences %f  1/norm %f%n", sumPoweredDifferences, oneOverNorm);
            return (oneOverNorm == 2) ? Math.sqrt(sumPoweredDifferences) : Math.pow(sumPoweredDifferences, oneOverNorm);
        }
    }
    
    // return 2 norm of difference between x and y
    public static double dist(Tensor x, Tensor y) {
        final double norm = 2;
        DistVisitor distVisitor = new DistVisitor(norm);
        visitCorresponding(x, y, distVisitor);
        return distVisitor.getDist();
    }
    
    // return p norm of difference between this and given tensor
    public static double dist(Tensor x, Tensor y, double p) {
        DistVisitor distVisitor = new DistVisitor(p);
        visitCorresponding(x, y, distVisitor);
        return distVisitor.getDist();
    }
    
    // return trace (sum of diagonal elements)
    public static double trace(Tensor x) {throw new NotYetImplemented();}
    
    ///////////////////// convolution operators
    // a convolution is a cross-correlation of an input image (or images) with a kernel (or kernels)
    
    public static Tensor conv2(Tensor x, Tensor k, boolean performFullConvolution) {throw new NotYetImplemented();}
    public static Tensor xcorr2(Tensor x, Tensor k, boolean performFullConvolution) {throw new NotYetImplemented();}
    public static Tensor xconv3(Tensor x, Tensor k, boolean performFullConvolution) {throw new NotYetImplemented();}
    public static Tensor xcorr3(Tensor x, Tensor k, boolean performFullConvoluation) {throw new NotYetImplemented();}
    
    ////////////////////////////// eigenvalues, SVD, linear systems solutions
    // In torch7, these methods are implemented with an interface to LAPACK libraries
    
    // Solution to Ax = B
    // resultA will contain LU factorization of A
    // resultB will contain solution
    public static void gesv(Tensor resultB, Tensor resultA, Tensor b, Tensor a) {throw new NotYetImplemented();}
    
    // Solution of least squares and least norm problems for full rank A that is m x n
    // If n <= m, solve ||AX - B||_F
    // If n > m, solve min ||X||_F s.t. AX = B
    public static void gels (Tensor resultB, Tensor resultA, Tensor b, Tensor a) {throw new NotYetImplemented();}
    
    // calculate all eigenvalues and eigenvectors
    public static void eig(Tensor resultE, Tensor resultV, Tensor a, 
            boolean onlyDetermineEigenValue, boolean onlyUseLowerTriangularPortion) {throw new NotYetImplemented();}
    
    // singular value decomposition
    public static void svd(Tensor resu, Tensor ress, Tensor resv, Tensor a, boolean determineAllSingularValues)
    {throw new NotYetImplemented();}
    
    // inverse of square matrix
    public static void inverse(Tensor result, Tensor a) {throw new NotYetImplemented();}
    
    ///////////////////// logical operators on tensors
    // in torch7, these return a byte tensor, which this implementation 
    
    public static Tensor lt(Tensor a, Tensor b) {throw new NotYetImplemented();}
    public static Tensor le(Tensor a, Tensor b) {throw new NotYetImplemented();}
    public static Tensor gt(Tensor a, Tensor b) {throw new NotYetImplemented();}
    public static Tensor ge(Tensor a, Tensor b) {throw new NotYetImplemented();}
    public static Tensor eq(Tensor a, Tensor b) {throw new NotYetImplemented();}
    public static Tensor ne(Tensor a, Tensor b) {throw new NotYetImplemented();}

    ////////////////////////// private helper methods
    
    // element-by-element assignment x = y
    // mutate x
    // x and y may have different shapes but must have the same number of elements
    private void setEachElement(Tensor x, Tensor y) {
        Log log = new Log("setEachElement", true);
        if (x.getNElements() != y.getNElements())
            throw new IllegalArgumentException("different number of elements; x=" + x + " y=" + y);
        final int dimX = x.getNDimensions();
        final int dimY = y.getNDimensions();
        if (dimX == 1 && dimY == 1) {
            final int size0X = x.getSize(0);
            for (int i = 0; i < size0X; i++)
                x.set(i, y.get(i));
        }
        else if (dimX == 1 && dimY == 2) {
            final int size0X = x.getSize(0);
            Index2Visitor yVisitor = new Index2Visitor(y);
            for (int i = 0; i < size0X; i++) {
                Integer index0Y = 0;
                Integer index1Y = 0;
                yVisitor.next(index0Y, index1Y); // mutate both arguments
                x.set(i, y.get(index0Y, index1Y));
            }
        }
        else if (dimX == 2 && dimY == 1) {
            final int size0X = x.getSize(0);
            final int size1X = x.getSize(0);
            int index0Y = 0;
            for (int i = 0; i < size0X; i++)
                for (int j = 0; j < size1X; j++) {
                    x.set(i, j, y.get(index0Y));
                    index0Y++;
                }
        }
        else if (dimX == 2 && dimY == 2) {
            final int size0X = x.getSize(0);
            final int size1X = x.getSize(1);
            for (int i = 0; i < size0X; i++)
                for (int j = 0; j < size1X; j++) {
                    x.set(i, j, y.get(i,j));
                }
        }
        else
            throw new RuntimeException("bad code; x=" + x + " ;y=" + y);
    }
    
    // visit each element in raveled order
    // raveled order has left-most index varying most rapidly
    // API designed to allow construction of a result tensor
    private interface Visitor {
        // specify shape of the result
        public void start(int dimensions, int size0, int size1);
        
        // create element result[i0] or result[i0,i1]
        public void visit(int i0, int i1, double x, double y);
        
        // clean up
        public void end();
    }
    
    // visit corresponding elements in raveled order
    // sizes must be equal but shapes can be difference
    private static void visitCorresponding(Tensor x, Tensor y, Visitor visitor) {
        final int nElements = x.getNElements();
        if (nElements != y.getNElements())
            throw new IllegalArgumentException("different number of elements; x=" + x + " y=" + y);
        final int dimX = x.nDimensions;
        final int dimY = y.nDimensions;
        if (dimX == 1 && dimY == 1)
            visitCorresponding11(x, y, visitor);
        else if (dimX == 1 && dimY == 2)
            visitCorresponding12(x, y, visitor);
        else if (dimX ==2 && dimY == 1)
            visitCorresonding21(x, y, visitor);
        else if (dimX ==2 && dimY == 2)
            visitCorresponding22(x, y, visitor);
        else
            throw new IllegalArgumentException("bad dimensions; x=" + x + " y=" + y);
    }
    
    private static void visitCorresponding11(Tensor x, Tensor y, Visitor visitor) {
        final int xSize0 = x.getSize(0);
        visitor.start(1, xSize0, 0);
        for (int i = 0; i < xSize0; i++)
            visitor.visit(i, 0, x.get(i), y.get(i));
        visitor.end();
    }
    
    
    private static void visitCorresponding12(Tensor x, Tensor y, Visitor visitor) {
        visitor.start(1, x.getSize(0), 0);
        int xIndex = 0;
        int ySize0 = y.getSize(0);
        int ySize1 = y.getSize(1);
        // left-most index varies most rapidly
        for (int j = 0; j < ySize1; j++)
            for (int i = 0; i < ySize0; i++) {
                visitor.visit(i, j, x.get(xIndex), y.get(i,j));
                xIndex++;
            }
        visitor.end();
    }
    
    private static void visitCorresonding21(Tensor x, Tensor y, Visitor visitor) {
        visitor.start(1, x.getSize(0), x.getSize(1));
        int yIndex = 0;
        int xSize0 = x.getSize(0);
        int xSize1 = x.getSize(1);
        // left-most index varies most rapidly
        for (int j = 0; j < xSize1; j++)
            for (int i = 0; i < xSize0; i++) {
                visitor.visit(i, j, x.get(i, j), y.get(yIndex));
                yIndex++;
            }
        visitor.end();
    }
    
    private static void visitCorresponding22(Tensor x, Tensor y, Visitor visitor) {
        visitor.start(2, x.getSize(0), x.getSize(1));
        int ySize0 = y.getSize(0);
        int ySize1 = y.getSize(1);
        // left-most index varies most rapidly
        for (int j = 0; j < ySize1; j++)
            for (int i = 0; i < ySize0; i++) {
                visitor.visit(i, j, x.get(i,j), y.get(i,j));
            }
        visitor.end();
    }
    
    // apply a functor to each corresponding element
    // shape of result is same as shape of x
    // visit the indices in raveled order
    // in raveled order, the left most index varies most rapidly
    private static Tensor applyCorresponding(Tensor x, Tensor y, Functor2 f) {
        Log log = new Log("applyCorresponding", false);
        final int nElements = x.getNElements();
        if (nElements != y.getNElements())
            throw new IllegalArgumentException("different number of elements; x=" + x + " y=" + y);
        final int dimX = x.getNDimensions();
        final int dimY = y.getNDimensions();
        log.format("dimX=%d dimY=%d%n", dimX, dimY);
        if (dimX == 1 && dimY == 1) {
            final int size0X = x.getSize(0);
            Tensor result = new Tensor(size0X);
            for (int i = 0; i < size0X; i++)
                result.set(i, f.apply(x.get(i), y.get(i)));
            return result;
        }
        else if (dimX == 1 && dimY == 2) {
            final int size0X = x.getSize(0);
            Tensor result = new Tensor(size0X);
            IndicesInRaveledOrder yIndexer = new IndicesInRaveledOrder(y);
            for (int i = 0; i < size0X; i++) {
                result.set(i,  f.apply(x.get(i), y.storage[yIndexer.next()]));
            }
            return result;
        }
        else if (dimX == 2 && dimY == 1) {
            Tensor result = new Tensor(x.getSize(0), x.getSize(1));
            IndicesInRaveledOrder resultStorageIndices = new IndicesInRaveledOrder(result);
            IndicesInRaveledOrder xStorageIndices = new IndicesInRaveledOrder(x);
            IndicesInRaveledOrder yStorageIndices = new IndicesInRaveledOrder(y); 
            for (int i = 0; i < nElements; i++)
                result.storage[resultStorageIndices.next()] = f.apply(x.storage[xStorageIndices.next()], y.storage[yStorageIndices.next()]);
            return result;
        }
        else if (dimX == 2 && dimY == 2) {
            final int size0X = x.getSize(0);
            final int size1X = x.getSize(1);
            Tensor result = new Tensor(size0X,size1X);
            for (int i = 0; i < size0X; i++)
                for (int j = 0; j < size1X; j++) {
                    result.set(i, j, f.apply(x.get(i,j), y.get(i,j)));
                }
            return result;
        }
        else
            throw new RuntimeException("bad code; x=" + x + " ;y=" + y);
    }
    
    // apply a functor to each corresponding element
    // shape of result is same as shape of x
    // visit the indices in raveled order
    // in raveled order, the left most index varies most rapidly
    private static Tensor applyCorresponding(Tensor x, double value, Functor2 f) {
        Log log = new Log("applyCorresponding(Tensor,double)", false);
        final int nElements = x.getNElements();
        final int dimX = x.getNDimensions();
        log.format("dimX=%d %n", dimX);
        if (dimX == 1) {
            final int size0X = x.getSize(0);
            Tensor result = new Tensor(size0X);
            for (int i = 0; i < size0X; i++)
                result.set(i, f.apply(x.get(i), value));
            return result;
        }
        else if (dimX == 2) {
            final int size0X = x.getSize(0);
            final int size1X = x.getSize(1);
            Tensor result = new Tensor(size0X,size1X);
            for (int i = 0; i < size0X; i++)
                for (int j = 0; j < size1X; j++)
                    result.set(i, j, f.apply(x.get(i, j), value));
            return result;
        }
        else
            throw new RuntimeException("bad code; x=" + x);
    }
    
    // return offsets in storage for a traversal in ravelled order
    private static class IndicesInRaveledOrder {
        private int nextIndex0;
        private int nextIndex1;
        
        private int nDimensions;
        private int offset;
        private int size0;
        //private int size1;
        private int stride0;
        private int stride1;
        
        public IndicesInRaveledOrder(Tensor x) {
            this.nDimensions = x.nDimensions;
            this.offset = x.offset;
            this.size0 = x.size0;
            //this.size1 = x.size1;
            this.stride0 = x.stride0;
            this.stride1 = x.stride1;
            
            this.nextIndex0 = 0;
            this.nextIndex1 = 0;
        }
        
        // return next index in storage of a ravelled order traversal of x (in which first subscript varies most rapidly)
        public int next() {
            final boolean logDetails = false;
            Log log = new Log("Tensor.IndicesInRaveledOrder.next", false);
            int result;
            if (nDimensions == 1) {
                result = this.offset + nextIndex0 * stride0;
                nextIndex0++;
                return result;
            }
            else if (nDimensions == 2) {
                result = this.offset + nextIndex0 * stride0 + nextIndex1 * stride1;
                if (logDetails)
                    log.format("offset=%d nextIndex0=%d stride0=%d nextIndex1=%d stride1=%d result=%d%n",
                        offset, nextIndex0, stride0, nextIndex1, stride1, result);

                nextIndex0++;
                if (nextIndex0 == size0) {
                    nextIndex0 = 0;
                    nextIndex1++;
                }
                if (logDetails)
                    log.format("nextIndex0=%d nextIndex1=%d%n", nextIndex0, nextIndex1, result);
                log.println("storage index=" + result);
                return result;
            }
            else 
                throw new RuntimeException("bad nDimensions; nDimensions=" + nDimensions);
            
        }
    }
    
    
    
    
    

       

    
    
    
    
    
    

    
    
   
    
    
    
    

}
