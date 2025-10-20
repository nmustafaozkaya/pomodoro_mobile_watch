package com.pomodoro.phone;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;
import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.pomodoro.phone/wear";
    private static final String PREFS_NAME = "pomodoro_phone_data";
    private static final String PREFS_SETTINGS = "pomodoro_phone_settings";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("getWearData")) {
                                String wearData = getWearData();
                                result.success(wearData);
                            } else if (call.method.equals("sendToWear")) {
                                Object data = call.arguments;
                                sendDataToWear(data);
                                result.success("Data sent to wear");
                            } else if (call.method.equals("setInitialSettings")) {
                                // Allow the phone app to save desired initial settings so wear can read them on boot (emulator-friendly)
                                try {
                                    String json = (String) call.arguments;
                                    JSONObject obj = new JSONObject(json);
                                    int durationSeconds = obj.optInt("durationSeconds", 1500);
                                    String language = obj.optString("language", "tr");
                                    SharedPreferences prefs = getSharedPreferences(PREFS_SETTINGS, Context.MODE_PRIVATE);
                                    SharedPreferences.Editor editor = prefs.edit();
                                    editor.putInt("durationSeconds", durationSeconds);
                                    editor.putString("language", language);
                                    editor.apply();
                                    result.success("Settings saved");
                                } catch (Exception e) {
                                    result.error("SETTINGS_ERROR", e.getMessage(), null);
                                }
                            } else {
                                result.notImplemented();
                            }
                        });
    }

    private String getWearData() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        try {
            JSONObject data = new JSONObject();
            data.put("totalWorkMinutes", prefs.getInt("totalWorkMinutes", 0));
            data.put("lastSessionMinutes", prefs.getInt("lastSessionMinutes", 25));
            data.put("lastUpdate", prefs.getLong("lastUpdate", 0));
            data.put("isConnected", prefs.getBoolean("isConnected", false));
            
            // Add empty recent array for cloud data (will be filled by API)
            data.put("recent", new org.json.JSONArray());
            
            return data.toString();
        } catch (Exception e) {
            return "{}";
        }
    }

    private void sendDataToWear(Object data) {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        
        // Mark as connected
        editor.putBoolean("isConnected", true);
        editor.putLong("lastUpdate", System.currentTimeMillis());
        
        editor.apply();
        
        // Here you would implement actual Bluetooth/Wear OS communication
        // For now, we're just simulating the connection
    }
}
