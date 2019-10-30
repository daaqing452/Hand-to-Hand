import cv2
import numpy as np
import math
import sys
import matplotlib.pyplot as plt
from utils import *

svm = cv2.ml.SVM_load('models/detect_walking_what.model')

filename = sys.argv[1]
filename0 = filename + 'L.txt'
filename1 = filename + 'R.txt'
acc0r, att0r, rot0r, qua0r = read_file2(filename0)
acc1r, att1r, rot1r, qua1r = read_file2(filename1)

n = min(acc0r.shape[0], acc1r.shape[0])
acc0r = acc0r[:n]
acc1r = acc1r[:n]
print('acc raw shape:', n)

def feature_axis(a):
	f_max = a.max()
	f_min = a.min()
	f_mean = a.mean()
	f_std = a.std()
	f = [f_max, f_min, f_mean, f_std]
	return f

win = 50
data = []
for i in range(0, n-win, win//2):
	f = []
	for j in range(3): f.extend( feature_axis(acc0r[i:i+win,j+1]) )
	for j in range(3): f.extend( feature_axis(rot0r[i:i+win,j+1]) )
	for j in range(2): f.extend( feature_axis(att0r[i:i+win,j+1]) )
	for j in range(3): f.extend( feature_axis(acc1r[i:i+win,j+1]) )
	for j in range(3): f.extend( feature_axis(rot1r[i:i+win,j+1]) )
	for j in range(2): f.extend( feature_axis(att1r[i:i+win,j+1]) )
	data.append(f)

data = np.array(data).astype(np.float32)
np.save('noise/what.npy', data)
label = np.zeros((data.shape[0]))

res = np.array(svm.predict(data)[1]).reshape(label.shape[0])
print(res.shape)
wrong = len(np.nonzero(np.abs(res - label) > 0.1)[0])
acc = 1 - wrong / label.shape[0]
print('acc:', acc, wrong, '/', label.shape[0])

plt.subplot(3, 1, 1)
plt.plot(acc0r[:, 1:4])
plt.subplot(3, 1, 2)
plt.plot(acc1r[:, 1:4])
plt.subplot(3, 1, 3)
plt.plot(res)
plt.show()