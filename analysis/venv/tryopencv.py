import cv2
import numpy as np

svm = cv2.ml.SVM_create()
svm.setType(cv2.ml.SVM_C_SVC)
svm.setKernel(cv2.ml.SVM_RBF)

trainData = np.array([[0,0],[0,1],[1,0],[1,1]], dtype=np.float32)
labels = np.array([0,1,1,0])

svm.train(trainData, cv2.ml.ROW_SAMPLE, labels)
svm.save('a.model')

print('train finished!')

results = svm.predict(trainData)[1]
print(results)