import matplotlib.pyplot as plt
import numpy as np
import scipy.signal as signal
import sys
from utils import *

COMBINE_LR = True
SUB_SIGNAL = False

PLOT_ACC_RAW 		= False
PLOT_ACC_ROTATED 	= False
PLOT_ACC_ROTATE_ONE = False
PLOT_QUA 			= False
PLOT_DELTA_QUA		= False
PLOT_CORRELATION 	= False
PLOT_HIGHPASS 		= False

DRAW_SMOOTH			= False
DRAW_CORRELATION	= True

filename0 = "../log-006correlation-WatchL.txt"
filename1 = "../log-006correlation-WatchR.txt"
acc0r, att0r, rot0r, qua0r = read_file2(filename0)
acc1r, att1r, rot1r, qua1r = read_file2(filename1)
print('acc raw shape:', acc0r.shape, qua0r.shape)

# orientation -> rotation
qua0r[:,2:] *= -1
qua1r[:,2:] *= -1

print_timestamp_quality(acc0r[:,0], acc1r[:,0])

acc0, acc1 = bias(acc0r, acc1r, 0, 3)
qua0, qua1 = bias(qua0r, qua1r, 0, 3)
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
qua1 = resample(qua1, t1, 0.01, norm='sphere')

l = 500
r = 5800
acc0 = acc0[l:r]
qua0 = qua0[l:r]
acc1 = acc1[l:r]
qua1 = qua1[l:r]

acc2r, att2r, rot2r, qua2r = read_file2('../log-014sin-WatchL.txt')
acc3r, att3r, rot3r, qua3r = read_file2('../log-014sin-WatchR.txt')
acc2, acc3 = bias(acc2r, acc3r, 0, 0)
qua2, qua3 = bias(qua2r, qua3r, 0, 0)
t1 = min(acc2[-1,0], acc3[-1,0])
acc2 = resample(acc2, t1, 0.01)
qua2 = resample(qua2, t1, 0.01, norm='sphere')
acc3 = resample(acc3, t1, 0.01)
qua3 = resample(qua3, t1, 0.01, norm='sphere')
acc0 = np.concatenate([acc0, acc2], axis=0)[:-150]
acc1 = np.concatenate([acc1, acc3], axis=0)[:-150]
qua0 = np.concatenate([qua0, qua2], axis=0)[:-150]
qua1 = np.concatenate([qua1, qua3], axis=0)[:-150]

def rotate(acc, qua):
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

def rotate2(acc, qua0, qua1):
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

acc0q, qua0q = rotate(acc0, qua0)
acc1q, qua1q = rotate(acc1, qua1)
print('acc rotated shape:', acc0q.shape)

acc0z = rotate2(acc0, qua0, qua1)

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

# cors = correlation_axis(acc0z, acc1)
cors = acc0z * -acc1

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
	plt.figure('correlation')
	for i in range(3):
		sub = plt.subplot(4, 1, i+1)
		plt.plot(cors[:,i])
	sub = plt.subplot(4, 1, 4)
	plt.plot(cors.sum(axis=1))

# highpass
if PLOT_HIGHPASS:
	coeff_b, coeff_a = signal.butter(3, 0.2, 'highpass')
	plt.figure('highpass')
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

# draw smooth
if DRAW_SMOOTH:
	rr = 5500
	ylabel = ['W', 'X', 'Y', 'Z']
	plt.figure('draw1')
	for i in range(4):
		sub = plt.subplot(4, 2, i*2+1)
		sub.set_ylim(-1.1, 1.1)
		plt.ylabel(ylabel[i], rotation='horizontal', horizontalalignment='right', fontsize=15, fontname='arial')
		plt.xticks([])
		plt.yticks(size=8, fontname='arial')
		plt.plot(qua0[:rr, i], linewidth=1)
		plt.plot(qua1[:rr, i], 'coral', linewidth=1)
		#if i == 3:
		#	plt.xlabel('(a) Before smoothing', fontsize=12, fontname='arial')

		sub = plt.subplot(4, 2, i*2+2)
		# sub.yaxis.set_ticks_position('right')
		sub.set_ylim(-1.1, 1.1)
		plt.ylabel(ylabel[i], rotation='horizontal', horizontalalignment='right', fontsize=15, fontname='arial')
		plt.xticks([])
		plt.yticks(size=8, fontname='arial')
		p0, = plt.plot(qua0q[:rr, i], linewidth=1)
		p1, = plt.plot(qua1q[:rr, i], 'coral', linewidth=1)
		#if i == 3:
		#	plt.xlabel('(b) After smoothing', fontsize=12, fontname='arial')
		if i == 0:	
			sub.legend([p0, p1], ['Left', 'Right'], loc=(0.2, 1.03), edgecolor='white', ncol=2, prop={'family': 'arial', 'size': 14})

# draw correlation
if DRAW_CORRELATION:
	plt.figure('draw2')
	for i in range(3):
		sub = plt.subplot(7, 1, i+1)
		sub.set_ylim(-9.5, 9.5)
		sub.yaxis.set_ticks_position('right')
		plt.yticks(size=8, fontname='arial')
		plt.xticks([])
		p1, = plt.plot(acc1[:, i], 'coral', linewidth=1)
		p0, = plt.plot(acc0[:, i], linewidth=1)
		if i == 1:
			plt.ylabel('Raw Motion', fontsize=12, fontname='arial')
		if i == 0:
			sub.legend([p0, p1], ['Left', 'Right'], loc=(0.5, 1.1), ncol=2, edgecolor='white', prop={'family': 'arial', 'size': 10})
	for i in range(3):
		sub = plt.subplot(7, 1, i+4)
		sub.set_ylim(-9.5, 9.5)
		sub.yaxis.set_ticks_position('right')
		plt.yticks(size=8, fontname='arial')
		plt.xticks([])
		p1, = plt.plot(acc1[:, i], 'coral', linewidth=1)
		p0, = plt.plot(acc0z[:, i], 'seagreen', linewidth=1)
		if i == 1:
			plt.ylabel('Rotated Motion', fontsize=12, fontname='arial')
		if i == 2:
			sub.legend([p0, p1], ['Rotated Left', 'Right'], loc=(0.5, -2.3), ncol=2, edgecolor='white', prop={'family': 'arial', 'size': 10})
	sub = plt.subplot(7, 1, 7)
	sub.yaxis.set_ticks_position('right')
	plt.yticks(size=8, fontname='arial')
	plt.xticks([])
	p2, = plt.plot(cors.sum(axis=1), 'darkviolet', linewidth=1)
	plt.ylabel('Correlation', fontsize=12, fontname='arial')
	plt.xlabel('Stationary Walking Running Jumping Hand Moving Unimanual Touch', fontsize=12, fontname='arial')
	sub.legend([p2], ['X Y Z'], loc=(0.2, 8.4), edgecolor='white', ncol=2, prop={'family': 'arial', 'size': 10})

plt.show()
