import matplotlib.pyplot as plt
import numpy as np
import wave

def read_wav(filename):
	f = wave.open(filename, 'rb')
	params = f.getparams()
	nchannels, sampwidth, framerate, nframes = params[:4]
	print(nchannels, sampwidth, framerate, nframes)
	str_data = f.readframes(nframes)
	f.close()
	wave_data = np.fromstring(str_data, dtype=np.short)
	return wave_data

tag = 'IyP(urdl)'
wavel = read_wav('../log-' + tag + '-WatchL.wav')
waver = read_wav('../log-' + tag + '-WatchR.wav')

plt.subplot(311)
plt.plot(wavel)
plt.subplot(312)
plt.plot(waver)
plt.show()