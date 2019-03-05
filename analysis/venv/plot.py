import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

filename_l = "../log-20190305-091935-WatchL.txt"
filename_r = "../log-test_delimiter-WatchR.txt"
acc0r, att0r, rot0r = read_file2(filename_l)
acc1r, att1r, rot1r = read_file2(filename_r)
print(acc0r.shape, acc1r.shape)

t0 = np.diff(acc0r[:, 0]) * 1000
t1 = np.diff(acc1r[:, 0]) * 1000
t0.sort()
t1.sort()
print(t0.mean(), t0.std(), t0[-5:])
print(t1.mean(), t1.std(), t1[-5:])

acc0r, acc1r = bias(acc0r, acc1r, 0, 0)

t1 = min(acc0r[-1,0], acc1r[-1,0])
acc0 = resample(acc0r, t1, 0.01)
acc1 = resample(acc1r, t1, 0.01)

plt.figure()
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc1r[:, i+1])

'''plt.figure()
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc0r[:, 0], acc0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc1r[:, 0], acc1r[:, i+1])

plt.figure()
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc0[:, i])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc1[:, i])'''

plt.figure()
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(att0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(att1r[:, i+1])

plt.figure()
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(rot0r[:, i+1])
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(rot1r[:, i+1])

plt.show()
