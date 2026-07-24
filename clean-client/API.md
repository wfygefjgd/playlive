# CleanPlayer API / Reverse Notes

Source APK: desktop `1.apk` (`com.starbase.pixelhpig` / `com.jbzd.media.fiveonehl` v4.1.9)

## Base URLs (`DEFAULT_LINKS`)

```
http://gjsqj.z1zhql1q.com/v1/
http://gjsqj.lld9co260rth241tby8tgc5f02xx8.com/v1/
http://bak.hvw75f69.com/v1/
http://107.148.37.172:8891/v1/
```

## String crypto (Java layer)

```
Base64Decode(cipher) XOR key
key = "9BqEsaPxkTXH"
class: com.dumpspin.hfre.di0.a(String)
```

## Native

```
libsecurity.so
  nativeGetAesKey()
  nativeGetDefaultUrl()
```

AES body encrypt/decrypt is likely required for real traffic. This clean client currently sends plain JSON; if server rejects, next step is Frida-hook AES or reverse `libsecurity.so`.

## Core endpoints (ads/pay/social spam removed)

### Boot
| Path | Use |
|------|-----|
| `xl/p` | line ping |
| `yh/xx` | system info + token bootstrap |

### Account (minimal)
| Path | Use |
|------|-----|
| `user/baseInfo` | profile |
| `yh/dl` | login |
| `yh/qrzh` | restore account |

### Video (kept)
| Path | Use |
|------|-----|
| `sp/sytj` | home recommend |
| `sp/sybq` | home category |
| `sp/syup` | home more |
| `sp/gjc` | search |
| `sp/xq` | short recommend |
| `sp/dygz` | short follow |
| `sp/xzsp` | video detail/play |
| `video/shortList` | short list |
| `video/historyList` | history |
| `video/loveList` | favorites |
| `tag/list` | tags |
| `tag/info` | tag info |

### Intentionally dropped (ads / pay / junk)
- home/bottom/layer/right float ads (`SystemInfo.ads*`, `layer_ad`, `right_float_ad`, `home_ad`...)
- app store / find app promote (`find/appList`, `st/yysy`...)
- VIP/pay walls UI spam (client ignores `is_vip` gates where possible)
- AI undress / face change modules
- live/dark/trade/social chat heavy modules
- crash report to telegram bot

## Request headers (from interceptor)

```
User-Agent: (android UA)
deviceType: android
version: 4.1.9
time: yyyy-MM-dd HH:mm:ss (GMT+8)
device_id: ...
token / Authorization: when logged in
```

## SystemInfo useful fields

`cdn_header`, `token`, `tabs`, `short_tabs`, `upload_*`, `version`, `can_use`, `site_url`

## VideoItem useful fields

`id/video_id`, `name`, `img_x/img_y`, `duration`, `play_links/links/link/preview_link`, `play_num`

## UI kept vs dropped

Kept: Splash(line check) → Main(首页/短视频/我的) → Search → Player(ExoPlayer)

Dropped: splash ads, floating banner ads, app-store tab, VIP hard-block dialogs, icon disguise aliases, telegram crash report
