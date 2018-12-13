import matplotlib.pyplot as plt
import numpy as np

filename = "../log_test_buffer21.txt"

t_pre = 0
t_list = []
f = open(filename, 'r')
line = -1
while True:
    line += 1
    s = f.readline()
    if len(s) <= 0:
        break
    arr = s[:-1].split(' ')
    if arr[0] == 'time':
        t = int(arr[1])
        if line != 0: t_list.append(t - t_pre)
        t_pre = t
f.close()

t_list.sort()
t_list = np.array(t_list)
print(t_list.max())
print(t_list.mean())
print(t_list.std())

plt.subplot(211)
plt.hist(t_list, bins=400)
plt.show()