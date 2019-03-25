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
	qua = []
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
		if op == 'qua': qua.append([t, float(arr[1]), float(arr[2]), float(arr[3]), float(arr[4])])
	f.close()
	return np.array(acc), np.array(att), np.array(rot), np.array(qua)

def resample(a, t1=None, stride=20, norm='linear'):
	shape = a.shape
	t = a[0,0]
	if t1 is None:
		t1 = a[shape[0]-1,0]
	b = []
	i = 0
	j = 0
	while t < t1:
		while i+1 < shape[0] and a[i+1,0] <= t: i += 1
		while j < shape[0] and a[j,0] < t: j += 1
		if i == j:
			b.append(a[i,1:])
			t += stride
			continue
		sl = (t - a[i,0]) / (a[j,0] - a[i,0])
		sr = (a[j,0] - t) / (a[j,0] - a[i,0])
		if norm == 'linear':
			bb = [sr * a[i,k] + sl * a[j,k] for k in range(1, shape[1])]
		elif norm == 'sphere':
			costh = a[i,1]*a[j,1] + a[i,2]*a[j,2] + a[i,3]*a[j,3] + a[i,4]*a[j,4]
			if costh < 0:
				a[j,1:] = -a[j,1:]
				costh = a[i,1]*a[j,1] + a[i,2]*a[j,2] + a[i,3]*a[j,3] + a[i,4]*a[j,4]
			costh = min(costh, 1)
			th = math.acos(costh)
			if th < 1e-3:
				bb = a[i,1:]
			else:
				bb = [(math.sin(sr*th) * a[i,k] + math.sin(sl*th) * a[j,k]) / math.sin(th) for k in range(1, shape[1])]
		b.append(bb)
		t += stride
	b = np.array(b)
	return b

def bias(a0, a1, bias0 = 0, bias1 = 0):
	a0 = a0[bias0:,]
	a0[:,0] -= a0[0,0]
	a1 = a1[bias1:,]
	a1[:,0] -= a1[0,0]
	n = min(a0.shape[0], a1.shape[0])
	a0 = a0[:n]
	a1 = a1[:n]
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

def print_timestamp_quality(t0, t1):
	t0 = np.diff(t0) * 1000
	t1 = np.diff(t1) * 1000
	t0.sort()
	t1.sort()
	print('T0:', t0.mean(), t0.std(), t0[:5], t0[-5:])
	print('T1:', t1.mean(), t1.std(), t1[:5], t1[-5:])

def qua_mean_filter(qua, w=2):
	n = qua.shape[0]
	quaq = []
	for i in range(n):
		a = qua[max(0,i-w//2):min(n-1,i+w//2)]
		M = np.dot(a.T, a) / a.shape[0]
		eigvalue, eigvector = np.linalg.eig(M)
		quaq.append(eigvector[0])
	return np.array(quaq)

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

