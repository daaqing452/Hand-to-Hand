import matplotlib.pyplot as plt
import numpy as np
from utils import *

filename_l = "../log_bad_left.txt"
filename_r = "../log_bad_right.txt"
acc0r, gyr0r, gra0r = read_file(filename_l)
acc1r, gyr1r, gra1r = read_file(filename_r)

L0 = min(acc0r.shape[0], acc1r.shape[0])
acc0 = acc0r[:L0, 1:4]
acc1 = acc1r[:L0, 1:4]

acc0 = highpass_filter(acc0, level=2)
acc1 = highpass_filter(acc1, level=2)

def cor(a0, a1, W=10, STD=5, TH=9.8):
    d = []
    L = a0.shape[0]
    for i in range(L):
        if i + W >= L:
            d.append(0)
            continue
        a = a0[i:i+W]
        b = a1[i:i+W]
        a = a - a.mean(axis=0)
        b = b - b.mean(axis=0)
        #a = (np.abs(a) > TH) * a
        #b = (np.abs(b) > TH) * b
        a = np.linalg.norm(a, axis=1)
        b = np.linalg.norm(b, axis=1)
        a = a / max(STD, a.std())
        b = b / max(STD, a.std())
        c = np.convolve(a, b, 'same')
        d.append(c.max())
    return np.array(d)

plt.figure(1)
for i in range(3):
    plt.subplot(6, 1, i+1)
    plt.plot(acc0r[:, i+1])
    plt.plot(acc1r[:, i+1])
for i in range(3):
    plt.subplot(6, 1, i+4)
    plt.plot(acc0[:, i])
    plt.plot(acc1[:, i])

plt.figure(2)
plt.subplot(614)
plt.plot(cor(acc0, acc1))

plt.subplot(615)
plt.plot(cor(acc0, acc0))

plt.subplot(616)
plt.plot(cor(acc1, acc1))

plt.show()