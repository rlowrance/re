package com.roylowrance.util;

// decomposition and solution of Ax=b where A is symmetric and positive definite
// ref: press-07 numerical recipes, p 100 - 102
public class Cholesky {
	private int n;          // size of rows and columns
	private Tensor el;      // the decomposition
	
	/**
	 * construct by deriving the Cholesky decomposition of a
	 * @param a
	 * @throws Cholesky.NotPostiveDefinite if a is not symmetrix and positive definite
	 */
	public Cholesky(Tensor a) {
	    if (a.getNDimensions() != 2)
	        throw new IllegalArgumentException("a must have 2 dimensions; a=" + a);
		if (a.getSize(0) != a.getSize(1))
			throw new IllegalArgumentException("a must be square; a=" + a);
		el = Tensor.newInstance(a);  // el is a share-nothing deep copy of a
		// el will be mutated in the code below, hence the share-nothing deep copy
		n = a.getSize(0);
		
		for (int i = 0; i < n; i++) {
			for (int j = i; j < n; j++) {
				double sum = 0;
				int k;
				for (sum = el.get(i,j), k = i - 1; k >= 0; k--)
					sum -= el.get(i, k) * el.get(j, k);
				if (i == j) {
					if (sum <= 0.0)
						throw new NotPositiveDefinite("a with rounding errors is not positive definite");
					el.set(i, i, Math.sqrt(sum));
				}
				else {
					el.set(j, i, sum / el.get(i, i));
				}
			}
		}
		for (int i = 0; i < n; i++)
			for (int j = 0; j < i; j++)
				el.set(j, i, 0);
	}
	
	/**
	 * retrieve the factor L. The other factor is L^T.
	 * @return factor L.
	 */
	public Tensor getEl() {
		return el;
	}
	
	/**
	 * solve Ax = b for positive definite A.
	 * @param b the right-hand side
	 * @return vector x, the solution to Ax = b, so that x = A^-1 b
	 *         x is a 1D Tensor with n elements
	 */
	public Tensor solve(Tensor b) {
	    if (b.getNDimensions() != 1)
	        throw new IllegalArgumentException("b not 1D; b=" + b);
		if (b.getNElements() != n)
			throw new IllegalArgumentException("vector b has " + b.getNElements() + "elements but A is " + n + " x " + n);
		Tensor x = new Tensor(n);
		// solve L y = b, storing y in x
		for (int i = 0; i < n; i++) {
			double sum;
			int k;
			for (sum = b.get(i), k = i - 1; k >= 0; k--)
				sum -= el.get(i, k) * x.get(k);
			x.set(i,  sum / el.get(i, i));
		}
		// solve L^T x = y
		for (int i = n - 1; i >= 0; i--) {
			double sum;
			int k;
			for (sum = x.get(i), k = i + 1; k < n; k++)	
				sum -= el.get(k, i) * x.get(k);
			x.set(i, sum / el.get(i,i));
		}
		return x;
	}
	
	/**
	 * b := L y, where L is the lower triangle matrix from the Cholesky decomposition
	 * @param y a vector
	 * @return L y
	 */
	public Tensor elMultiply(Tensor y) {
		if (y.getNElements() != n)
			throw new IllegalArgumentException("vector y has " + y.getNElements() + " elements but A is " + n + " x " + n);
		Tensor b = new Tensor(n);
		for (int i = 0; i < n; i++) {
			b.set(i, 0.0);
			for (int j = 0; j <= i; j++) 
				b.set(i, b.get(i) + el.get(i,j) * y.get(j));
		}
		return b;
	}
	
	/**
	 * Solve L y = b, where L is the lower triangular matrix from the Cholesky decomposition
	 * @param b is the input vector
	 * @return vector y such that y = L^-1 b
	 */
	public Tensor elSolve(Tensor b) {
		if (b.getNElements() != n)
			throw new IllegalArgumentException("vector b has " + b.getNElements() + "elements but A is " + n + " x " + n);
		Tensor y = new Tensor(n);
		for (int i = 0; i < n; i++) {
			double sum = 0.0;
			int j;
			for (sum = b.get(i), j = 0; j < i; j++)
				sum -= el.get(i, j) * y.get(j);
			y.set(i, sum / el.get(i, i));
		}
		return y;
	}
	
	/**
	 * determine inverse of stored matrix
	 * @return the inverse
	 */
	public Tensor inverse() {
		Tensor ainv = new Tensor(n, n);
		for (int i = 0; i < n; i++)
			for (int j = 0; j <= i; j++) {
				double sum = i == j ? 1.0 : 0.0;
				for (int k = i - 1; k >= j; k--)
					sum -= el.get(i, k) * ainv.get(j, k);
				ainv.set(j, i, sum / el.get(i,i));
			}
		for (int i = n - 1; i >= 0; i--)
			for (int j = 0; j <= i; j++) {
				double sum = i < j ? 0.0 : ainv.get(j, i);
				for (int k = i + 1; k < n; k++)
					sum -= el.get(k, i) * ainv.get(j, k);
				double temp = sum / el.get(i, i);
				ainv.set(i, j, temp);
				ainv.set(j, i, temp);
			}
		return ainv;
	}
	
	/**
	 * logarithm of the determinant of A
	 * @return log of determinant
	 */
	public double logDeterminant() {
		double sum = 0.0;
		for (int i = 0; i < n; i++)
			sum += Math.log(el.get(i, i));
		return 2.0 * sum;
	}
	
	public class NotPositiveDefinite extends RuntimeException {
		public NotPositiveDefinite(String message) {
			super(message);
		}
	}
}
