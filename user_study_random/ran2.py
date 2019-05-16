#!/usr/bin/python
# -*- coding: UTF-8 -*-
import os
import matplotlib.pyplot as plt
from PIL import Image
import random

plt.rcParams['font.family'] = ['Adobe Heiti Std']

filenames = ['IyPl', 'IyPr', 'IyPu', 'IyPd', 'IyUl', 'IyUr']
titles = ['左划手掌', '右划手掌', '上划手掌', '下划手掌', '左划手上侧', '右划手上侧']

username = 'fjy'

n = len(filenames)
x = [i for i in range(n)]
random.shuffle(x)

f = open('order2.txt', 'a')
f.write(username + ': ' + str(x) + '\n')
f.close()

for j in range(n):
	if j == 0:
		plt.figure(100 + j)
		plt.plot([1])
		plt.title('拍手校准')
		plt.show()
	i = x[j]
	img = Image.open('figures/' + filenames[i] + '.jpg')
	plt.figure(j+1)
	plt.imshow(img)
	plt.title(titles[i])
	plt.show()
