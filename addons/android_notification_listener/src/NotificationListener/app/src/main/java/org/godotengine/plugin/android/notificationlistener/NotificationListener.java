package org.godotengine.plugin.android.notificationlistener;

import static android.content.Context.POWER_SERVICE;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.PowerManager;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.List;

public class NotificationListener extends GodotPlugin {
    /**
     * Base constructor passing a {@link Godot} instance through which the plugin can access Godot's
     * APIs and lifecycle events.
     *
     * @param godot
     */
    public NotificationListener(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "NotificationListener";
    }

    @UsedByGodot
    public void helloWorld() {
        getGodot().getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Toast.makeText(getGodot().getActivity(), "Hello world.", Toast.LENGTH_LONG).show();
            }
        });
    }

    @UsedByGodot
    public void create_fg_notification() {
        getGodot().getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Activity activity = getGodot().getActivity();
                if (activity == null) {
                    return;
                }

                // Check permissions
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    if (ContextCompat.checkSelfPermission(activity,
                            android.Manifest.permission.POST_NOTIFICATIONS)
                            != android.content.pm.PackageManager.PERMISSION_GRANTED) {

                        activity.requestPermissions(
                                new String[]{android.Manifest.permission.POST_NOTIFICATIONS},
                                1001
                        );
                        Toast.makeText(activity, "Permission requested. Try again.", Toast.LENGTH_LONG).show();
                        return;
                    }
                }

                // Also check battery optimization
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PowerManager pm = (PowerManager) activity.getSystemService(POWER_SERVICE);
                    if (!pm.isIgnoringBatteryOptimizations(activity.getPackageName())) {
                        Toast.makeText(activity, "Please disable battery optimization for best results", Toast.LENGTH_LONG).show();
                        // Still continue, but warn user
                    }
                }

                // Start service with explicit intent
                Intent intent = new Intent(activity, BonfireForegroundServiceInstance.class);
                activity.startForegroundService(intent);
                Toast.makeText(activity, "Foreground service started", Toast.LENGTH_LONG).show();
            }
        });
    }

    @UsedByGodot
    public void sync_notification_servers(String[] addresses, String[] authenticationDataStrings) {
        getGodot().getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                BonfireForegroundServiceInstance service = BonfireForegroundServiceInstance.getInstance();

                if (service == null) {
                    return;
                }

                service.disconnectAll();
                service.initialize(addresses, authenticationDataStrings);
            }
        });
    }
}
