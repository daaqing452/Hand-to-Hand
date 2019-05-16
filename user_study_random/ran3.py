#!/usr/bin/python
# -*- coding: UTF-8 -*-
import os
import matplotlib.pyplot as plt
from PIL import Image
import random
import sys

plt.rcParams['font.family'] = ['Adobe Heiti Std']

ges = ['IxP', 'IxB', 'FDxP', 'PxFU', 'FDxFU']
con = ['walking', 'running']

username = sys.argv[1]

n = len(ges)

f = open('order3.txt', 'a')
for k in range(2):
	f.write(username + ', ' + con[k] + '\n')
	for j in range(10):
		x = [ges[i] for i in range(n)]
		random.shuffle(x)
		f.write(str(x) + ',\n')
	f.write('\n')

f.close()
