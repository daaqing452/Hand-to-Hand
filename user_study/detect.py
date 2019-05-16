import matplotlib.pyplot as plt
import numpy as np
import sys
import time
from sklearn import svm
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import cross_val_score
from sklearn.model_selection import ShuffleSplit
from sklearn.utils.multiclass import unique_labels

condition = sys.argv[1]
ctype = sys.argv[2]
users = ['hbs', 'wxy', 'zmy', 'xcn', 'gyz', 'xsc', 'lzp', 'wjy', 'wzh', 'cs']
if len(sys.argv) > 3 and ctype == 'within':
	users = [sys.argv[3]]
gess = ['noise', 'IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU']

raw = []
for user in users:
	rawu = []
	for ges in gess:
		# print(user)
		a = np.load(condition + '/' + user + '/' + ges + '.npy')
		if ges != 'noise': a = a[:10]
		rawu.append(a.swapaxes(1, 2))
	raw.append(rawu)

def feature_axis(a):
	n = a.shape[0]
	f_max = a.max(axis=1).reshape(n, 1)
	f_min = a.min(axis=1).reshape(n, 1)
	f_mean = a.mean(axis=1).reshape(n, 1)
	f_std = a.std(axis=1).reshape(n, 1)
	f = np.concatenate([f_max, f_min, f_mean, f_std], axis=1)
	return f

def feature(a):
	f = []
	for i in range(26):
		if i >= 6 and i <= 9: continue
		if i == 12: continue
		if i >= 19 and i <= 22: continue
		if i == 25: continue
		f.append(feature_axis(a[:, i]))
	f = np.concatenate(f, axis=1)
	return f

# within user
if ctype == 'within':
	for u in range(len(users)):
		print('\n' + users[u])
		data = []
		label = []

		for g in range(len(gess)):
			n = raw[u][g].shape[0]
			lb = 0
			if g == 0: lb = 1
			data .append( feature(raw[u][g]) )
			label.append( [lb] * n           )

		data  = np.concatenate(data,  axis=0)
		label = np.concatenate(label, axis=0)
		n = data.shape[0]

		arr = np.arange(n)
		np.random.shuffle(arr)
		data2  = np.array([ data[arr[i]] for i in range(n)])
		label2 = np.array([label[arr[i]] for i in range(n)])

		clf = svm.SVC()
		seed = int(time.time() * 1000000) % 2176783647
		cv = ShuffleSplit(n_splits=100, test_size=0.2, random_state=seed)
		score = cross_val_score(clf, data2, label2, cv=cv)
		print('cross-val:', score.mean())

		clf = svm.SVC()
		m = int(n*0.8)
		clf.fit(data2[:m], label2[:m])
		res = clf.predict(data2[m:])
		plot_confusion_matrix(label2[m:], res, gess)

# between user
if ctype == 'between':
	acc_all = 0
	conf = np.zeros((2, 2))
	for u in range(len(users)):
		print('\n' + users[u])
		data = []
		label = []
		data2 = []
		label2 = []

		for v in range(len(users)):
			for g in range(len(gess)):
				n = raw[v][g].shape[0]
				lb = 0
				if g == 0: lb = 1
				if v != u:
					data  .append( feature(raw[v][g]) )
					label .append( [lb] * n           )
				else:
					data2 .append( feature(raw[v][g]) )
					label2.append( [lb] * n           )

		data   = np.concatenate(data,   axis=0)
		label  = np.concatenate(label,  axis=0)
		data2  = np.concatenate(data2,  axis=0)
		label2 = np.concatenate(label2, axis=0)
		if u == 0:
			print(data.shape)
			print(data2.shape)

		clf = svm.SVC()
		clf.fit(data, label)
		res = clf.predict(data2)
		acc = 1 - len(np.nonzero(res != label2)[0]) / label2.shape[0]
		print('acc:', acc)
		acc_all += acc

		for i in range(res.shape[0]):
			conf[label2[i], res[i]] += 1
		# plot_confusion_matrix(label2, res, gess)
	print('mean acc = ', acc_all / len(users))

	conf = conf.astype(int)
	precis = conf[1, 1] / (conf[0, 1] + conf[1, 1])
	recall = conf[1, 1] / (conf[1, 0] + conf[1, 1])
	print('')
	print(conf)
	print('precis: ', precis)
	print('recall: ', recall)
