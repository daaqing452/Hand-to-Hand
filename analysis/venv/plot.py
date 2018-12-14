import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

filename_l = "../log_left.txt"
filename_r = "../log_right.txt"
acc0r, gyr0r, gra0r = read_file(filename_l)
acc1r, gyr1r, gra1r = read_file(filename_r)

acc0 = resample(acc0r, 4)
acc1 = resample(acc1r, 4)
print(acc1.shape, acc1r.shape)

plt.figure(1)
for i in range(3):
	plt.subplot(6, 1, i+1)
	plt.plot(acc0[:, i])
for i in range(3):
	plt.subplot(6, 1, i+1)
	plt.plot(acc1[:, i])

for i in range(3):
    plt.subplot(6, 1, i+4)
    plt.plot(acc0r[:, i+1])
for i in range(3):
    plt.subplot(6, 1, i+4)
    plt.plot(acc1r[:, i+1])

'''plt.figure(2)
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gyr0[zl:zr, i])
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gyr1[zl:zr, i])

plt.figure(3)
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gra0[zl:zr, i])
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gra1[zl:zr, i])'''

plt.show()
