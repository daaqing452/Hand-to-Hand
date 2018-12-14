import numpy as np


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
	return np.array(acc), np.array(gyr), np.array(gra)

def read_file2(filename):
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
		op = arr[0]
		if op == 'acc': acc.append([float(arr[1]), float(arr[2]), float(arr[3])])
		if op == 'gyr': gyr.append([float(arr[1]), float(arr[2]), float(arr[3])])
		if op == 'gra': gra.append([float(arr[1]), float(arr[2]), float(arr[3])])
	f.close()
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