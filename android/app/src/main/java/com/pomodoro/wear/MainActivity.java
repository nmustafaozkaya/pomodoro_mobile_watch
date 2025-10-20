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
    private static final String PREFS_SETTINGS = "pomodoro_phone_settings"; // optional: where we might cache phone settings on wear

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
                            } else if (call.method.equals("getInitialSettings")) {
                                String settings = getInitialSettings();
                                result.success(settings);
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

    private String getInitialSettings() {
        // Try to read cached settings on wear (for emulator/testing). In real scenarios, this should be populated via Data Layer from phone.
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS_SETTINGS, Context.MODE_PRIVATE);
            int durationSeconds = prefs.getInt("durationSeconds", 1500);
            String language = prefs.getString("language", "tr");

            JSONObject data = new JSONObject();
            data.put("durationSeconds", durationSeconds);
            data.put("language", language);
            return data.toString();
        } catch (Exception e) {
            try {
                JSONObject fallback = new JSONObject();
                fallback.put("durationSeconds", 1500);
                fallback.put("language", "tr");
                return fallback.toString();
            } catch (Exception ex) {
                return "{}";
            }
        }
    }
}
