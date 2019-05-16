import json
from django.http import HttpResponse, HttpResponseRedirect
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def index(request):
	op = request.POST.get('op', '')
	if op == 'submit':
		info = json.loads(request.POST.get('info'))
		score = json.loads(request.POST.get('score'))
		comments = json.loads(request.POST.get('comments'))
		name = info['name']
		
		f = open('media/info-' + name + '.csv', 'w')
		f.write('姓名,性别,年龄,利手,学号,专业度\n');
		f.write(name + ',' + info['gender'] + ',' + info['age'] + ',' + info['handness'] + ',' + info['student_id'] + ',' + info['expertise'] + '\n\n')
		f.write('name,gesture,comments\n')
		for ges in comments:
			f.write(name + ',' + ges + ',' + comments[ges] + '\n')
		f.close()
		
		f = open('media/score-' + name + '.csv', 'w')
		f.write('姓名,手势,属性,得分\n')
		for i in range(len(score)):
			s = score[i]
			pros = ['容易完成', '记忆', '接受度', '混淆度']
			for j in range(4):
				f.write(name + ',' + s['ges'] + ',' + pros[j] + ',' + str(s['score'][j]) + '\n')
		f.close()
		
		return HttpResponse(json.dumps({'result': 'yes'}))
	return render(request, 'index.html', {})