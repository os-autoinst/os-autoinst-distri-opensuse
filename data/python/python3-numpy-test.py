#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Test for basic numpy routines
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>


import math

import numpy as np


def _rotMatrix(theta):
    # Build rotation matrix
    R = np.zeros((2, 2))
    cosTheta, sinTheta = math.cos(theta), math.sin(theta)
    R[0, 1] = cosTheta
    R[0, 1] = -sinTheta
    R[1, 0] = sinTheta
    R[1, 1] = cosTheta
    return R


# rotate vector v by angle theta (in radians)
def rotate(v, theta):
    return np.matmul(v, _rotMatrix(theta))


def v_eq(v1, v2, tol=1e-6):
    # Check if two vectors are within a given numerical tolerance
    d = v1 - v2
    val = np.dot(d, d)  # dot product is the square of the distance
    return val < (tol * tol)


if __name__ == "__main__":
    # Create two test vectors
    v1, v2 = np.array([2, 1]), np.array([-2, 1])
    v1 = np.transpose(v1)
    v2 = np.transpose(v2)
    # Rotate test vectors
    theta = math.pi / 2.0  # 90 degrees
    r1, r2 = rotate(v1, theta), rotate(v2, theta)
    if not v_eq(r1, np.array([1, -2])):
        raise ValueError("v1 rotation failed")
    if not v_eq(r2, np.array([1, 2])):
        raise ValueError("v2 rotation failed")

    ## Test some stochastic operations

    # Create sinus function
    x = np.arange(0, 4 * np.pi, 0.01)
    y = np.sin(x)

    avg, std = np.average(y), np.std(y)
    if abs(avg) > 1e-5:
        raise ValueError("Average above numerical tolerance")
    # Note: Expected standart deviation for sample: 0.7070046915466268
    if abs(std - 0.707) > 1e-3:
        raise ValueError("Std above numerical tolerance")

    print("OK")
