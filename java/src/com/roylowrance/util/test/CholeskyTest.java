package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Cholesky;
import com.roylowrance.util.Tensor;

public class CholeskyTest {
	Tensor t;
	Cholesky c;
	Tensor b;

	@Before
	public void setUp() throws Exception {
		// this example is from 
		// http://math.fullerton.edu/mathews/n2003/CholeskyMod.html
		double[][] array2 = {
				{2, 1, 1, 3, 2},
				{1, 2, 2, 1, 1},
				{1, 2, 9, 1, 5},
				{3, 1, 1, 7, 1},
				{2, 1, 5, 1, 8}};
		t = Tensor.newInstanceFromArray(array2);
		c = new Cholesky(t);
		
		double[] array1 = {-2, 4, 3, -5, 1};
		b = Tensor.newInstanceFromArray(array1);
	}

	@Test
	public void testCholesky() {
	    final boolean display = false;
		// verify values from setUp's matrix
		Tensor el = c.getEl();
		// upper-right triangle is zeroes
		final int n = el.getSize(0); // number of rows
		assertEquals(5, n, 0);
		for (int i = 0; i < n; i++)
			for (int j = i + 1; j < n; j++)
				assertEquals(0, el.get(i,j), 0);
		// test specific values in other entries
		assertEquals(Math.sqrt(2), el.get(0,0), 0);
		
		assertEquals(1.0 / Math.sqrt(2), el.get(1,0), 0);
		assertEquals(Math.sqrt(3.0 / 2.0), el.get(1,1), 0);
		
		assertEquals(1.0 / Math.sqrt(2), el.get(2,0), 0);
		assertEquals(Math.sqrt(3.0 / 2.0), el.get(2,1), 1e-15);
		assertEquals(Math.sqrt(7), el.get(2,2), 0);
		
		assertEquals(3.0 / Math.sqrt(2.0), el.get(3,0), 0);
		assertEquals(-1.0 / Math.sqrt(6), el.get(3,1), 1e-15);
		assertEquals(0, el.get(3,2), 0);
		assertEquals(Math.sqrt(7.0 / 3.0), el.get(3,3), 1e-15);
		
		assertEquals(Math.sqrt(2), el.get(4,0), 1e-15);
		assertEquals(0, el.get(4,1), 1e-15);
		assertEquals(4.0 / Math.sqrt(7), el.get(4,2), 0);
		assertEquals(-2.0 * Math.sqrt(3.0 / 7.0), el.get(4,3), 1e-15);
		assertEquals(Math.sqrt(2), el.get(4,4), 1e-14);
		
		// The factorization should yield the original matrix after L * L^T
		if (display)
		    printTensor("L", el);
		
		Tensor elTranspose = Tensor.newInstance(el).t();
		if (display)
		    printTensor("L^T", elTranspose);
		Tensor b = new Tensor(n,n).addT2DotT2(1, el, elTranspose); // scaling factor is 1 (not 0!, which was a bug)
		for (int i = 0; i < t.getSize(0); i++)
			for (int j = 0; j < t.getSize(1); j++)
				assertEquals(t.get(i,j), b.get(i,j), 1e-15);
		
		// test non-semi definite matrx
		// the test matrix comes from wikipedia at positive-definite matrix
		// http://en.wikipedia.org/wiki/Positive-definite_matrix
		double[][] array2 = {{1, 2}, {2, 1}};
		Tensor idx = Tensor.newInstanceFromArray(array2);
		try {
			new Cholesky(idx);
			fail("expected exception");
		}
		catch (Cholesky.NotPositiveDefinite e) {
		}
		
		// this matrix is positive definite according to
		// http://en.wikipedia.org/wiki/Positive-definite_matrix
		double[][] m1Array = {{2, -1, 0}, {-1, 2, -1}, {0, -1, 2}};
		Tensor m1 = Tensor.newInstanceFromArray(m1Array);
		new Cholesky(m1);
	}
	
	private void printTensor(String name, Tensor t) {
	    System.out.println("Tensor " + name);
	    for (int i = 0; i < t.getSize(0); i++) {
	        System.out.print("row " + i + ":");
	        for (int j = 0; j < t.getSize(1); j++)
	            System.out.format(" %5.2f", t.get(i,j));
	        System.out.println("");
	    }
	    System.out.println("");  
	}

	@Test
	public void testSolve() {
		double[] array = {-2D, 4D, 3D, -5D, 1D};
		Tensor b = Tensor.newInstanceFromArray(array);
		Tensor x = c.solve(b);
	}
	
	@Test
	public void testSolveSystem() {
		// example from : http://math.fullerton.edu/mathews/n2003/cholesky/CholeskyMod/Links/CholeskyMod_lnk_8.html
		// the system to be solved as A C = B, given A and B below
		double[][] aArray = {
				{6, 15, 55, 225},
				{15, 55, 225, 979},
				{55, 225, 979, 4425},
				{225, 979, 4425, 20515}};
		Tensor a = Tensor.newInstanceFromArray(aArray);
		
		double[] bArray = {36, 76, 272, 1042};
		Tensor b = Tensor.newInstanceFromArray(bArray);
		
		Cholesky choleskyA = new Cholesky(a);
		Tensor c = choleskyA.solve(b);
		
		assertEquals(12.0714, c.get(0), 1e-4);
		assertEquals(-16.1071, c.get(1), 1e-4);
		assertEquals(7.82143, c.get(2), 1e-4);
		assertEquals(-1, c.get(3), 1e-4);
	}

	@Test
	public void testElMultiply() {
		//fail("Not yet implemented");
	}

	@Test
	public void testElSolve() {
		//fail("Not yet implemented");
	}

	@Test
	public void testInverse() {
		//fail("Not yet implemented");
	}

	@Test
	public void testLogDeterminant() {
		//fail("Not yet implemented");
	}

}
