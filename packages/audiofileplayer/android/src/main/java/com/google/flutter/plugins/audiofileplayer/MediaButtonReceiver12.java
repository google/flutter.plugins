package com.google.flutter.plugins.audiofileplayer;

import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;
import android.view.KeyEvent;
import java.util.List;

public class MediaButtonReceiver12 {

    private static ComponentName getMediaButtonReceiverComponent(Context context) {
        Intent queryIntent = new Intent("android.intent.action.MEDIA_BUTTON");
        queryIntent.setPackage(context.getPackageName());
        PackageManager pm = context.getPackageManager();
        List<ResolveInfo> resolveInfos = pm.queryBroadcastReceivers(queryIntent, 0);
        if (resolveInfos.size() == 1) {
            ResolveInfo resolveInfo = (ResolveInfo)resolveInfos.get(0);
            return new ComponentName(resolveInfo.activityInfo.packageName, resolveInfo.activityInfo.name);
        } else {
            if (resolveInfos.size() > 1) {
                Log.w("MediaButtonReceiver12", "More than one BroadcastReceiver that handles android.intent.action.MEDIA_BUTTON was found, returning null.");
            }

            return null;
        }
    }

    public static PendingIntent buildMediaButtonPendingIntent(Context context, long action) {
        ComponentName mbrComponent = getMediaButtonReceiverComponent(context);
        if (mbrComponent == null) {
            Log.w("MediaButtonReceiver12", "A unique media button receiver could not be found in the given context, so couldn't build a pending intent.");
            return null;
        } else {
            return buildMediaButtonPendingIntent(context, mbrComponent, action);
        }
    }

    public static PendingIntent buildMediaButtonPendingIntent(Context context, ComponentName mbrComponent, long action) {
        if (mbrComponent == null) {
            Log.w("MediaButtonReceiver12", "The component name of media button receiver should be provided.");
            return null;
        } else {
            int keyCode = PlaybackStateCompat.toKeyCode(action);
            if (keyCode == 0) {
                Log.w("MediaButtonReceiver12", "Cannot build a media button pending intent with the given action: " + action);
                return null;
            } else {
                Intent intent = new Intent("android.intent.action.MEDIA_BUTTON");
                intent.setComponent(mbrComponent);
                intent.putExtra("android.intent.extra.KEY_EVENT", new KeyEvent(0, keyCode));
                return PendingIntent.getBroadcast(context, keyCode, intent, PendingIntent.FLAG_IMMUTABLE | 0);
            }
        }
    }
}
