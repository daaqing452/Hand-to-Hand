import numpy as np
import matplotlib.pyplot as plt
import time
from sklearn.model_selection import cross_val_score
from sklearn.model_selection import ShuffleSplit
from sklearn import svm

def leave_out(a):
	n = a.shape[0]
	raw = []
	for i in range(18):
		raw.append(a[:,i:900:18])
	sid = [	0, 1, 2,
			3, 4, 5,
			#6, 7, 8,
			9, 10, 11,
			12, 13, 14,
			#15, 16, 17
		]
	signals = [raw[i] for i in sid]
	f_mean = np.array([s.mean(axis=1) for s in signals])
	f_max = np.array([s.max(axis=1) for s in signals])
	#f_min = np.array([s.min(axis=1) for s in signals])
	f_order = np.array([s.argmax(axis=1) < s.argmin(axis=1) for s in signals])
	a = np.concatenate([f_mean, f_max], axis=0).T
	return np.array(a)

pos = np.load('palm_np.npy')
noise0 = np.load('noise_np.npy')
noise1 = np.load('noise_16_np.npy')
noise2 = np.load('back_np.npy')
noise3 = np.load('fist_np.npy')

data = np.concatenate((pos, noise0, noise1, noise2, noise3), axis=0)
label = np.zeros((data.shape[0]))4
label[:pos.shape[0]] = np.ones((pos.shape[0]))

data = leave_out(data)
print(data.shape, label.shape)

if False:
	for i in range(10):
		plt.figure()
		for j in range(18):
			plt.subplot(6, 3, j+1)
			plt.plot(noise[i*10, j:900:18])
		plt.show()

clf = svm.SVC()
seed = int(time.time() * 1000000) % 2176783647
cv = ShuffleSplit(n_splits=100, test_size=0.2, random_state=seed)
score = cross_val_score(clf, data, label, cv=cv)
print(score)
print(score.mean())