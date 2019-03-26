import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

SUB         = True
COMBINE_LR  = True

PLOT_ACC_RAW            = False
PLOT_ACC_RAW_TIME       = False
PLOT_ACC_RAW_RESAMPLE   = True
PLOT_ACC_ROTATED        = True
PLOT_QUA                = True
PLOT_ROT                = True
PLOT_CORRELATION        = True

filename0 = "../log-010IyPb-WatchL.txt"
filename1 = "../log-010IyPb-WatchR.txt"
acc0r, att0r, rot0r, qua0r = read_file2(filename0)
acc1r, att1r, rot1r, qua1r = read_file2(filename1)
print('acc raw shape:', acc0r.shape, qua0r.shape)

# orientation -> rotation
qua0r[:,2:] *= -1
qua1r[:,2:] *= -1

print_timestamp_quality(acc0r[:,0], acc1r[:,0])
BIAS_L = 0
BIAS_R = 0
acc0, acc1 = bias(acc0r, acc1r, BIAS_L, BIAS_R)
qua0, qua1 = bias(qua0r, qua1r, BIAS_L, BIAS_R)
rot0, rot1 = bias(rot0r, rot1r, BIAS_L, BIAS_R)

t1 = min(acc0[-1,0], acc1[-1,0])
acc0 = resample(acc0, t1, 0.01)
qua0 = resample(qua0, t1, 0.01, norm='sphere')
rot0 = resample(rot0, t1, 0.01)
acc1 = resample(acc1, t1, 0.01)
qua1 = resample(qua1, t1, 0.01)
rot1 = resample(rot1, t1, 0.01)

if SUB:
    ZL = 324
    ZR = -500
    acc0 = acc0[ZL:ZR]
    qua0 = qua0[ZL:ZR]
    rot0 = rot0[ZL:ZR]
    acc1 = acc1[ZL:ZR]
    qua1 = qua1[ZL:ZR]
    rot1 = rot1[ZL:ZR]

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

acc0z = rotate2(acc0, qua0, qua1)
cors = acc0z * -acc1

if COMBINE_LR:
    row = 3
else:
    row = 6

if PLOT_ACC_RAW:
    plt.figure('acc raw')
    for i in range(3):
        plt.subplot(row, 1, i+1)
        plt.plot(acc0r[:, i+1])
        plt.subplot(row, 1, row//6*3+i+1)
        plt.plot(acc1r[:, i+1])

if PLOT_ACC_RAW_TIME:
    plt.figure('acc raw - time')
    for i in range(3):
        plt.subplot(row, 1, i+1)
        plt.plot(acc0r[:, 0], acc0r[:, i+1])
        plt.subplot(row, 1, row//6*3+i+1)
        plt.plot(acc1r[:, 0], acc1r[:, i+1])

if PLOT_ACC_RAW_RESAMPLE:
    plt.figure('acc raw - resample')
    for i in range(3):
        sub = plt.subplot(row, 1, i+1)
        # sub.set_ylim(-0.6, 0.6)
        plt.plot(acc0[:, i])
        sub = plt.subplot(row, 1, row//6*3+i+1)
        # sub.set_ylim(-0.6, 0.6)
        plt.plot(acc1[:, i])

if PLOT_ACC_ROTATED:
    plt.figure('acc rotated')
    for i in range(3):
        sub = plt.subplot(row, 1, i+1)
        # sub.set_ylim(-0.6, 0.6)
        plt.plot(acc0z[:, i])
        plt.subplot(row, 1, row//6*3+i+1)
        # sub.set_ylim(-0.6, 0.6)
        plt.plot(acc1[:, i])

if PLOT_QUA:
    plt.figure('qua')
    for i in range(4):
        sub = plt.subplot(4, 1, i+1)
        sub.set_ylim(-1.1, 1.1)
        plt.plot(qua0[:, i])
        plt.plot(qua1[:, i])

if PLOT_ROT:
    plt.figure('rot')
    for i in range(3):
        plt.subplot(row, 1, i+1)
        plt.plot(rot0[:, i])
        plt.subplot(row, 1, row//6*3+i+1)
        plt.plot(rot1[:, i])

if PLOT_CORRELATION:
    plt.figure('correlation')
    for i in range(3):
        sub = plt.subplot(4, 1, i+1)
        plt.plot(cors[:,i])
    sub = plt.subplot(4, 1, 4)
    plt.plot(cors.sum(axis=1))

plt.show()
