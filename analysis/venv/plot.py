import matplotlib.pyplot as plt
import numpy as np
import sys
from utils import *

filename_l = "../data/log_left.txt"
filename_r = "../data/log_right.txt"
#acc0, gyr0, gra0 = read_file(filename_l)
#acc1, gyr1, gra1 = read_file(filename_r)
#acc0 = np.array(acc0)
#acc1 = np.array(acc1)

acc0, gyr0, gra0 = read_file2(filename_l)
acc1, gyr1, gra1 = read_file2(filename_r)

zl = 200
zr = 1000

plt.subplot(211)
plt.plot(acc0[zl:zr,1])
plt.subplot(212)
plt.plot(acc1[zl:zr,1])

'''plt.figure(1)
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(acc0[zl:zr, i+1])
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(acc1[zl:zr, i+1])'''

'''plt.figure(2)
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gyr0[zl:zr, i])
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gyr1[zl:zr, i])

plt.figure(3)
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gra0[zl:zr, i])
for i in range(3):
	plt.subplot(3, 1, i+1)
	plt.plot(gra1[zl:zr, i])'''

plt.show()
