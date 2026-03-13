package org.godotengine.plugin.android.notificationlistener;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class ServiceRestartReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d("Bonfire_DEBUG", "Checking service status...");
        Intent serviceIntent = new Intent(context, BonfireForegroundServiceInstance.class);
        context.startForegroundService(serviceIntent);
    }
}