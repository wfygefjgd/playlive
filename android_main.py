#!/usr/bin/env python3
"""
TVPlayer Android (Kivy) - 兼容 Android 4.4 - 13
手势:
  左右滑动 = 切换频道
  左侧上下滑动 = 亮度
  右侧上下滑动 = 音量
  左上角 = 隐藏/显示面板
  左下角 = 锁定
"""
import re
from kivy.app import App
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.video import Video
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.scrollview import ScrollView
from kivy.uix.gridlayout import GridLayout
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.storage.jsonstore import JsonStore
from kivy.network.urlrequest import UrlRequest
from kivy.metrics import dp
from kivy.graphics import Color, Rectangle

Window.clearcolor = (0, 0, 0, 1)

DEFAULT_SOURCES = [
    ("best-fan", "https://raw.githubusercontent.com/best-fan/iptv-sources/main/cn_all.m3u8"),
    ("TVBox", "https://ghfast.top/raw.githubusercontent.com/Supprise0901/TVBox_live/main/live.txt"),
    ("vbskycn", "https://raw.githubusercontent.com/vbskycn/iptv/master/tv/tv.m3u"),
    ("fanmingming", "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u"),
]

MIRRORS = [
    "https://ghfast.top/raw.githubusercontent.com/",
    "https://raw.gitmirror.com/",
    "https://raw.kkgithub.com/",
]

HEADERS = {"User-Agent": "Mozilla/5.0 (Linux; Android 10)"}


class Channel(object):
    __slots__ = ("name", "url", "group")

    def __init__(self, name, url, group=""):
        self.name = name or "未知"
        self.url = url or ""
        self.group = group or "未分组"


def parse_m3u(text):
    channels = []
    pending_name = None
    pending_group = "未分组"
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#EXTINF:"):
            m = re.search(r'group-title="([^"]*)"', line)
            pending_group = m.group(1) if m else "未分组"
            m2 = re.search(r",(.+?)$", line)
            pending_name = m2.group(1).strip() if m2 else "未知"
        elif line and not line.startswith("#") and pending_name is not None:
            channels.append(Channel(pending_name, line, pending_group))
            pending_name = None
            pending_group = "未分组"
    return channels


class ChannelBtn(Button):
    def __init__(self, channel, index, on_select, **kw):
        super(ChannelBtn, self).__init__(**kw)
        self.channel = channel
        self.index = index
        self.on_select = on_select
        self.background_normal = ""
        self.background_color = (0.12, 0.12, 0.12, 1)
        self.color = (0.9, 0.9, 0.9, 1)
        self.size_hint_y = None
        self.height = dp(40)
        self.halign = "left"
        self.valign = "middle"
        self.text_size = (None, None)
        self.bind(on_release=self._click)

    def _click(self, *a):
        if self.on_select:
            self.on_select(self.index)


class TVApp(FloatLayout):
    def __init__(self, **kw):
        super(TVApp, self).__init__(**kw)
        self.channels = []
        self.filtered = []
        self.current_index = 0
        self._locked = False
        self._panel_visible = True
        self._brightness = 1.0
        self._volume = 0.8
        self._touch_start = None
        self._loading = False
        self._show_fav = False
        self._source_idx = 0
        self._fetch_queue = []
        self._current_url = None

        self.fav_store = JsonStore("favorites.json")
        self.hidden_store = JsonStore("hidden.json")
        self.cache_store = JsonStore("cache.json")

        self._build_ui()
        Clock.schedule_once(lambda dt: self._load_cache(), 0.3)

    def _build_ui(self):
        self.video = Video(fit_mode="fill", state="stop", volume=self._volume)
        self.add_widget(self.video)

        self.overlay = FloatLayout()
        self.add_widget(self.overlay)

        self.ch_label = Label(
            text="", size_hint=(1, None), height=dp(28),
            pos_hint={"top": 0.92}, color=(1, 1, 1, 0.75), font_size=dp(12)
        )
        self.overlay.add_widget(self.ch_label)

        self.indicator = Label(
            text="", size_hint=(None, None), size=(dp(140), dp(44),),
            pos_hint={"center_x": 0.5, "center_y": 0.5},
            color=(1, 1, 1, 1), font_size=dp(18), opacity=0
        )
        self.overlay.add_widget(self.indicator)

        # left panel
        self.panel = BoxLayout(
            orientation="vertical", size_hint=(0.38, 0.82),
            pos_hint={"x": 0.02, "y": 0.1}, spacing=dp(4), padding=dp(6)
        )
        with self.panel.canvas.before:
            Color(0.12, 0.12, 0.12, 0.92)
            self._panel_rect = Rectangle(pos=self.panel.pos, size=self.panel.size)
        self.panel.bind(pos=self._sync_panel_bg, size=self._sync_panel_bg)

        self.search = TextInput(
            hint_text="搜索频道", multiline=False, size_hint=(1, None), height=dp(36),
            background_color=(0.08, 0.08, 0.08, 1), foreground_color=(1, 1, 1, 1),
            hint_text_color=(0.5, 0.5, 0.5, 1)
        )
        self.search.bind(text=lambda *a: self._filter())
        self.panel.add_widget(self.search)

        self.list_box = GridLayout(cols=1, spacing=dp(2), size_hint_y=None)
        self.list_box.bind(minimum_height=self.list_box.setter("height"))
        self.scroll = ScrollView(size_hint=(1, 1), do_scroll_x=False)
        self.scroll.add_widget(self.list_box)
        self.panel.add_widget(self.scroll)

        ctrl = BoxLayout(size_hint=(1, None), height=dp(40), spacing=dp(4))
        for text, cb in (("刷新", self._do_refresh), ("换源", self._switch_source), ("收藏", self._toggle_fav)):
            b = Button(text=text, background_normal="", background_color=(0.05, 0.4, 0.6, 1))
            b.bind(on_release=cb)
            ctrl.add_widget(b)
        self.panel.add_widget(ctrl)

        self.status = Label(text="", size_hint=(1, None), height=dp(22), color=(0.6, 0.6, 0.6, 1), font_size=dp(11))
        self.panel.add_widget(self.status)
        self.overlay.add_widget(self.panel)

        # toggle panel button top-left
        self.hide_btn = Button(
            text="◀", size_hint=(None, None), size=(dp(44), dp(44)),
            pos_hint={"x": 0.01, "top": 0.98},
            background_normal="", background_color=(0, 0, 0, 0.55),
            color=(1, 1, 1, 1), font_size=dp(16)
        )
        self.hide_btn.bind(on_release=self._toggle_panel)
        self.overlay.add_widget(self.hide_btn)

        # lock button bottom-left
        self.lock_btn = Button(
            text="🔓", size_hint=(None, None), size=(dp(44), dp(44)),
            pos_hint={"x": 0.01, "y": 0.02},
            background_normal="", background_color=(0, 0, 0, 0.55),
            color=(1, 1, 1, 1), font_size=dp(16)
        )
        self.lock_btn.bind(on_release=self._toggle_lock)
        self.overlay.add_widget(self.lock_btn)

    def _sync_panel_bg(self, *a):
        self._panel_rect.pos = self.panel.pos
        self._panel_rect.size = self.panel.size

    def on_touch_down(self, touch):
        if self._locked:
            if self.lock_btn.collide_point(*touch.pos):
                return super(TVApp, self).on_touch_down(touch)
            return True
        self._touch_start = (touch.x, touch.y)
        return super(TVApp, self).on_touch_down(touch)

    def on_touch_move(self, touch):
        if self._locked or not self._touch_start:
            return super(TVApp, self).on_touch_move(touch)
        dx = touch.x - self._touch_start[0]
        dy = touch.y - self._touch_start[1]
        if abs(dy) > abs(dx) and abs(dy) > dp(8):
            if self._panel_visible and self.panel.collide_point(*self._touch_start):
                return super(TVApp, self).on_touch_move(touch)
            if self._touch_start[0] < Window.width * 0.35:
                self._adjust_brightness(1 if dy > 0 else -1)
                self._touch_start = (touch.x, touch.y)
                return True
            if self._touch_start[0] > Window.width * 0.65:
                self._adjust_volume(1 if dy > 0 else -1)
                self._touch_start = (touch.x, touch.y)
                return True
        return super(TVApp, self).on_touch_move(touch)

    def on_touch_up(self, touch):
        if self._locked:
            if self.lock_btn.collide_point(*touch.pos):
                return super(TVApp, self).on_touch_up(touch)
            return True
        if not self._touch_start:
            return super(TVApp, self).on_touch_up(touch)
        dx = touch.x - self._touch_start[0]
        dy = touch.y - self._touch_start[1]
        adx, ady = abs(dx), abs(dy)
        if self._panel_visible and self.panel.collide_point(*self._touch_start):
            self._touch_start = None
            return super(TVApp, self).on_touch_up(touch)
        if adx > dp(50) and adx > ady:
            if dx > 0:
                self._prev_channel()
            else:
                self._next_channel()
            self._touch_start = None
            return True
        self._touch_start = None
        return super(TVApp, self).on_touch_up(touch)

    def _next_channel(self):
        if not self.filtered:
            return
        self.current_index = (self.current_index + 1) % len(self.filtered)
        self._play_current()

    def _prev_channel(self):
        if not self.filtered:
            return
        self.current_index = (self.current_index - 1) % len(self.filtered)
        self._play_current()

    def select_channel(self, index):
        if 0 <= index < len(self.filtered):
            self.current_index = index
            self._play_current()

    def _adjust_brightness(self, dirn):
        self._brightness = max(0.05, min(1.0, self._brightness + dirn * 0.05))
        try:
            Window.brightness = self._brightness
        except Exception:
            pass
        self._show_indicator("亮度 %d%%" % int(self._brightness * 100))

    def _adjust_volume(self, dirn):
        self._volume = max(0.0, min(1.0, self._volume + dirn * 0.05))
        self.video.volume = self._volume
        self._show_indicator("音量 %d%%" % int(self._volume * 100))

    def _show_indicator(self, text):
        self.indicator.text = text
        self.indicator.opacity = 1
        Clock.unschedule(self._hide_indicator)
        Clock.schedule_once(self._hide_indicator, 1.2)

    def _hide_indicator(self, dt):
        self.indicator.opacity = 0

    def _toggle_panel(self, *a):
        if self._locked:
            return
        self._panel_visible = not self._panel_visible
        self.panel.opacity = 1 if self._panel_visible else 0
        self.panel.disabled = not self._panel_visible
        self.hide_btn.text = "▶" if not self._panel_visible else "◀"

    def _toggle_lock(self, *a):
        self._locked = not self._locked
        self.lock_btn.text = "🔒" if self._locked else "🔓"
        if self._locked:
            self.panel.opacity = 0
            self.panel.disabled = True
            self.hide_btn.opacity = 0
            self.hide_btn.disabled = True
        else:
            self.hide_btn.opacity = 1
            self.hide_btn.disabled = False
            if self._panel_visible:
                self.panel.opacity = 1
                self.panel.disabled = False

    def _play_current(self):
        if not self.filtered or self.current_index >= len(self.filtered):
            return
        ch = self.filtered[self.current_index]
        if ch.url == self._current_url:
            return
        self._current_url = ch.url
        self.video.source = ch.url
        self.video.state = "play"
        self.ch_label.text = "%d/%d %s" % (self.current_index + 1, len(self.filtered), ch.name)
        self._highlight_list()

    def _filter(self):
        kw = (self.search.text or "").lower()
        result = []
        for ch in self.channels:
            if self.hidden_store.exists(ch.url):
                continue
            if self._show_fav and not self.fav_store.exists(ch.url):
                continue
            if kw and kw not in ch.name.lower():
                continue
            result.append(ch)
        self.filtered = result
        self._update_list()

    def _update_list(self):
        self.list_box.clear_widgets()
        for i, ch in enumerate(self.filtered):
            fav = "★ " if self.fav_store.exists(ch.url) else "▸ "
            btn = ChannelBtn(ch, i, self.select_channel, text=fav + ch.name)
            self.list_box.add_widget(btn)
        self._highlight_list()

    def _highlight_list(self):
        for child in self.list_box.children:
            if isinstance(child, ChannelBtn):
                if child.index == self.current_index:
                    child.background_color = (0.04, 0.28, 0.44, 1)
                else:
                    child.background_color = (0.12, 0.12, 0.12, 1)

    def _load_cache(self):
        try:
            if self.cache_store.exists("channels"):
                raw = self.cache_store.get("channels")["data"]
                self.channels = [Channel(c["name"], c["url"], c.get("group", "")) for c in raw]
                self._filter()
                if self.filtered:
                    self.current_index = 0
                    self._play_current()
                self.status.text = "%d 个频道 (缓存)" % len(self.channels)
                return
        except Exception:
            pass
        self._do_refresh()

    def _save_cache(self):
        try:
            data = [{"name": c.name, "url": c.url, "group": c.group} for c in self.channels]
            self.cache_store.put("channels", data=data)
        except Exception:
            pass

    def _do_refresh(self, *a):
        if self._loading:
            return
        self._loading = True
        self.status.text = "加载中..."
        self.channels = []
        self._fetch_queue = list(DEFAULT_SOURCES)
        self._fetch_next()

    def _fetch_next(self):
        if not self._fetch_queue:
            self._loading = False
            self._save_cache()
            self._filter()
            if self.filtered:
                self.current_index = 0
                self._play_current()
            self.status.text = "%d 个频道" % len(self.channels) if self.channels else "加载失败"
            return
        name, url = self._fetch_queue.pop(0)
        urls = [url]
        if "raw.githubusercontent.com" in url:
            for p in MIRRORS:
                urls.append(url.replace("https://raw.githubusercontent.com/", p))
        self._try_urls(urls)

    def _try_urls(self, urls):
        if not urls:
            self._fetch_next()
            return
        url = urls[0]

        def ok(req, result):
            text = result.decode("utf-8") if isinstance(result, bytes) else result
            chs = parse_m3u(text)
            if chs:
                existing = {c.url for c in self.channels}
                for c in chs:
                    if c.url not in existing:
                        self.channels.append(c)
                        existing.add(c.url)
                self._fetch_next()
            else:
                self._try_urls(urls[1:])

        def err(req, error):
            self._try_urls(urls[1:])

        UrlRequest(url, on_success=ok, on_error=err, on_failure=err, timeout=10, req_headers=HEADERS)

    def _switch_source(self, *a):
        if self._loading:
            return
        self._source_idx = (self._source_idx + 1) % len(DEFAULT_SOURCES)
        name, url = DEFAULT_SOURCES[self._source_idx]
        self._loading = True
        self.status.text = "切换 %s..." % name
        self.channels = []
        self._fetch_queue = [(name, url)]
        self._fetch_next()

    def _toggle_fav(self, *a):
        self._show_fav = not self._show_fav
        self._filter()


class TVPlayerApp(App):
    def build(self):
        return TVApp()


if __name__ == "__main__":
    TVPlayerApp().run()
