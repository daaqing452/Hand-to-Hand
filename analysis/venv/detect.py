import matplotlib.pyplot as plt
import numpy as np
from utils import *

filename_l = "../data/log-w16-WatchL.txt"
filename_r = "../data/log-w16-WatchR.txt"
acc0r, att0r, rot0r = read_file2(filename_l)
acc1r, att1r, rot1r = read_file2(filename_r)

acc0r = rot0r
acc1r = rot1r

acc0r, acc1r = bias(acc0r, acc1r, 0, 2)
t1 = min(acc0r[-1,0], acc1r[-1,0])
acc0 = resample(acc0r, t1, 0.01)
acc1 = resample(acc1r, t1, 0.01)

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
plt.plot(conv(acc0, acc1))

plt.figure()
plt.title('direct multiply on magnitude of three axis')
for i in range(3):
    plt.subplot(3, 1, i+1)
    plt.plot(np.abs(acc0[:,i]) * np.abs(acc1[:,i]))


plt.show()