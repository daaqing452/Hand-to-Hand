import matplotlib.pyplot as plt
import numpy as np
import scipy.signal as signal
import sys
from utils import *

COMBINE_LR = True
SUB_SIGNAL = False

filename0 = "../log-001-WatchL.txt"
filename1 = "../log-001-WatchR.txt"
acc0r, att0r, rot0r, qua0r = read_file2(filename0)
acc1r, att1r, rot1r, qua1r = read_file2(filename1)
print(acc0r.shape, qua0r.shape)

print_timestamp_quality(acc0r[:,0], acc1r[:,0])

acc0, acc1 = bias(acc0r, acc1r, 3, 0)
qua0, qua1 = bias(qua0r, qua1r, 3, 0)
if SUB_SIGNAL:
	zl = 250
	zr = 350
	acc0 = acc0[zl:zr]
	qua0 = qua0[zl:zr]
	acc1 = acc1[zl:zr]
	qua1 = qua1[zl:zr]
t1 = min(acc0[-1,0], acc1[-1,0])
acc0 = resample(acc0, t1, 0.01)
qua0 = resample(qua0, t1, 0.01)
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
	return np.array([w, -x, -y, -z]) / np.linalg.norm(a, ord=2)

def work(acc, qua):
	# filter qua
	quaq = signal.medfilt(qua, (21, 1))

	# rotate
	n = acc.shape[0]
	acc = np.insert(acc, 0, values=np.zeros(n), axis=1)
	accq = []
	for i in range(n):
		ai = quamul(quamul(quainv(quaq[i]), acc[i]), quaq[i])
		accq.append(ai[1:])
	accq = np.array(accq)
	return accq, quaq

acc0q, qua0q = work(acc0, qua0)
acc1q, qua1q = work(acc1, qua1)

print(acc0q.shape)

if True:
	if COMBINE_LR:
		row = 3
	else:
		row = 6
	# raw
	plt.figure()
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
	plt.figure()
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
	# qua
	plt.figure()
	for i in range(4):
		sub = plt.subplot(8, 1, i+1)
		sub.set_ylim(-1.1, 1.1)
		plt.plot(qua0[:, i])
		plt.plot(qua1[:, i])
		sub = plt.subplot(8, 1, i+5)
		sub.set_ylim(-1.1, 1.1)
		plt.plot(qua0q[:, i])
		plt.plot(qua1q[:, i])
	# sync
	energy = acc0q * -acc1q
	plt.figure()
	for i in range(3):
		sub = plt.subplot(4, 1, i+1)
		plt.plot(energy[:, i])
	sub = plt.subplot(4, 1, 4)
	plt.plot(np.linalg.norm(energy, ord=2, axis=1))

'''if False:
	plt.figure()
	for i in range(3):
	    sub = plt.subplot(7, 1, i+1)
	    sub.set_ylim(-10, 10)
	    plt.plot(acc0r[:, i+1])
	    plt.plot(acc0q[:, i+1])
	for i in range(4):
	    sub = plt.subplot(7, 1, i+4)
	    sub.set_ylim(-1.1, 1.1)
	    plt.plot(qua0r[:, i+1])
	    plt.plot(qua0[:, i])

if False:
	plt.figure()
	for i in range(3):
	    sub = plt.subplot(7, 1, i+1)
	    sub.set_ylim(-10, 10)
	    plt.plot(acc0r[:, i+1])
	for i in range(4):
	    sub = plt.subplot(7, 1, i+4)
	    sub.set_ylim(-1.1, 1.1)
	    plt.plot(qua0r[:, i+1])
	plt.figure()
	for i in range(3):
	    sub = plt.subplot(7, 1, i+1)
	    sub.set_ylim(-10, 10)
	    plt.plot(acc0q[:, i+1])
	for i in range(4):
	    sub = plt.subplot(7, 1, i+4)
	    sub.set_ylim(-1.1, 1.1)
	    plt.plot(qua0[:, i])'''

plt.show()

'''q0 = np.array([0.9812798, -0.07862352, 0.157247, -0.07862352])
v = np.array([0, 1, 2, 3])
vv = quamul(quamul(q0, v), quainv(q0))
print(vv)'''