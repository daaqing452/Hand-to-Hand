package pcg.hand2hand_smartwatch;

import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.util.Log;

import java.lang.reflect.Array;
import java.util.ArrayList;

public class InertialSensor implements SensorEventListener  {
    MainActivity father;
    int counter;

    Sensor sensorLinearAccelerometer;
    Sensor sensorGyroscope;
    Sensor sensorMegneticField;
    Sensor sensorGravity;

    float[] dataLinearAccelerometer;
    float[] dataGyroscope;
    float[] dataMegneticField;
    float[] dataGravity;

    ArrayList<float[]> listLinearAccelerometer;
    ArrayList<float[]> listGyroscope;
    ArrayList<float[]> listMegneticField;
    ArrayList<float[]> listGravity;

    public InertialSensor(MainActivity father) {
        this.father = father;
        counter = 0;

        sensorLinearAccelerometer = father.sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION);
        father.sensorManager.registerListener(this, sensorLinearAccelerometer, SensorManager.SENSOR_DELAY_FASTEST);
        dataLinearAccelerometer = new float[] { 0, 0, 0 };
        listLinearAccelerometer = new ArrayList<>();

        sensorGyroscope = father.sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
        father.sensorManager.registerListener(this, sensorGyroscope, SensorManager.SENSOR_DELAY_FASTEST);
        dataGyroscope = new float[] { 0, 0, 0 };
        listGyroscope = new ArrayList<>();

        /*sensorMegneticField = father.sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD);
        father.sensorManager.registerListener(this, sensorMegneticField, SensorManager.SENSOR_DELAY_FASTEST);
        dataMegneticField = new float[] { 0, 0, 0 };
        listMegneticField = new ArrayList<>();*/

        sensorGravity = father.sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY);
        father.sensorManager.registerListener(this, sensorGravity, SensorManager.SENSOR_DELAY_FASTEST);
        dataGravity = new float[] { 0, 0, 0 };
        listGravity = new ArrayList<>();
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        father.showFrequency();
        if (event.sensor == sensorLinearAccelerometer) {
            counter++;
            father.logToFile3(String.format("acc %.5f %.5f %.5f", event.values[0], event.values[1], event.values[2]));
            //synchronized (dataLinearAccelerometer) { dataLinearAccelerometer = event.values; }
            //father.logToFile2();
            //if (father.isLogging) { synchronized (listLinearAccelerometer) { listLinearAccelerometer.add(event.values); } }
            //father.logToFile("acc", event.values);
        }
        if (event.sensor == sensorGyroscope) {
            father.logToFile3(String.format("gyr %.5f %.5f %.5f", event.values[0], event.values[1], event.values[2]));
            //synchronized (dataGyroscope) { dataGyroscope = event.values; }
            //if (father.isLogging) { synchronized (listGyroscope) { listGyroscope.add(event.values); } }
            //father.logToFile("gyr", event.values);
        }
        /*if (event.sensor == sensorMegneticField) {
            //synchronized (dataMegneticField) { dataMegneticField = event.values; }
            //if (father.isLogging) { synchronized (listMegneticField) { listMegneticField.add(event.values); } }
            //father.logToFile("meg", event.values);
        }*/
        if (event.sensor == sensorGravity) {
            father.logToFile3(String.format("gra %.5f %.5f %.5f", event.values[0], event.values[1], event.values[2]));
            //synchronized (dataGravity) { dataGravity = event.values; }
            //if (father.isLogging) { synchronized (listGravity) { listGravity.add(event.values); } }
            //father.logToFile("gra", event.values);
        }

        /*float[] r = new float[9];
        float[] v = new float[3];
        SensorManager.getRotationMatrix(r, null, dataLinearAccelerometer, dataMegneticField);
        SensorManager.getOrientation(r, v);
        father.uText1.setText(String.format("%.3f %.3f %.3f", v[0], v[1], v[2]));*/
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }
}
