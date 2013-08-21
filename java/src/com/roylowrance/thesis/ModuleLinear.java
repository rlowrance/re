package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

public class ModuleLinear {
    private State w;
    
    public ModuleLinear(int ninputs, int noutputs) {
        w = new State(ninputs, noutputs);
    }
    
    // return output State
    public State fprop(State input) {
        final int n = w.getX().getSize(0);
        final int m = input.getX().getSize(1);
        State result = new State(n, m);
                
        Tensor resultX = new Tensor(w.getX().getSize(0), input.getX().getSize(1));
        resultX.mm(w.getX(), input.getX());  // mutate result
        result.setX(resultX);
        
        return result;
    }
    
    // return 
    public State bprop(State output) {
        Tensor resultDx = new Tensor(w.getX().getSize(1), output.getDx().getSize(1));
        resultDx.mm(w.getX().t(), output.getDx());
        
    }

}
