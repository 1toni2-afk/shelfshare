package ro.shelfshare.shelfshare;

import android.graphics.Color;
import android.view.Window;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Colorează fâșiile de sub bara de stare și bara de navigare după tema din
 * aplicație.
 *
 * WebView-ul nu mai desenează sub barele de sistem (index.html nu are
 * `viewport-fit=cover`), deci Capacitor îl împinge cu padding, iar în spațiul
 * rămas se vede fundalul ferestrei. Tema aleasă în Setări poate fi alta decât
 * cea a telefonului, așa că fundalul și culoarea iconițelor vin din JS
 * (lib/theme/themeStore.ts), nu din values-night.
 */
@CapacitorPlugin(name = "ThemeBars")
public class ThemeBarsPlugin extends Plugin {

    @PluginMethod
    public void apply(PluginCall call) {
        boolean dark = Boolean.TRUE.equals(call.getBoolean("dark", false));
        String color = call.getString("color", dark ? "#0E0E0F" : "#F8F4EC");

        getActivity().runOnUiThread(() -> {
            try {
                Window window = getActivity().getWindow();
                window.getDecorView().setBackgroundColor(Color.parseColor(color));
                WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, window.getDecorView());
                controller.setAppearanceLightStatusBars(!dark);
                controller.setAppearanceLightNavigationBars(!dark);
                call.resolve();
            } catch (IllegalArgumentException e) {
                call.reject("Culoare invalidă: " + color);
            }
        });
    }
}
