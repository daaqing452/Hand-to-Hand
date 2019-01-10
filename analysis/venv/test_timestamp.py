import matplotlib.pyplot as plt
import numpy as np

filename = "../log-2019-01-10-11-43-36-.txt"

t_pre = [0, 0, 0, 0]
t_list = [[], [], [], []]
f = open(filename, 'r')
line = -1
while True:
    line += 1
    s = f.readline()
    if len(s) <= 0:
        break
    arr = s[:-1].split(' ')
    t = float(arr[0])
    op = arr[1]
    k = -1
    if op == 'acc': k = 0
    if op == 'gyr': k = 1
    if op == 'gra': k = 2
    if t_pre[k] != 0:
        if t < t_pre[k]:
            print(line, t)
        t_list[k].append(t - t_pre[k])
    t_pre[k] = t
f.close()

t_list[0].sort()
#t_list[1].sort()
#t_list[2].sort()
t_list[0] = np.array(t_list[0])[0:]
#t_list[1] = np.array(t_list[1])[0:]
#t_list[2] = np.array(t_list[2])[0:]
print(t_list[0].min(), t_list[0].max(), t_list[0].mean(), t_list[0].std())
#print(t_list[1].min(), t_list[1].max(), t_list[1].mean(), t_list[1].std())
#print(t_list[2].min(), t_list[2].max(), t_list[2].mean(), t_list[2].std())

plt.subplot(311)
plt.hist(t_list[0], bins=400)
#plt.subplot(312)
#plt.hist(t_list[1], bins=400)
#plt.subplot(313)
#plt.hist(t_list[2], bins=400)
plt.show()
