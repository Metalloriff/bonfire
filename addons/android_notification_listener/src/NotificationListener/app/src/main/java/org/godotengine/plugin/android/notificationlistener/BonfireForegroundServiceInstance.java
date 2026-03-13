package org.godotengine.plugin.android.notificationlistener;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.PendingIntent;
import android.content.Intent;
import android.os.PowerManager;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;

public class BonfireForegroundServiceInstance extends BonfireForegroundService {
    private static BonfireForegroundServiceInstance instance;

    public static BonfireForegroundServiceInstance getInstance() {
        return instance;
    }

    private NotificationListener listener;
    private String[] serverEndpoints;
    private String[] authenticationDataStrings;
    private PowerManager.WakeLock wakeLock;
    private static final long RESTART_CHECK_INTERVAL = 60000;

    public void initialize(String[] endpoints, String[] authenticationDataStrings) {
        this.serverEndpoints = endpoints;
        this.authenticationDataStrings = authenticationDataStrings;

        disconnectAll();
        connectToServers();
        scheduleRestartCheck();
    }

    private void scheduleRestartCheck() {
        AlarmManager alarmManager = (AlarmManager) getSystemService(ALARM_SERVICE);
        Intent intent = new Intent(this, ServiceRestartReceiver.class);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        // Set repeating alarm
        alarmManager.setRepeating(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime(),
                RESTART_CHECK_INTERVAL,
                pendingIntent
        );
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        // Restart the service if it was killed
        Intent restartIntent = new Intent(this, BonfireForegroundServiceInstance.class);
        restartIntent.setPackage(getPackageName());
        startService(restartIntent);

        Log.d("Bonfire_DEBUG", "Task was removed. May cause issues.");
    }

    @Override
    public void onDestroy() {
        disconnectAll();
        instance = null;

        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }

        // Schedule service restart
        Intent restartIntent = new Intent(this, BonfireForegroundServiceInstance.class);
        PendingIntent restartPendingIntent = PendingIntent.getService(
                this,
                1,
                restartIntent,
                PendingIntent.FLAG_ONE_SHOT | PendingIntent.FLAG_IMMUTABLE
        );

        AlarmManager alarmManager = (AlarmManager) getSystemService(ALARM_SERVICE);
        if (alarmManager != null) {
            alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 1000,
                    restartPendingIntent);
        }

        super.onDestroy();
    }

    private final Map<String, WebSocket> activeConnections = new ConcurrentHashMap<>();
    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .pingInterval(30, TimeUnit.SECONDS)
            .build();

    public void connectToServers() {
        for (int i = 0; i < serverEndpoints.length; i++) {
            String endpoint = serverEndpoints[i];
            String authenticationData = authenticationDataStrings[i];

            Log.d("Bonfire_DEBUG", "Attempting to connect to " + endpoint);

            Request request = new Request.Builder().url(endpoint).build();

            httpClient.newWebSocket(request, new WebSocketListener() {
                @Override
                public void onOpen(@NonNull WebSocket webSocket, @NonNull Response response) {
                    activeConnections.put(endpoint, webSocket);
;
                    Log.d("Bonfire_DEBUG", "Connected to " + endpoint);
                }

                @Override
                public void onMessage(@NonNull WebSocket webSocket, @NonNull String text) {
                    try {
                        JSONObject payload = new JSONObject(text);
                        String messageType = payload.getString("type");

                        switch(messageType) {
                            case "handshake" -> {
                                webSocket.send(authenticationData);
                            }
                            case "notification" -> {
                                String notifType = payload.getString("notif_type");
                                String notifTitle = payload.getString("title");
                                String notifBody = payload.getString("body");

                                NotificationHelper.showNotification(getInstance(), notifTitle, notifBody);
                            }
                        }
                    } catch (JSONException e) {
                        Log.d("Bonfire_DEBUG", "Received invalid JSON message through endpoint '" + endpoint + "'; Exception: " + e.getMessage());
                    }
                }

                @Override
                public void onFailure(@NonNull WebSocket webSocket, @NonNull Throwable t, Response response) {
                    activeConnections.remove(endpoint);

                    Log.d("Bonfire_DEBUG", "Failed to connect to " + endpoint + "; Reason: " + t.toString());
                }
            });
        }
    }

    private void handleServerResponse(String text) {
        Log.d("Bonfire_DEBUG", text);
    }

    public void disconnectAll() {
        for (WebSocket ws : activeConnections.values()) {
            ws.close(1000, "Shutting down");
        }
        activeConnections.clear();
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;

        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Bonfire::ServiceLock");
        wakeLock.acquire(10*60*1000L);

        Log.d("Bonfire_DEBUG", "Service created with wake lock");
        Log.d("Bonfire_DEBUG", "Service created.");
    }

    @Override
    protected Notification serviceNotification() {
        return createNotification(
                "Bonfire",
                "Bonfire is running.",
                R.drawable.bonfire_logo_small,
                R.drawable.bonfire_logo_large,
                org.godotengine.godot.Godot.class
        );
    }

}
