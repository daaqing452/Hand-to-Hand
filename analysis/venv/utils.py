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
		t = int(arr[0])
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

def resample(a, stride=20):
	lena = len(a)
	t = a[0][0]
	t1 = a[lena-1][0]
	b = []
	i = 0
	while t < t1:
		while i < lena and a[i][0] < t: i += 1
		sl = (t - a[i-1][0]) / (a[i][0] - a[i-1][0])
		sr = (a[i][0] - t) / (a[i][0] - a[i-1][0])
		b.append([a[i-1][j] * sr + a[i][j] * sl for j in range(1, len(a[i]))])
		t += stride
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