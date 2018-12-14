import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

filename_l = "../log_bump_left.txt"
filename_r = "../log_bump_right.txt"
acc0r, gyr0r, gra0r = read_file(filename_l)
acc1r, gyr1r, gra1r = read_file(filename_r)
print(acc0r.shape, acc1r.shape)

zl = 0
zr = 1498
acc0r = acc0r[zl:zr]
gyr0r = gyr0r[zl:zr]
gra0r = gra0r[zl:zr]
acc1r = acc1r[zl:zr]
gyr1r = gyr1r[zl:zr]
gra1r = gra1r[zl:zr]

acc0 = resample(acc0r, 4)
acc1 = resample(acc1r, 4)

plt.figure(1)
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc1r[:, i+1])

plt.figure(2)
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc0r[:, 0], acc0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc1r[:, 0], acc1r[:, i+1])

plt.figure(3)
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc0[:, i])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc1[:, i])

plt.show()
