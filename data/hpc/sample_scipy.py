"""
TODO: Extend it in order to run one script for scipy and numpy
"""
from mpi4py import MPI
import scipy  # unsued import. it just verify that the setup works
import numpy as np  # unsued import.


comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

print('Hello from process {} out of {}'.format(rank, size))
