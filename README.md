# recording_app

Add description

## Android setup

Add required permissions to AndroidManifest.xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Optional: Add this permission if you want to use bluetooth telephony device like headset/earbuds -->
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<!-- Optional: Add this permission if you want to save your recordings in public folders -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>

In build.gradle, set minSdk = 23

## ios setup

<key>NSMicrophoneUsageDescription</key>
<string>Some message to describe why you need this permission</string>

## Packages used

- record: ^5.2.0
- path_provider: ^2.1.5
- permission_handler: ^11.3.1
- shared_preferences
