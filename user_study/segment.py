import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

PLOT_ACC 	= True

BIAS_L = 1
BIAS_R = 14
special = []
delete_sig_list = []

filename = sys.argv[1]
filename0 = filename + 'L.txt'
filename1 = filename + 'R.txt'
acc0r, att0r, rot0r, qua0r = read_file2(filename0)
acc1r, att1r, rot1r, qua1r = read_file2(filename1)
print('acc raw shape:', acc0r.shape, qua0r.shape)
qua0r[:,2:] *= -1
qua1r[:,2:] *= -1

# print_timestamp_quality(acc0r[:,0], acc1r[:,0])
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
qua1 = resample(qua1, t1, 0.01, norm='sphere')
rot1 = resample(rot1, t1, 0.01)
att1 = resample(att1, t1, 0.01)

mag0 = np.linalg.norm(acc0, axis=1)
mag1 = np.linalg.norm(acc1, axis=1)

sigstart = -1
idletime = 0
data = []
mids = []
for i in range(mag1.shape[0]):
	if mag1[i] > 2 or mag0[i] > 3:
	# if mag1[i] > 3 or mag0[i] > 5 or acc1[i, 0] < -1.8:
		if sigstart == -1: sigstart = i
		sigend = i
		idletime = 0
	else:
		if sigstart != -1 and idletime > 20 or i in special:
			sigmid = (sigstart + sigend) // 2
			if i in special: sigmid = i
			l = sigmid - 25
			r = sigmid + 25
			mids.append(sigmid)
			data.append(np.concatenate([acc0[l:r], rot0[l:r], qua0[l:r], att0[l:r], acc1[l:r], rot1[l:r], qua1[l:r], att1[l:r]], axis=1))
			sigstart = -1
		idletime += 1

def delete(idx):
	global data
	global mids
	for i in idx:
		data = data[:i] + data[i+1:]
		mids = mids[:i] + mids[i+1:]

data = data[1:]
mids = mids[1:]
delete(delete_sig_list)
print('len:', len(data))
data = np.array(data)

ofn = sys.argv[2]
np.save(ofn + '.npy', data)

s = np.zeros((mag1.shape[0]))
for mid in mids:
	s[mid] = 1

if PLOT_ACC:
	plt.figure('acc')
	for i in range(3):
	    plt.subplot(5, 1, i+1)
	    plt.plot(acc0[:, i])
	    plt.subplot(5, 1, i+1)
	    plt.plot(acc1[:, i])
	plt.subplot(5, 1, 4)
	plt.plot(mag0)
	plt.plot(-mag1)
	plt.subplot(5, 1, 5)
	plt.plot(s)
	plt.show()