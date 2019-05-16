#!/usr/bin/python
# -*- coding: UTF-8 -*-
import os
import matplotlib.pyplot as plt
from PIL import Image
import random

plt.rcParams['font.family'] = ['Adobe Heiti Std']

filenames = ['IxP', 'IxB', 'IxI', 'IxFU', 'IxG', 'FUxFU', 'DxU', 'FDxFU', 'PxFU', 'FDxP']
titles = ['手指点手掌', '手指点手背', '手指点手指', '手指点拳上侧', '手指点关节', '拳上侧相碰', '手下侧碰手上侧', '拳下侧碰拳上侧', '手掌碰拳上侧', '拳下侧碰手掌']

username = 'ycy'

n = len(filenames)
x = [i for i in range(n)]
random.shuffle(x)

f = open('order.txt', 'a')
f.write(username + ': ' + str(x) + '\n')
f.close()

for j in range(n):
	if j == 0 or j == 5:
		plt.figure(100 + j)
		plt.plot([1])
		plt.title('拍手校准')
		plt.show()
	i = x[j]
	# if i == 6: continue
	img = Image.open('figures/' + filenames[i] + '.jpg')
	plt.figure(j+1)
	plt.imshow(img)
	plt.title(titles[i])
	plt.show()
