package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

// throw IllegalArgumentException if certain conditions hold
public class IAE {

    // helper function

    private static void throwIAE(String fmt, Object... objects) {
        throw new IllegalArgumentException(String.format(fmt, objects));
    }

    // a <= b
    public static void equals(int a, int b, String msg, String nameA, String nameB) {
        if (a == b)
            return;
        throwIAE("%s (%s) should be equal to %s(%s) but is not", nameA, a, nameB, b);

    }

    // a == constant
    public static void equalsConstant(int a, int constant, String nameA) {
        if (a == constant)
            return;
        throwIAE("%s (%s) should be equal to %s but is not", nameA, a, constant);

    }

    //
    public static void false_(boolean cond, String msg) {
        if (!cond)
            throwIAE("It should be that %s but is not", msg);
    }

    // tensor is 1D (and hence is not null)
    public static void is1D(Tensor t, String name) {
        isNotNull(t, name);
        if (t.getNDimensions() == 1)
            return;
        throwIAE("Tensor %s should not be null but is", name);
    }

    // tensor is 1D of specified size
    public static void is1DWithSize(Tensor t, int size, String name) {
        is1D(t, name);
        if (t.getSize(0) == size)
            return;
        throwIAE("Tensor %s should have size %d", name, size);
    }

    // tensor is 2D (and hence is not null)
    public static void is2D(Tensor t, String name) {
        isNotNull(t, name);
        if (t.getNDimensions() == 2)
            return;
        throwIAE("Tensor %s should not be null but is", name);
    }

    // object is not null
    public static void isNotNull(Object o, String name) {
        if (o != null)
            return;
        throwIAE("Object %s is null but should not be", name);
    }

    // a <= b
    public static void lessEqual(int a, int b, String nameA, String nameB) {
        if (a <= b)
            return;
        throwIAE("%s (%d) should be <= %s (%d) but is not", nameA, a, nameB, b);
    }

    // a >= 0
    public static void nonNegative(int a, String nameA) {
        if (a >= 0)
            return;
        throwIAE("%s (%d) should be non-negative but is not", nameA, a);
    }

    // t != null
    public static void notNull(Object t, String var) {
        if (t != null)
            return;
        throwIAE("%s is null but should not be", var);
    }

    // a > 0
    public static void positive(int a, String nameA) {
        if (a > 0)
            return;
        throwIAE("%s (%d) should be positive but is not", nameA, a);
    }

}
