package com.pomodoro.wear;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;
import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.pomodoro.wear/data";
    private static final String PREFS_NAME = "pomodoro_work_data";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("getWorkData")) {
                                String workData = getWorkData();
                                result.success(workData);
                            } else if (call.method.equals("sendWorkData")) {
                                Object data = call.argument("totalWorkMinutes");
                                Object sessionMinutes = call.argument("lastSessionMinutes");
                                Object timestamp = call.argument("timestamp");
                                saveWorkData(data, sessionMinutes, timestamp);
                                result.success("Data saved");
                            } else {
                                result.notImplemented();
                            }
                        });
    }

    private String getWorkData() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        try {
            JSONObject data = new JSONObject();
            data.put("totalWorkMinutes", prefs.getInt("totalWorkMinutes", 0));
            data.put("lastSessionMinutes", prefs.getInt("lastSessionMinutes", 25));
            data.put("lastUpdate", prefs.getLong("lastUpdate", 0));
            return data.toString();
        } catch (Exception e) {
            return "{}";
        }
    }

    private void saveWorkData(Object totalWorkMinutes, Object sessionMinutes, Object timestamp) {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        
        if (totalWorkMinutes != null) {
            editor.putInt("totalWorkMinutes", (Integer) totalWorkMinutes);
        }
        if (sessionMinutes != null) {
            editor.putInt("lastSessionMinutes", (Integer) sessionMinutes);
        }
        if (timestamp != null) {
            editor.putLong("lastUpdate", (Long) timestamp);
        }
        
        editor.apply();
    }
}
