package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

// a State carries values between modules.
public class State {
    private Tensor x;  // actual state
    private Tensor dx; // partial derivative of loss function wrt x
    
    // construct 1D state
    public State(int n) {
        x = new Tensor(n);
        dx = new Tensor(n);
    }

    // construct 2D state 
    public State(int n, int m) {
        x = new Tensor(n, m);
        dx = new Tensor(n, m);
    }
    
    // acccessors
    public Tensor getX()           {return x;}
    public void setX(Tensor value) {x = value;}
    
    public Tensor getDx()           {return dx;}
    public void setDx(Tensor value) {dx = value;}
    
    // resize to 1D
    public void resize(int n) {
        if (x.getNDimensions() == 1) {
            x = resize1Dto1D(x, n);
            dx = resize1Dto1D(dx, n);
        }
        else {
            x = resize2Dto1D(x, n);
            dx = resize2Dto1D(dx, n);
        }
    }
    
    // resize to 2D
    public void resize(int n, int m) {
        if (x.getNDimensions() == 1) {
            x = resize1Dto2D(x, n, m);
            dx = resize1Dto2D(dx, n, m);
        }
        else {
            x = resize2Dto2D(x, n, m);
            dx =resize2Dto2D(dx, n, m);
        }
    }
    
    private Tensor resize1Dto1D(Tensor x, int n) {
        Tensor result = new Tensor(n);
        final int sizeX = x.getSize(0);
        for (int i = 0; i < n; i++) {
            result.set(i, (i < sizeX) ? x.get(i) : 0);
        }
        return result;
    }
    
    private Tensor resize1Dto2D(Tensor x, int n, int m) {
        Tensor result = new Tensor(n, m);
        final int sizeX = x.getSize(0);
        int xIndex = 0;
        for (int rowIndex = 0; rowIndex < n; rowIndex++) {
            for (int columnIndex = 0; columnIndex < m; columnIndex++) {
                result.set(rowIndex, columnIndex, (xIndex < sizeX) ? x.get(xIndex) : 0);
                xIndex++;
            }
        }
        return result;
    }
    
    private Tensor resize2Dto1D(Tensor x, int n) {
        Tensor result = new Tensor(n);
        int resultIndex = 0;
        for (int rowIndex = 0; rowIndex < x.getSize(0); rowIndex++)
            for (int columnIndex = 0; columnIndex < x.getSize(1); columnIndex++) {
                result.set(resultIndex, x.get(rowIndex, columnIndex));
                resultIndex++;
            }
        return result;
    }
    
    private Tensor resize2Dto2D(Tensor x, int n, int m) {
        Tensor temp = resize2Dto1D(x, x.getSize(0) * x.getSize(1));
        return resize1Dto2D(temp, n, m);
    }
    
}
