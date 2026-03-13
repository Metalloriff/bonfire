package org.godotengine.plugin.android.notificationlistener;

// This code primarily came from aslamanver on GitHub, specifically this gist:
// https://gist.github.com/aslamanver/f32a0bb8461c250d4a945e11f6771456
// Thank you to them for this code. I do not know Android programming,
// and I hate programming for Android with a passion, as stated multiple times in comments.

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import androidx.annotation.Nullable;

public abstract class BonfireForegroundService extends Service {

    protected final IBinder mBinder = new LocalBinder();
    protected int REQUEST_CODE, NOTIFICATION_ID = 3000;
    protected String CHANNEL_ID = "ForegroundService_ID";
    protected String CHANNEL_NAME = "ForegroundService Channel";
    protected NotificationManager mNotificationManager;
    protected NotificationCompat.Builder mNotificationBuilder;

    public static void start(Context context, Class<? extends BonfireForegroundService> serviceClass) {
        ContextCompat.startForegroundService(context, new Intent(context, serviceClass));
    }

    public static void stop(Context context, Class<? extends BonfireForegroundService> serviceClass) {
        context.stopService(new Intent(context, serviceClass));
    }

    protected abstract Notification serviceNotification();

    public abstract void onTaskRemoved(Intent rootIntent);

    @Override
    public void onCreate() {
        super.onCreate();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            if (!pm.isIgnoringBatteryOptimizations(getPackageName())) {
                Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                intent.setData(Uri.parse("package:" + getPackageName()));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
            }
        }

        mNotificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        mNotificationBuilder = new NotificationCompat.Builder(this, CHANNEL_ID);
        Notification notification = serviceNotification();

        int foregroundServiceType = getServiceType();

        startForeground(
                NOTIFICATION_ID,
                notification,
                foregroundServiceType
        );
    }

    private static int getServiceType() {
        int foregroundServiceType = 0;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            foregroundServiceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC;
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            foregroundServiceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE;
        }
        return foregroundServiceType;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return Service.START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

    protected Notification createNotification(String title, String message, int smallIcon, int bigIcon, Class<?> intentClass) {

        // Get the layouts to use in the custom notification
        // RemoteViews notificationLayout = new RemoteViews(getPackageName(), R.layout.notification_main);
        // notificationLayout.setTextViewText(R.id.txtTitle, message);
        // .setCustomBigContentView(notificationLayout);

        mNotificationBuilder.setContentTitle(title)
                .setContentText(message)
                .setAutoCancel(true);

        if (smallIcon != 0) {
            mNotificationBuilder.setSmallIcon(smallIcon);
        }

        if (bigIcon != 0) {
            mNotificationBuilder.setLargeIcon(Bitmap.createScaledBitmap(BitmapFactory.decodeResource(getResources(), bigIcon), 128, 128, true));
        }

        if (intentClass != null) {
            Intent notificationIntent = new Intent(this, intentClass);

            int pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                pendingIntentFlags |= PendingIntent.FLAG_IMMUTABLE;
            }

            PendingIntent pendingIntent = PendingIntent.getActivity(
                    this,
                    REQUEST_CODE,
                    notificationIntent,
                    pendingIntentFlags
            );
            mNotificationBuilder.setContentIntent(pendingIntent);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW);
            channel.setShowBadge(false);
            channel.setImportance(NotificationManager.IMPORTANCE_LOW);
            mNotificationManager.createNotificationChannel(channel);
        }

        return mNotificationBuilder.build();
    }

    public class LocalBinder extends Binder {
        public BonfireForegroundService getService() {
            return BonfireForegroundService.this;
        }
    }
}
