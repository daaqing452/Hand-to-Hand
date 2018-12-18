package pcg.hand2hand_phone;

import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ScrollView;
import android.widget.TextView;

public class MainActivity extends AppCompatActivity {

    EditText textIp, textMessage;
    TextView textInfo;
    Button buttonSetup, buttonSend, buttonSendLogOn, buttonSendLogOff;
    ScrollView scrollTextInfo;

    Server server;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        textIp = findViewById(R.id.text_ip);
        textMessage = findViewById(R.id.text_message);
        textInfo = findViewById(R.id.text_info);
        buttonSetup = findViewById(R.id.button_setup);
        buttonSend = findViewById(R.id.button_send);
        buttonSendLogOn = findViewById(R.id.button_send_logon);
        buttonSendLogOff = findViewById(R.id.button_send_logoff);
        scrollTextInfo = findViewById(R.id.scroll_text_info);

        server = new Server(this);

        buttonSetup.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                server.setup();
            }
        });

        buttonSend.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                server.broadcast(textMessage.getText().toString());
            }
        });

        buttonSendLogOn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                server.broadcast("logon");
            }
        });

        buttonSendLogOff.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                server.broadcast("logoff");
            }
        });
    }
}
