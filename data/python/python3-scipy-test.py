#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Test for some basic scipy routines
# * do 1 simple 1d discrete fourier transformation
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>


import math

import numpy as np
from scipy.integrate import quad, simps


def max_difference(a1, a2):
    return np.absolute(a1 - a2).max()


if __name__ == "__main__":
    try:
        from scipy.fft import fft, ifft

        print("scipy-fft module present")
        ## Create input functions
        x = np.arange(-4 * np.pi, 4 * np.pi, 0.1)
        y1 = np.sin(x)
        y2 = np.sin(2 * x)
        y = y1 + y2

        print("Performing fft ... ")
        # Note:  Fourier(f+g) = Fourier(f) + Fourier(g)
        fr_y1 = fft(y)
        fr_y2 = fft(y1) + fft(y2)

        ## Check if both resulting functions are the same
        max_diff = max_difference(fr_y1, fr_y2)
        print("  Max difference: %.2e" % (max_diff))
        if max_diff > 1e-5:
            raise ValueError("fft function check failed")

        ## Inverse fft is the actual cross-check:
        ## check if: ifft( fft(y1) + fft(y2)) = y1+y2
        print("Inverse fft ... ")
        y_inv = ifft(fr_y2)
        max_diff = max_difference(y, y_inv)
        print("  Max difference: %.2e" % (max_diff))
        if max_diff > 1e-5:
            raise ValueError("inverse fft function check failed")
    except ImportError:
        print("Softfail: bsc#1180605 - scipy-fft module not found")

    ## Test integration
    print("Test integrators  ... ")
    x = np.array([1, 2, 3, 4])
    integral = simps(x ** 2, x)  # Integrate x^2 from 1..4. Exact result: 21
    if abs(integral - 21.0) > 0.5:
        raise ValueError("Simpson integration failed")
    integral = quad(lambda x: x ** 3, 1, 4)[
        0
    ]  # Integrate x^3 from 1..4. Exact result: 63.75
    if abs(integral - 63.75) > 0.5:
        raise ValueError("quad integration failed")
    print("OK")
