using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace hand2hand_desktop {
    public partial class MainWindow : Window {
        Server server;

        public MainWindow() {
            InitializeComponent();
            server = new Server(this);
            uComboIP.ItemsSource = server.ips;
            uTextNetInfo.SetBinding(TextBlock.TextProperty, new Binding("netInfo") { Source = server });
            uTextConsole.SetBinding(TextBox.TextProperty, new Binding("console") { Source = server });
        }

        private void uButtonListen_Click(object sender, RoutedEventArgs e) {
            server.Listen();
        }

        private void uButtonStop_Click(object sender, RoutedEventArgs e) {
            server.Stop();
        }
        
        private void uButtonSend_Click(object sender, RoutedEventArgs e) {
            server.BroadCast(uTextMessage.Text);
        }

        private void uButtonLogOn_Click(object sender, RoutedEventArgs e) {
            server.BroadCast("logon");
        }

        private void uButtonLogOff_Click(object sender, RoutedEventArgs e) {
            server.BroadCast("logoff");
        }

        private void uTextConsole_TextChanged(object sender, TextChangedEventArgs e) {
            uScrollConsole.ScrollToEnd();
        }
    }

    public class Server :INotifyPropertyChanged {
        const int PORT = 929;
        public TcpListener listener;
        public Thread threadListen;
        public bool listening = false;

        public List<TcpClient> clientList;

        MainWindow father;
        public List<string> ips;
        public string netInfo0;
        public string console0;
        public string netInfo { get { return netInfo0; } set { netInfo0 = value; OnPropertyChanged("netInfo"); } }
        public string console { get { return console0; } set { console0 = value; OnPropertyChanged("console"); } }

        public Server(MainWindow father) {
            this.father = father;
            string hostName = Dns.GetHostName();
            IPAddress[] addressList = Dns.GetHostAddresses(hostName);
            ips = new List<string>();
            foreach (IPAddress ip in addressList) {
                if (ip.ToString().Split('.').Length != 4) continue;
                ips.Add(ip.ToString());
            }
            clientList = new List<TcpClient>();
            netInfo = "Idle";
        }

        public void Listen() {
            if (listener == null) {
                try {
                    string ip = father.uComboIP.SelectedItem.ToString();
                    listener = new TcpListener(IPAddress.Parse(ip), PORT);
                    threadListen = new Thread(Listening);
                    threadListen.IsBackground = true;
                    threadListen.Start();
                } catch (Exception e) {
                    console += e.ToString() + "\n";
                }
            }
        }

        public void Stop() {
            listening = false;
            clientList.Clear();
            if (listener != null) {
                listener.Stop();
                listener = null;
            }
            console += "Stop listening\n";
        }

        public void Listening() {
            listener.Start();
            listening = true;
            netInfo = "Listening...";
            console += "Listening...\n";
            try {
                while (listening) {
                    TcpClient client = listener.AcceptTcpClient();
                    clientList.Add(client);
                    console += "Connection(" + clientList.Count + "): " + client.Client.RemoteEndPoint.ToString() + "\n";
                    Thread threadReceive = new Thread(Receiving);
                    threadReceive.IsBackground = true;
                    threadReceive.Start(client);
                }
            } catch (Exception e) {
                console += e.ToString() + "\n";
            } finally {
                netInfo = "Idle";
            }
        }

        public void Receiving(object clientObject) {
            TcpClient client = (TcpClient)clientObject;
            string remoteInfo = client.Client.RemoteEndPoint.ToString();
            try {
                StreamReader reader = new StreamReader(client.GetStream());
                while (listening) {
                    string str = reader.ReadLine();
                    if (str == null) break;
                    console += str + "\n";
                }
                reader.Close();
            } catch (Exception e) {
                console += e.ToString() + "\n";
            }
            clientList.Remove(client);
            console += "Disconnection(" + clientList.Count + "): " + remoteInfo + "\n";
        }

        public void BroadCast(string s) {
            foreach (TcpClient client in clientList) {
                StreamWriter writer = new StreamWriter(client.GetStream());
                writer.WriteLine(s);
                writer.Flush();
                console += "Send to " + client.Client.RemoteEndPoint.ToString() + " : " + s + "\n";
            }
        }

        public event PropertyChangedEventHandler PropertyChanged;
        public void OnPropertyChanged(string propertyName) {
            if (PropertyChanged != null) {
                PropertyChanged.Invoke(this, new PropertyChangedEventArgs(propertyName));
            }
        }
    }
}
