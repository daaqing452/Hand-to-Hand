import matplotlib.pyplot as plt
import numpy as np
from utils import *

filename_l = "../log-20190121-105041-WatchL.txt"
filename_r = "../log-20190121-105041-WatchR.txt"
acc0r, att0r, rot0r = read_file2(filename_l)
acc1r, att1r, rot1r = read_file2(filename_r)

acc0r, acc1r = bias(acc0r, acc1r, 0, 2)
t1 = min(acc0r[-1,0], acc1r[-1,0])
acc0 = resample(acc0r, t1, 0.01)
acc1 = resample(acc1r, t1, 0.01)

def cor(a0, a1, W=5, STD=5, TH=9.8):
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

plt.figure()
plt.title('acc on three axes')
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(acc0[:, i])
    plt.plot(acc1[:, i])

plt.figure()
plt.title('magnitude & conv on magnitude')
plt.subplot(311)
plt.plot(np.linalg.norm(acc0, axis=1))
plt.plot(np.linalg.norm(acc1, axis=1))
plt.subplot(312)
plt.plot(cor(acc0, acc1))

plt.figure()
plt.title('direct multiply on magnitude of three axis')
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(np.abs(acc0[:,i]) * np.abs(acc1[:,i]))



plt.show()