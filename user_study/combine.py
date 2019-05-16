import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

PLOT_ACC 	= False

orders = [
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU'],
]

f = {'IxP': [], 'IxB': [], 'FDxP': [], 'PxFU': [], 'FDxFU': []}

for i in range(10):
	data = np.load(str(i) + '.npy')
	print(data.shape[0])
	for j in range(5):
		f[orders[i][j]].append(data[j*5:j*5+5])
for key in f:
	f[key] = np.concatenate(f[key], axis=0)
	print(key, f[key].shape)
	np.save(key + '.npy', f[key])