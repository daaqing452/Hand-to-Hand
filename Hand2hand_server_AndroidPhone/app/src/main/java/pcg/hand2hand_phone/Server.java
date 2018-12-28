package pcg.hand2hand_phone;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.util.Log;
import android.widget.ScrollView;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.Enumeration;

public class Server {
    public final static int PORT = 9299;
    boolean listening;
    ServerSocket serverSocket;
    ArrayList<Socket> clients;
    MainActivity father;
    String info;

    public Server(MainActivity father) {
        this.father = father;
        String ip = getIPAddress();
        father.textIp.setText(ip);
        info = "";

        listening = false;
        serverSocket = null;
        clients = new ArrayList<>();
    }

    public void setup() {
        if (serverSocket == null) {
            // listening
            new Thread(new Runnable() {
                @Override
                public void run() {
                    try {
                        String ip = father.textIp.getText().toString();
                        serverSocket = new ServerSocket(PORT, 10, InetAddress.getByName(ip));
                        listening = true;
                        father.runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                father.buttonSetup.setText("stop");
                            }
                        });
                        addInfo("bind: " + ip);
                        addInfo("listening...");
                        while (listening) {
                            Socket client = serverSocket.accept();
                            synchronized (clients) {
                                clients.add(client);
                            }
                            addInfo("Connection (" + clients.size() + "): " + client.getInetAddress().getHostAddress());
                            new ThreadReceive(client).start();
                        }
                    } catch (Exception e) {
                        addInfo("Error 0: " + e.toString());
                    }
                }
            }).start();
        } else {
            /*try {
                for (Socket client : clients) {
                    client.close();
                }
                serverSocket = null;
                listening = false;
                father.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        father.buttonSetup.setText("setup");
                    }
                });
            } catch (Exception e) {
                Log.d("xnet", "1: " + e.toString());
            }*/
        }
    }

    String s2;
    void broadcast(String s) {
        if (!listening) return;
        s2 = s;
        new Thread(new Runnable() {
            @Override
            public void run() {
                for (Socket client : clients) {
                    try {
                        PrintWriter writer = new PrintWriter(new OutputStreamWriter(client.getOutputStream()));
                        writer.write(s2 + "\n");
                        writer.flush();
                        addInfo("Send: " + s2);
                    } catch (Exception e) {
                        addInfo("Error 2: " + e.toString());
                    }
                }
            }
        }).start();
    }

    class ThreadReceive extends Thread {
        Socket client;

        public ThreadReceive(Socket client) {
            this.client = client;
        }

        @Override
        public void run() {
            try {
                BufferedReader reader = new BufferedReader(new InputStreamReader(client.getInputStream()));
                while (listening) {
                    String s = reader.readLine();
                    if (s == null) break;
                    addInfo("Receive " + client.getInetAddress().getHostAddress() + ": " + s);
                }
            } catch (Exception e) {
                addInfo("Error 3: " + e.toString());
            }
            clients.remove(client);
            addInfo("Disconnection (" + clients.size() + ")");
        }
    }

    void addInfo(String s) {
        info += "\n" + s;
        father.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                father.textInfo.setText(info);
                father.scrollTextInfo.fullScroll(ScrollView.FOCUS_DOWN);
            }
        });
    }

    String getIPAddress() {
        ConnectivityManager connectivityManager = (ConnectivityManager) father.getApplicationContext().getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo networkInfo = connectivityManager.getActiveNetworkInfo();
        if (networkInfo == null || !networkInfo.isConnected()) {
            return "No network info";
        }
        if (networkInfo.getType() == ConnectivityManager.TYPE_WIFI) {
            WifiManager wifiManager = (WifiManager) father.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            WifiInfo wifiInfo = wifiManager.getConnectionInfo();
            int ip = wifiInfo.getIpAddress();
            return (ip & 0xFF) + "." + ((ip >> 8) & 0xFF) + "." + ((ip >> 16) & 0xFF) + "." + ((ip >> 24) & 0XFF);
        } else if (networkInfo.getType() == ConnectivityManager.TYPE_MOBILE) {
            try {
                for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements(); ) {
                    NetworkInterface networkInterface = en.nextElement();
                    for (Enumeration<InetAddress> ina = networkInterface.getInetAddresses(); ina.hasMoreElements(); ) {
                        InetAddress inetAddress = ina.nextElement();
                        if (!inetAddress.isLoopbackAddress() && inetAddress instanceof Inet4Address) {
                            return inetAddress.getHostAddress();
                        }
                    }
                }
                return "No mobile address found";
            } catch (Exception e) {
                return "Error: fail to get mobile";
            }
        } else {
            return "Not wifi or mobile";
        }
    }
}
