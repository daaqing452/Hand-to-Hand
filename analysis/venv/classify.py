import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

DETECT_THRESHOLD = 3

filename_l = "../log_left.txt"
filename_r = "../log_right.txt"
al, tl = read_file(filename_l)
ar, tr = read_file(filename_r)

a = al[:,0]
bx = (np.abs(a - a.mean()) > a.std() * DETECT_THRESHOLD).astype(int)
a = al[:,1]

print(len(np.nonzero(bx)[0]))
print(bx)
