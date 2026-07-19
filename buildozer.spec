[app]
title = TVPlayer
package.name = tvplayer
package.domain = org.tvplayer
source.dir = .
source.include_exts = py,png,jpg,kv,atlas,json
source.include_patterns = android_main.py
version = 1.0.0
requirements = python3,kivy==2.2.1
orientation = landscape
fullscreen = 1

# Android 4.4 (API 19) ~ Android 13 (API 33)
android.api = 33
android.minapi = 19
android.ndk = 25b
android.sdk = 33
android.archs = arm64-v8a,armeabi-v7a
android.permissions = INTERNET,ACCESS_NETWORK_STATE,WRITE_SETTINGS
android.accept_sdk_license = True
android.allow_backup = True
android.entrypoint = org.kivy.android.PythonActivity
android.presplash_color = #000000

# entry point
# buildozer uses main.py by default; we rename via p4a bootstrap
# Keep android_main.py and copy as main.py during build if needed

[buildozer]
log_level = 2
warn_on_root = 1
