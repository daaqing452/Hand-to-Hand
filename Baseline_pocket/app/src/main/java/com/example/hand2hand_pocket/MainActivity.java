package com.example.hand2hand_pocket;

import androidx.appcompat.app.AppCompatActivity;

import android.app.NotificationManager;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.speech.tts.TextToSpeech;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Random;

public class MainActivity extends AppCompatActivity {

    final String TAG = "baseline";
    final int T_DELAY = 10000;
    final int N_COMMAND = 20;

    TextView label0;
    Button buttonExp;
    ButtonOnClickListener listener;
    TextToSpeech tts;

    boolean experimenting = false;
    int nCommand = 0;
    PrintWriter writer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        tts = new TextToSpeech(MainActivity.this, new TextToSpeech.OnInitListener() {
            @Override
            public void onInit(int status) {
                if (status == TextToSpeech.SUCCESS) {
                    Log.d(TAG, "onInit: TTS引擎初始化成功");
                }
                else{
                    Log.d(TAG, "onInit: TTS引擎初始化失败");
                }
            }
        });
        tts.setSpeechRate(1.0f);

        label0 = findViewById(R.id.label0);
        buttonExp = findViewById(R.id.button_exp);
        Button buttonAnswerCall = findViewById(R.id.button_answercall);
        Button buttonRejectCall = findViewById(R.id.button_rejectcall);
        Button buttonPlayPause = findViewById(R.id.button_playpause);
        Button buttonPrevMusic = findViewById(R.id.button_prevmusic);
        Button buttonNextMusic = findViewById(R.id.button_nextmusic);
        Button buttonReadMessage = findViewById(R.id.button_readmessage);
        Button buttonDeleteMessage = findViewById(R.id.button_deletemessage);
        Button buttonReplyMessage = findViewById(R.id.button_replymessage);

        buttonExp.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (experimenting) {
                    writer.close();
                    buttonExp.setText("Exp. End");
                    label0.setText("Hello World");
                    experimenting = false;
                } else {
                    Calendar calendar = Calendar.getInstance();
                    int year = calendar.get(Calendar.YEAR);
                    int month = calendar.get(Calendar.MONTH) + 1;
                    int day = calendar.get(Calendar.DATE);
                    int hour = calendar.get(Calendar.HOUR_OF_DAY);
                    int minute = calendar.get(Calendar.MINUTE);
                    int second = calendar.get(Calendar.SECOND);
                    String fileName = "baseline_" + year + month + day + hour + minute + second + ".txt";
                    try {
                        writer = new PrintWriter(new OutputStreamWriter(new FileOutputStream(Environment.getExternalStorageDirectory().getPath() + "/" + fileName)));
                    } catch (Exception e) {
                        Log.d(TAG, e.toString());
                    }
                    log("start");
                    buttonExp.setText("Exp. Start");
                    nCommand = 0;
                    Log.d(TAG, "start");
                    experimenting = true;
                    tts.speak("任务开始", TextToSpeech.QUEUE_FLUSH, null, null);
                    issueStimuli();
                }
            }
        });

        listener = new ButtonOnClickListener();
        buttonAnswerCall.setOnClickListener(listener);
        buttonRejectCall.setOnClickListener(listener);
        buttonPlayPause.setOnClickListener(listener);
        buttonPrevMusic.setOnClickListener(listener);
        buttonNextMusic.setOnClickListener(listener);
        buttonReadMessage.setOnClickListener(listener);
        buttonDeleteMessage.setOnClickListener(listener);
        buttonReplyMessage.setOnClickListener(listener);
    }

    void issueStimuli() {
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                nCommand++;
                label0.setText("" + nCommand);
                int command = rand() % 5;
                String[] nameList = new String[] {"张子豪", "郭英超", "陈远杰", "马玉涛", "周翔", "陈佳颖", "王雨涵", "吴哲宇", "陶红杰", "陈阳"};
                switch (command) {
                    case 0:
                        int i = rand() % nameList.length;
                        tts.speak("来电提示：" + nameList[i], TextToSpeech.QUEUE_FLUSH, null, null);
                        break;
                    case 1:
                        tts.speak("来电提示：骚扰电话", TextToSpeech.QUEUE_FLUSH, null, null);
                        break;
                    case 2:
                        tts.speak("播放音乐", TextToSpeech.QUEUE_FLUSH, null, null);
                        break;
                    case 3:
                        tts.speak("上一首音乐", TextToSpeech.QUEUE_FLUSH, null, null);
                        break;
                    case 4:
                        tts.speak("下一首音乐", TextToSpeech.QUEUE_FLUSH, null, null);
                        break;
                    default:
                        break;
                }
                log("stimuli " + command);
            }
        }, T_DELAY);
    }

    int rand() {
        return Math.abs(new Random().nextInt());
    }

    void log(String s) {
        if (experimenting && writer != null) {
            s = System.currentTimeMillis() + " " + s;
            writer.println(s);
        }
    }

    void notify2(int type) {
        Uri uri = RingtoneManager.getDefaultUri(type);
        Ringtone rt = RingtoneManager.getRingtone(getApplicationContext(), uri);
        rt.play();
    }



    class ButtonOnClickListener implements View.OnClickListener {
        @Override
        public void onClick(View view) {
            if (experimenting) {
                log("click " + view.getTag());
                if (nCommand < N_COMMAND) {
                    notify2(2);
                    issueStimuli();
                } else {
                    tts.speak("任务结束", TextToSpeech.QUEUE_FLUSH, null, null);
                    Log.d(TAG, "finish");
                    buttonExp.performClick();
                }
            }
        }
    }
}

