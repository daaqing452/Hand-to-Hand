import math
import numpy as np
from scipy import signal

def read_file(filename):
	t_first = -1
	acc = []
	gyr = []
	gra = []
	f = open(filename, 'r')
	line = -1
	while True:
		line += 1
		s = f.readline()
		if len(s) <= 0:
			break
		arr = s[:-1].split(' ')
		t = float(arr[0])
		if t_first == -1:
			t_first = t
			t = 0
		else:
			t -= t_first
		op = arr[1]
		if op == 'acc': acc.append([t, float(arr[2]), float(arr[3]), float(arr[4])])
		if op == 'gyr': gyr.append([t, float(arr[2]), float(arr[3]), float(arr[4])])
		if op == 'gra': gra.append([t, float(arr[2]), float(arr[3]), float(arr[4])])
	f.close()
	print('t_first:', t_first)
	return np.array(acc), np.array(gyr), np.array(gra)

def read_file2(filename):
	t = t0 = -1
	acc = []
	att = []
	rot = []
	f = open(filename, 'r')
	line = -1
	while True:
		line += 1
		s = f.readline()
		if len(s) <= 0:
			break
		arr = s[:-1].split(' ')
		op = arr[0]
		if op == 'time':
			if t == -1: t0 = float(arr[1])
			t = float(arr[1]) - t0
		if op == 'acc': acc.append([t, float(arr[1]), float(arr[2]), float(arr[3])])
		if op == 'att': att.append([t, float(arr[1]), float(arr[2]), float(arr[3])])
		if op == 'rot': rot.append([t, float(arr[1]), float(arr[2]), float(arr[3])])
	f.close()
	return np.array(acc), np.array(att), np.array(rot)

def resample(a, t1=None, stride=20):
	shape = a.shape
	t = a[0,0]
	if t1 is None:
		t1 = a[shape[0]-1,0]
	b = []
	i = 0
	while t < t1:
		while i < shape[0] and a[i,0] < t: i += 1
		sl = (t - a[i-1,0]) / (a[i,0] - a[i-1,0])
		sr = (a[i,0] - t) / (a[i,0] - a[i-1,0])
		b.append([a[i-1,j] * sr + a[i,j] * sl for j in range(1, shape[1])])
		t += stride
	b = np.array(b)
	print(b.shape)
	return b

def bias(a0, a1, bias0 = 0, bias1 = 0):
	a0 = a0[bias0:,]
	a0[:,0] -= a0[0,0]
	a1 = a1[bias1:,]
	a1[:,0] -= a1[0,0]
	return a0, a1

def conv(a0, a1, window=5, std_threshold=5, amplitude_threshold=9.8):
    w = window
    sth = std_threshold
    ath = amplitude_threshold
    d = []
    L = a0.shape[0]
    for i in range(L):
        if i + w >= L:
            d.append(0)
            continue
        a = a0[i:i+w]
        b = a1[i:i+w]
        a = a - a.mean(axis=0)
        b = b - b.mean(axis=0)
        #a = (np.abs(a) > ath) * a
        #b = (np.abs(b) > ath) * b
        a = np.linalg.norm(a, axis=1)
        b = np.linalg.norm(b, axis=1)
        a = a / max(sth, a.std())
        b = b / max(sth, a.std())
        # convolve: full, valid, same
        c = np.convolve(a, b, 'same')
        d.append(c.max())
    return np.array(d)

def windowed_normalize(a, window=30):
	shape = a.shape
	w = int(window/2)
	b = []
	i = w
	while i + w < shape[0]:
		c = a[i - w : i + w]
		c = (c[w] - c.mean(axis=0)) / c.std(axis=0)
		b.append(c)
		i += 1
	return np.array(b)

def highpass_filter(a, btc=0.4, level=3):
    coeff_b, coeff_a = signal.butter(level, btc, 'highpass')
    return signal.filtfilt(coeff_b, coeff_a, a, axis=0)

def kalman_filter(obs, q=0.01):
    n = obs.shape[0]
    x = np.zeros((n))
    x[0] = obs[0]
    p = q
    for i in range(1, n):
        k = math.sqrt(p * p + q * q)
        h = math.sqrt(k * k / (k * k + q * q))
        x[i] = obs[i] * h + x[i-1] * (1 - h)
        p = math.sqrt((1 - h) * k * k)
    return x