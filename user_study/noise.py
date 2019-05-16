import numpy as np
import sys
import matplotlib.pyplot as plt
from utils import *

samp_n = 500

BIAS_L = 0
BIAS_R = 0

filename = sys.argv[1]
filename0 = filename + 'L.txt'
filename1 = filename + 'R.txt'
acc0r, att0r, rot0r, qua0r = read_file2(filename0)
acc1r, att1r, rot1r, qua1r = read_file2(filename1)
print('acc raw shape:', acc0r.shape, qua0r.shape)
qua0r[:,2:] *= -1
qua1r[:,2:] *= -1

acc0, acc1 = bias(acc0r, acc1r, BIAS_L, BIAS_R)
qua0, qua1 = bias(qua0r, qua1r, BIAS_L, BIAS_R)
rot0, rot1 = bias(rot0r, rot1r, BIAS_L, BIAS_R)
att0, att1 = bias(att0r, att1r, BIAS_L, BIAS_R)

t1 = min(acc0[-1,0], acc1[-1,0])
acc0 = resample(acc0, t1, 0.01)
qua0 = resample(qua0, t1, 0.01, norm='sphere')
rot0 = resample(rot0, t1, 0.01)
att0 = resample(att0, t1, 0.01)
acc1 = resample(acc1, t1, 0.01)
qua1 = resample(qua1, t1, 0.01)
rot1 = resample(rot1, t1, 0.01)
att1 = resample(att1, t1, 0.01)

a = np.concatenate([acc0, qua0, rot0, att0, acc1, qua1, rot1, att1], axis=1)
n = a.shape[0]
# a = a[n//10:n//10*9]
strand = a.shape[0] * 9 // 10 // (samp_n+1)
now = n//20+strand
noise = []
for i in range(samp_n):
	noise.append(a[now-25:now+25])
	# print(noise[-1].shape)
	now += strand
nz = np.concatenate(noise, axis=0)
noise = np.array(noise)
print(noise.shape)

pathele = filename.split('/')
oname = '/'.join(pathele[:-2]) + '/noise.npy'
np.save(oname, noise)

if False:
	plt.figure('noise')
	for i in range(3):
	    plt.subplot(5, 1, i+1)
	    plt.plot(a[:, i])
	    plt.subplot(5, 1, i+1)
	    plt.plot(a[:, i+13])
	plt.subplot(5, 1, 4)
	plt.plot(nz[:, 0])
	plt.plot(nz[:, 1])
	plt.plot(nz[:, 2])
	plt.show()