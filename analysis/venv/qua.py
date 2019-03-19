import matplotlib.pyplot as plt
import numpy as np
import scipy.signal as signal
import sys
from utils import *

COMBINE_LR = True
SUB_SIGNAL = False

PLOT_ACC_RAW 		= True
PLOT_ACC_ROTATED 	= False
PLOT_ACC_ROTATE_ONE = True
PLOT_QUA 			= False
PLOT_DELTA_QUA		= True
PLOT_CORRELATION 	= True
PLOT_HIGHPASS 		= False

filename0 = "../log-005noise-WatchL.txt"
filename1 = "../log-005noise-WatchR.txt"
acc0r, att0r, rot0r, qua0r = read_file2(filename0)
acc1r, att1r, rot1r, qua1r = read_file2(filename1)
print('acc raw shape:', acc0r.shape, qua0r.shape)

# orientation -> rotation
qua0r[:,2:] *= -1
qua1r[:,2:] *= -1

print_timestamp_quality(acc0r[:,0], acc1r[:,0])

acc0, acc1 = bias(acc0r, acc1r, 0, 0)
qua0, qua1 = bias(qua0r, qua1r, 0, 0)
if SUB_SIGNAL:
	zl = 250
	zr = 350
	acc0 = acc0[zl:zr]
	qua0 = qua0[zl:zr]
	acc1 = acc1[zl:zr]
	qua1 = qua1[zl:zr]
t1 = min(acc0[-1,0], acc1[-1,0])
acc0 = resample(acc0, t1, 0.01)
qua0 = resample(qua0, t1, 0.01, norm='sphere')
acc1 = resample(acc1, t1, 0.01)
qua1 = resample(qua1, t1, 0.01)

def quamul(a, b):
	w0, x0, y0, z0 = a[0], a[1], a[2], a[3]
	w1, x1, y1, z1 = b[0], b[1], b[2], b[3]
	w = w0 * w1 - x0 * x1 - y0 * y1 - z0 * z1
	x = w0 * x1 + x0 * w1 + y0 * z1 - z0 * y1
	y = w0 * y1 - x0 * z1 + y0 * w1 + z0 * x1
	z = w0 * z1 + x0 * y1 - y0 * x1 + z0 * w1
	return np.array([w, x, y, z])

def quainv(a):
	w, x, y, z = a[0], a[1], a[2], a[3]
	return np.array([w, -x, -y, -z])

def work(acc, qua):
	# filter qua
	quaq = signal.medfilt(qua, (151, 1))
	quaq = (quaq.T / np.linalg.norm(quaq.T, axis=0)).T
	# quaq = qua_mean_filter(qua)

	# rotate
	n = acc.shape[0]
	acc = np.insert(acc, 0, values=np.zeros(n), axis=1)
	accq = []
	for i in range(n):
		ai = quamul(quamul(quainv(quaq[i]), acc[i]), quaq[i])
		# ai = quamul(quamul(quaq[i], acc[i]), quainv(quaq[i]))
		accq.append(ai[1:])
	accq = np.array(accq)
	return accq, quaq

def work2(acc, qua0, qua1):
	qua0q = signal.medfilt(qua0, (151, 1))
	qua0q = (qua0q.T / np.linalg.norm(qua0q.T, axis=0)).T
	qua1q = signal.medfilt(qua1, (151, 1))
	qua1q = (qua1q.T / np.linalg.norm(qua1q.T, axis=0)).T
	n = acc.shape[0]
	acc = np.insert(acc, 0, values=np.zeros(n), axis=1)
	accq = []
	for i in range(n):
		qcom = quamul(qua1[i], quainv(qua0[i]))
		# qcom = quamul(quainv(qua1[i]), qua0[i])
		ai = quamul(quamul(qcom, acc[i]), quainv(qcom))
		accq.append(ai[1:])
	accq = np.array(accq)
	return accq

acc0q, qua0q = work(acc0, qua0)
acc1q, qua1q = work(acc1, qua1)
print('acc rotated shape:', acc0q.shape)

acc0z = work2(acc0, qua0, qua1)

def correlation_axis(acc0q, acc1q, w=100):
	n = acc0q.shape[0]
	i = 0
	cors = []
	for i in range(n-w):
		a0 = acc0q[i:i+w]
		a1 = -acc1q[i:i+w]
		a0 = (a0 - a0.mean(axis=0)) / a0.std(axis=0)
		a1 = (a1 - a1.mean(axis=0)) / a0.std(axis=0)
		cor = (a0 * a1).sum(axis=0)
		# cors.append(cor)
		cors.append(acc0q[i:i+w].std(axis=0))
	cors = np.array(cors)
	return cors


if COMBINE_LR:
	row = 3
else:
	row = 6

# raw
if PLOT_ACC_RAW:
	plt.figure('acc raw')
	for i in range(3):
	    sub = plt.subplot(row, 1, i+1)
	    sub.set_ylim(-10, 10)
	    plt.plot(acc0[:, i])
	    if COMBINE_LR:
	    	plt.plot(acc1[:, i])
	    else:
		    sub = plt.subplot(row, 1, i+4)
		    sub.set_ylim(-10, 10)
		    plt.plot(acc1[:, i])

# rotated
if PLOT_ACC_ROTATED:
	plt.figure('acc rotated')
	for i in range(3):
	    sub = plt.subplot(row, 1, i+1)
	    sub.set_ylim(-10, 10)
	    plt.plot(acc0q[:, i])
	    if COMBINE_LR:
	    	plt.plot(acc1q[:, i])
	    else:
		    sub = plt.subplot(row, 1, i+4)
		    sub.set_ylim(-10, 10)
		    plt.plot(acc1q[:, i])

# rotate one
if PLOT_ACC_ROTATE_ONE:
	plt.figure('rotate one')
	for i in range(3):
	    sub = plt.subplot(row, 1, i+1)
	    sub.set_ylim(-10, 10)
	    plt.plot(acc0z[:, i])
	    if COMBINE_LR:
	    	plt.plot(acc1[:, i])
	    else:
		    sub = plt.subplot(row, 1, i+4)
		    sub.set_ylim(-10, 10)
		    plt.plot(acc1[:, i])

# qua
if PLOT_QUA:
	plt.figure('qua')
	for i in range(4):
		sub = plt.subplot(8, 1, i+1)
		sub.set_ylim(-1.1, 1.1)
		plt.plot(qua0[:, i])
		plt.plot(qua1[:, i])
		sub = plt.subplot(8, 1, i+5)
		sub.set_ylim(-1.1, 1.1)
		plt.plot(qua0q[:, i])
		plt.plot(qua1q[:, i])

# deltaqua
if PLOT_DELTA_QUA:
	dqua = []
	costh = []
	for i in range(qua0q.shape[0]):
		dqua.append(quamul(qua1q[i], quainv(qua0q[i])))
		# dqua.append(quamul(quainv(qua0q[i]), qua1q[i]))
		costh.append(np.sum(qua0q[i] * qua1q[i]))
	plt.figure('delta qua')
	dqua = np.array(dqua)
	costh = np.array(costh)
	for i in range(4):
		sub = plt.subplot(5, 1, i+1)
		sub.set_ylim(-1.1, 1.1)
		plt.plot(dqua[:, i])
	sub = plt.subplot(5, 1, 5)
	sub.set_ylim(-1.1, 1.1)
	plt.plot(costh)

# correlation
if PLOT_CORRELATION:
	cors = correlation_axis(acc0z, acc1)
	plt.figure('correlation')
	for i in range(3):
		sub = plt.subplot(4, 1, i+1)
		# plt.plot(cors[:,i])
		plt.plot(acc0z[:, i] * -acc1[:, i])

# highpass
if PLOT_HIGHPASS:
	coeff_b, coeff_a = signal.butter(3, 0.2, 'highpass')
	for i in range(3):
		sub = plt.subplot(6, 1, i+1)
		sub.set_ylim(-10, 10)
		plt.plot(acc0[:, i])
		plt.plot(acc1[:, i])
		acc0h = signal.filtfilt(coeff_b, coeff_a, acc0[:,i])
		acc1h = signal.filtfilt(coeff_b, coeff_a, acc1[:,i])
		sub = plt.subplot(6, 1, i+4)
		sub.set_ylim(-10, 10)
		plt.plot(acc0h)
		plt.plot(acc1h)

plt.show()
