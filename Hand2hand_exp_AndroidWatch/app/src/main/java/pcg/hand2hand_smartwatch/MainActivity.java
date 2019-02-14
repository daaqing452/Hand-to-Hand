package pcg.hand2hand_smartwatch;

import android.hardware.SensorManager;
import android.os.Bundle;
import android.support.wearable.activity.WearableActivity;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import java.io.File;
import java.io.FileOutputStream;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.logging.Logger;

public class MainActivity extends WearableActivity {
    final boolean ENABLE_MICROPHONE = false;

    // ui
    TextView uText0, uText1, uText2;
    Button uButtonLog, uButtonConnect;
    EditText uEditIP;

    // log
    long startTime;
    File fileDirectory;
    PrintWriter logger;
    String logBuffer;
    boolean isLogging;

    // network
    Network network;

    // microphone
    Microphone microphone;

    // inertial
    SensorManager sensorManager;
    InertialSensor inertialSensor;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        uText0 = findViewById(R.id.text0);
        uText1 = findViewById(R.id.text1);
        uText2 = findViewById(R.id.text2);
        uButtonLog = findViewById(R.id.button_log);
        uButtonConnect = findViewById(R.id.button_connect);
        uEditIP = findViewById(R.id.editIP);

        uButtonLog.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                changeLogStatus(0);
            }
        });

        uButtonConnect.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                network.Connect(uEditIP.getText().toString());
            }
        });

        // Enables Always-on
        setAmbientEnabled();

        onCreateLogger();
        onCreateMicrophone();
        onCreateInertial();

        startTime = System.currentTimeMillis();
        network = new Network(this);
    }

    void onCreateLogger() {
        fileDirectory = this.getApplicationContext().getExternalFilesDir(null);
        logBuffer = "";
        isLogging = false;
    }

    void onCreateMicrophone() {
        microphone = new Microphone(this);
        if (ENABLE_MICROPHONE) microphone.start();
    }

    void onCreateInertial() {
        sensorManager = (SensorManager)getSystemService(SENSOR_SERVICE);
        inertialSensor = new InertialSensor(this);
    }

    void logToFile0(String tag, Object... param) {
        if (!isLogging) return;
        synchronized (logBuffer) {
            logBuffer += tag;
            switch (tag) {
                case "acc":
                case "gyr":
                case "gra":
                    float[] values0 = (float[]) param[0];
                    logBuffer += String.format(" %.5f %.5f %.5f", values0[0], values0[1], values0[2]);
                    break;
                case "meg":float[] values1 = (float[]) param[0];
                    logBuffer += String.format(" %.1f %.1f %.1f", values1[0], values1[1], values1[2]);
                    break;
                case "mic":
                    byte[] values2 = (byte[]) param[0];
                    for (byte value : values2) {
                        logBuffer += " " + value;
                        break;
                    }
                    break;
                case "time":
                    logBuffer += " " + System.currentTimeMillis();
                    break;
            }
            logBuffer += "\n";
            if (logBuffer.length() > 1024) {
                logger.write(logBuffer);
                logger.flush();
                logBuffer = "";
            }
        }
    }

    void logToFile1() {
        if (!isLogging) return;
        logBuffer += "time " + System.currentTimeMillis() + "\n";
        synchronized (inertialSensor.listLinearAccelerometer) {
            for (float[] values : inertialSensor.listLinearAccelerometer) logBuffer += String.format("acc %.5f %.5f %.5f\n", values[0], values[1], values[2]);
            inertialSensor.listLinearAccelerometer.clear();
        }
        synchronized (inertialSensor.listGyroscope) {
            for (float[] values : inertialSensor.listGyroscope) logBuffer += String.format("gyr %.5f %.5f %.5f\n", values[0], values[1], values[2]);
            inertialSensor.listGyroscope.clear();
        }
        synchronized (inertialSensor.listMegneticField) {
            for (float[] values : inertialSensor.listMegneticField) logBuffer += String.format("meg %.2f %.2f %.2f\n", values[0], values[1], values[2]);
            inertialSensor.listMegneticField.clear();
        }
        synchronized (inertialSensor.listGravity) {
            for (float[] values : inertialSensor.listGravity) logBuffer += String.format("gra %.5f %.5f %.5f\n", values[0], values[1], values[2]);
            inertialSensor.listGravity.clear();
        }
        /*synchronized (microphone.buffer) {
            logBuffer += "mic";
            for (byte value: microphone.buffer) logBuffer += " " + value;
            logBuffer += "\n";
        }*/
        if (logBuffer.length() > 1024) {
            logger.write(logBuffer);
            logger.flush();
            logBuffer = "";
        }
    }

    void logToFile2() {
        if (!isLogging) return;
        logBuffer += "time " + System.currentTimeMillis() + "\n";
        synchronized (inertialSensor.dataLinearAccelerometer) {
            float[] values = inertialSensor.dataLinearAccelerometer;
            logBuffer += String.format("acc %.5f %.5f %.5f\n", values[0], values[1], values[2]);
        }
        synchronized (inertialSensor.dataGyroscope) {
            float[] values = inertialSensor.dataGyroscope;
            logBuffer += String.format("gyr %.5f %.5f %.5f\n", values[0], values[1], values[2]);
        }
        /*synchronized (inertialSensor.dataMegneticField) {
            float[] values = inertialSensor.dataMegneticField;
            logBuffer += String.format("meg %.2f %.2f %.2f\n", values[0], values[1], values[2]);
        }*/
        synchronized (inertialSensor.dataGravity) {
            float[] values = inertialSensor.dataGravity;
            logBuffer += String.format("gra %.5f %.5f %.5f\n", values[0], values[1], values[2]);
        }
        //Log.d("log", logBuffer.length() + "");
        if (logBuffer.length() > 16384) {
            logger.write(logBuffer);
            logger.flush();
            logBuffer = "";
        }
    }

    void logToFile3(String s) {
        if (!isLogging) return;
        s = System.currentTimeMillis() + " " + s + "\n";
        logBuffer += s;
        Log.d("log", logBuffer.length() + "");
        if (logBuffer.length() > 16384) {
            logger.write(logBuffer);
            logger.flush();
            logBuffer = "";
        }
    }

    void showFrequency() {
        double runTime = (System.currentTimeMillis() - startTime) / 1000.0;
        uText0.setText(String.format("Inertial: %.3f Hz", inertialSensor.counter / runTime));
        uText1.setText(String.format("Microphone: %.3f Hz", microphone.counter / runTime));
    }

    void changeLogStatus(int v) {
        // v == 0 : change
        // v == 1 : off
        // v == 2 : on
        if (v == 0 && isLogging == true || v == 1) {
            if (isLogging) {
                if (logger != null) {
                    logger.write(logBuffer);
                    logger.flush();
                    logger.close();
                }
                logBuffer = "";
                isLogging = false;
                uButtonLog.setText("LOG/OFF");
            }
        } else {
            if (!isLogging) {
                try {
                    String fileName = "log_" + new SimpleDateFormat("yy-MM-dd_HH-mm-ss").format(new Date()) + ".txt";
                    logger = new PrintWriter(new FileOutputStream(fileDirectory + "/" + fileName));
                    logBuffer = "";
                    isLogging = true;
                    uButtonLog.setText("LOG/ON");
                } catch (Exception e) {
                    Log.d("file", e.toString());
                }
            }
        }
    }
}
