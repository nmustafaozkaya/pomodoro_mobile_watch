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
