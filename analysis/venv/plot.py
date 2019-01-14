import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

filename_l = "../log-2019-01-14-15-50-33-WatchL.txt"
filename_r = "../log-2019-01-14-15-50-33-WatchR.txt"
acc0r, gyr0r, gra0r = read_file(filename_l)
acc1r, gyr1r, gra1r = read_file(filename_r)
print(acc0r.shape, acc1r.shape)

t0 = acc0r[:, 0]
t1 = acc1r[:, 0]

n = min(t0.shape[0], t1.shape[0])
td = t0[:n] - t1[:n] - 118
print(td.mean(), td.std(), td[-5:])

t0 = np.diff(t0)
t1 = np.diff(t1)
t0.sort()
t1.sort()
print(t0.mean(), t0.std(), t0[-5:])
print(t1.mean(), t1.std(), t1[-5:])

zl = 0
zr = 1498
acc0r = acc0r[zl:zr]
gyr0r = gyr0r[zl:zr]
gra0r = gra0r[zl:zr]
acc1r = acc1r[zl:zr]
gyr1r = gyr1r[zl:zr]
gra1r = gra1r[zl:zr]

acc0 = resample(acc0r, 20)
acc1 = resample(acc1r, 20)

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
