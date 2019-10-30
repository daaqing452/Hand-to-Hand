import matplotlib.pyplot as plt
import numpy as np
import sys
import time
import cv2
from sklearn.metrics import confusion_matrix


condition = sys.argv[1]
# ctype = sys.argv[2]
users = ['hbs', 'wxy', 'zmy', 'xcn', 'gyz', 'xsc', 'lzp', 'wjy', 'wzh', 'cs']
if len(sys.argv) > 3 and ctype == 'within':
	users = [sys.argv[3]]
gess = ['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU']
gess_name = ['ItP', 'ItB', 'FBtP', 'PtFT', 'FBtFT']

raw = []
for user in users:
	rawu = []
	for ges in gess:
		a = np.load(condition + '/' + user + '/' + ges + '.npy')
		rawu.append(a.swapaxes(1, 2))
	raw.append(rawu)

# plot
if False:
	for i in range(4):
		for j in range(3):
			plt.subplot(6, 4, j*4+i+1)
			for k in range(3):
				plt.plot(raw[0][i][k, j+10])
	plt.show()

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

cms = np.zeros((len(gess), len(gess)))
data = []
label = []
data2 = []
label2 = []

for v in range(len(users)):
	for g in range(len(gess)):
		n = raw[v][g].shape[0]
		data  .append( feature(raw[v][g]) )
		label .append( [g] * n            )

data   = np.concatenate(data,   axis=0).astype(np.float32)
label  = np.concatenate(label,  axis=0)

svm = cv2.ml.SVM_create()
svm.setType(cv2.ml.SVM_C_SVC)
svm.setKernel(cv2.ml.SVM_RBF)
print('start training...')
svm.trainAuto(data, cv2.ml.ROW_SAMPLE, label)
svm.save('recognition_' + condition + '.model')

res = np.array(svm.predict(data)[1]).reshape(label.shape[0])
acc = 1 - len(np.nonzero(np.abs(res - label) > 0.1)[0]) / label.shape[0]
print('acc:', acc)
cm = confusion_matrix(label, res)
cms += cm

def plot_confusion_matrix(cm, classes, normalize=False, title=None, cmap=plt.cm.Blues):
    """
    This function prints and plots the confusion matrix.
    Normalization can be applied by setting `normalize=True`.
    """
    if not title:
        if normalize:
            title = 'Normalized confusion matrix 100 %'
        else:
            title = 'Confusion matrix, without normalization'

    # Compute confusion matrix
    # cm = confusion_matrix(y_true, y_pred)
    
    # Only use the labels that appear in the data
    # classes = classes[unique_labels(y_true, y_pred)]
    if normalize:
        cm = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis] * 100
        print("Normalized confusion matrix")
    else:
        print('Confusion matrix, without normalization')

    print(cm)

    fig, ax = plt.subplots()
    im = ax.imshow(cm, interpolation='nearest', cmap=cmap)
    ax.figure.colorbar(im, ax=ax)
    # We want to show all ticks...
    ax.set(xticks=np.arange(cm.shape[1]),
           yticks=np.arange(cm.shape[0]),
           # ... and label them with the respective list entries
           # xticklabels=classes,
           # yticklabels=classes,
           # title=title,
           # ylabel='True label',
           # xlabel='Predicted label'
           )

    ax.set_title(label=title, fontdict={'fontsize': 10})
    ax.set_xticklabels(labels=classes, fontdict={'fontsize': 9})
    ax.set_yticklabels(labels=classes, fontdict={'fontsize': 9})

    # Rotate the tick labels and set their alignment.
    # plt.setp(ax.get_xticklabels(), rotation=45, ha="right",
    #        rotation_mode="anchor", fontsize=9)

    # Loop over data dimensions and create text annotations.
    fmt = '.1f' if normalize else 'd'
    thresh = cm.max() / 2.
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            t = format(cm[i, j], fmt)
            if cm[i, j] == 100: t = '100'
            # t += '%'
            ax.text(j, i, t,
                    ha="center", va="center",
                    color="white" if cm[i, j] > thresh else "black")
    fig.tight_layout()
    return ax

plot_confusion_matrix(cms, gess_name, normalize=True)
