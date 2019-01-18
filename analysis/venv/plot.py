import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

filename_l = "../log-20190118-170806-WatchL.txt"
filename_r = "../log-20190118-170806-WatchR.txt"
acc0r, att0r, rot0r = read_file2(filename_l)
acc1r, att1r, rot1r = read_file2(filename_r)
print(acc0r.shape, acc1r.shape)

t0 = np.diff(acc0r[:, 0]) * 1000
t1 = np.diff(acc1r[:, 0]) * 1000
t0.sort()
t1.sort()
print(t0.mean(), t0.std(), t0[-5:])
print(t1.mean(), t1.std(), t1[-5:])

#zl = 0
#zr = 1498
acc0r = acc0r[:]
att0r = att0r[:]
rot0r = rot0r[:]
acc1r = acc1r[:]
att1r = att1r[:]
rot1r = rot1r[:]

#acc0 = resample(acc0r, 20)
#acc1 = resample(acc1r, 20)

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
    plt.plot(att0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(att1r[:, i+1])

plt.figure(4)
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(rot0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(rot1r[:, i+1])

plt.show()
