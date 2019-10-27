import cv2
import matplotlib.pyplot as plt
import numpy as np
import sys
import time
from sklearn.metrics import confusion_matrix

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
		if ges != 'noise':
			a = a[:10]
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
				if g == 0:
					lb = 0
				else:
					lb = 1
				if v != u:
					data  .append( feature(raw[v][g]) )
					label .append( [lb] * n           )
				else:
					data2 .append( feature(raw[v][g]) )
					label2.append( [lb] * n           )

		noise_wristrot = np.load('walking/NNNOISE/noise_wristrot_1000.npy')
		nnwr = noise_wristrot.shape[0]
		nnwrt = int(nnwr * 0.8)
		data.append(feature(noise_wristrot[:nnwrt]))
		label.append([0] * nnwrt)
		data2.append(feature(noise_wristrot[nnwrt:]))
		label2.append([0] * (nnwr-nnwrt))

		data   = np.concatenate(data,   axis=0).astype(np.float32)
		label  = np.concatenate(label,  axis=0)
		data2  = np.concatenate(data2,  axis=0).astype(np.float32)
		label2 = np.concatenate(label2, axis=0)

		svm = cv2.ml.SVM_create()
		svm.setType(cv2.ml.SVM_C_SVC)
		svm.setKernel(cv2.ml.SVM_RBF)
		svm.trainAuto(data, cv2.ml.ROW_SAMPLE, label)
		
		res = np.array(svm.predict(data2)[1]).reshape(label2.shape[0])
		acc = 1 - len(np.nonzero(np.abs(res - label2) > 0.1)[0]) / label2.shape[0]
		print('acc:', acc)
		acc_all += acc

		for i in range(res.shape[0]):
			conf[int(label2[i]), int(res[i])] += 1
		# plot_confusion_matrix(label2, res, gess)
	print('mean acc = ', acc_all / len(users))
	
	conf = conf.astype(int)
	precis = conf[1, 1] / (conf[0, 1] + conf[1, 1])
	recall = conf[1, 1] / (conf[1, 0] + conf[1, 1])
	print('')
	print(conf)
	print('precis: ', precis)
	print('recall: ', recall)

elif ctype == 'all':
	data = []
	label = []
	for u in range(len(users)):
		print('\n' + users[u])
		for g in range(len(gess)):
			n = raw[u][g].shape[0]
			if g == 0:
				lb = 0
			else:
				lb = 1
			data  .append( feature(raw[u][g]) )
			label .append( [lb] * n           )

	noise_wristrot = np.load('walking/NNNOISE/noise_wristrot_1000.npy')
	data.append(feature(noise_wristrot))
	label.append([0] * noise_wristrot.shape[0])

	data   = np.concatenate(data,   axis=0).astype(np.float32)
	label  = np.concatenate(label,  axis=0)
	svm = cv2.ml.SVM_create()
	svm.setType(cv2.ml.SVM_C_SVC)
	svm.setKernel(cv2.ml.SVM_RBF)
	svm.trainAuto(data, cv2.ml.ROW_SAMPLE, label)
	svm.save('detect_' + condition + '.model')

