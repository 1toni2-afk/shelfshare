package ro.shelfshare.shelfshare;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Pluginurile locale se înregistrează ÎNAINTE de super.onCreate, care
        // pornește bridge-ul.
        registerPlugin(ThemeBarsPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
