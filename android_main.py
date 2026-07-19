#!/usr/bin/env python3
import json, re, os
from functools import partial
from kivy.app import App
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.video import Video
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.recycleview import RecycleView
from kivy.uix.recycleview.views import RecycleDataViewBehavior
from kivy.uix.popup import Popup
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.storage.jsonstore import JsonStore
from kivy.network.urlrequest import UrlRequest
from kivy.properties import StringProperty, NumericProperty, BooleanProperty, ObjectProperty
from kivy.metrics import dp

Window.clearcolor = (0.05, 0.05, 0.05, 1)

# --- Reusable fetch ---
def fetch_url(url, callback, errback=None):
    UrlRequest(url, on_success=callback, on_error=errback or (lambda r, e: None),
               on_failure=errback or (lambda r, e: None),
               timeout=10,
               headers={'User-Agent': 'Mozilla/5.0'})

# --- Channel model ---
class Channel:
    __slots__ = ('name', 'url', 'group')
    def __init__(self, name, url, group=""):
        self.name = name
        self.url = url
        self.group = group

def parse_m3u(text):
    channels = []
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#EXTINF:"):
            m = re.search(r'group-title="([^"]*)"', line)
            group = m.group(1) if m else "未分组"
            m2 = re.search(r",(.+?)$", line)
            name = m2.group(1).strip() if m2 else "未知"
            channels.append(Channel(name, "", group))
        elif line and not line.startswith("#"):
            if channels:
                channels[-1].url = line
    return [c for c in channels if c.url]

DEFAULT_SOURCES = [
    ("best-fan", "https://raw.githubusercontent.com/best-fan/iptv-sources/main/cn_all.m3u8"),
    ("TVBox", "https://ghfast.top/raw.githubusercontent.com/Supprise0901/TVBox_live/main/live.txt"),
    ("vbskycn", "https://raw.githubusercontent.com/vbskycn/iptv/master/tv/tv.m3u"),
    ("fanmingming", "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u"),
]

# --- RecycleView row ---
class ChannelRow(RecycleDataViewBehavior, BoxLayout):
    index = NumericProperty(0)
    text = StringProperty("")
    fav_text = StringProperty("")

    def on_touch_up(self, touch):
        if self.collide_point(*touch.pos):
            app = App.get_running_app()
            app.select_channel(self.index)
        return super().on_touch_up(touch)


class TVApp(FloatLayout):
    def __init__(self, **kw):
        super().__init__(**kw)
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
        self._swap_btn = None

        self.fav_store = JsonStore("favorites.json")
        self.hidden_store = JsonStore("hidden.json")
        self.cache_store = JsonStore("cache.json")

        self._build_ui()
        Clock.schedule_once(lambda dt: self._load_cache(), 0.5)

    def _build_ui(self):
        # Video (lowest layer)
        self.video = Video(fit_mode="fill", state="stop", volume=self._volume)
        self.add_widget(self.video)

        # Overlay
        self.overlay = FloatLayout()
        self.add_widget(self.overlay)

        # Top bar with hide button
        top = BoxLayout(size_hint=(1, None), height=dp(44), pos_hint={"top": 1},
                        spacing=dp(8), padding=[dp(4), dp(2)])
        top.add_widget(Label(size_hint_x=0.7))
        self.hide_btn = Button(text="◀", size_hint=(None, 1), width=dp(44),
                              background_normal="", background_color=(0, 0, 0, 0.6),
                              color=(1, 1, 1, 1), on_press=self._toggle_panel)
        top.add_widget(self.hide_btn)
        self.overlay.add_widget(top)

        # Channel label
        self.ch_label = Label(text="", size_hint=(1, None), height=dp(30),
                             pos_hint={"top": 0.94}, color=(1, 1, 1, 0.7),
                             font_size=dp(12), halign="center")
        self.overlay.add_widget(self.ch_label)

        # Panel (left side)
        self.panel = BoxLayout(orientation="vertical", size_hint=(0.7, 0.75),
                              pos_hint={"x": 0, "y": 0.08},
                              spacing=dp(2))
        self.panel_bg = BoxLayout(size_hint=(1, 1))
        from kivy.graphics import Color, Rectangle
        self.panel_bg.canvas.add(Color(0.12, 0.12, 0.12, 0.92))
        self.panel_bg.canvas.add(Rectangle())
        self.panel_bg.bind(pos=lambda o, v: setattr(o.canvas.children[-1], 'pos', v),
                           size=lambda o, v: setattr(o.canvas.children[-1], 'size', v))
        self.panel.add_widget(self.panel_bg)

        # Search
        self.search = TextInput(hint_text="搜索频道", size_hint=(1, None), height=dp(36),
                               background_color=(0.08, 0.08, 0.08, 1),
                               foreground_color=(1, 1, 1, 1), hint_text_color=(0.5, 0.5, 0.5, 1))
        self.search.bind(text=self._filter)
        self.panel.add_widget(self.search)

        # Channel list
        self.rv = RecycleView(size_hint=(1, 1))
        self.rv_view = rv_view = self.rv
        self.panel.add_widget(self.rv)

        # Control buttons
        ctrl = BoxLayout(size_hint=(1, None), height=dp(40), spacing=dp(2))
        ctrl.add_widget(Button(text="刷新", on_press=self._do_refresh,
                              background_normal="", background_color=(0.05, 0.4, 0.6, 1)))
        ctrl.add_widget(Button(text="换源", on_press=self._switch_source,
                              background_normal="", background_color=(0.05, 0.4, 0.6, 1)))
        ctrl.add_widget(Button(text="收藏", on_press=self._toggle_fav,
                              background_normal="", background_color=(0.05, 0.4, 0.6, 1)))
        self.panel.add_widget(ctrl)

        self.overlay.add_widget(self.panel)

        # Lock button (bottom left)
        self.lock_btn = Button(text="🔓", size_hint=(None, None), size=(dp(44), dp(44)),
                              pos_hint={"x": 0, "y": 0},
                              background_normal="", background_color=(0, 0, 0, 0.5),
                              color=(1, 1, 1, 1), font_size=dp(18),
                              on_press=self._toggle_lock)
        self.overlay.add_widget(self.lock_btn)

        # Volume/brightness indicator
        self.indicator = Label(text="", size_hint=(None, None), size=(dp(120), dp(44)),
                              pos_hint={"center_x": 0.5, "center_y": 0.5},
                              color=(1, 1, 1, 0.9), font_size=dp(18),
                              opacity=0)
        self.overlay.add_widget(self.indicator)

    # --- Touch ---
    def on_touch_down(self, touch):
        if self._locked:
            return True
        self._touch_start = (touch.x, touch.y)
        return super().on_touch_down(touch)

    def on_touch_up(self, touch):
        if self._locked:
            return True
        if not self._touch_start:
            return super().on_touch_up(touch)
        dx = touch.x - self._touch_start[0]
        dy = touch.y - self._touch_start[1]
        adx, ady = abs(dx), abs(dy)

        if self._panel_visible and self.panel.collide_point(*touch.pos):
            pass
        elif adx > dp(50) and adx > ady:
            if dx > 0:
                self._prev_channel()
            else:
                self._next_channel()
            return True
        elif ady > dp(20) and ady > adx:
            if touch.x < Window.width * 0.35:
                self._adjust_brightness(-1 if dy > 0 else 1)
            elif touch.x > Window.width * 0.65:
                self._adjust_volume(-1 if dy > 0 else 1)
            return True
        self._touch_start = None
        return super().on_touch_up(touch)

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
        if index < len(self.filtered):
            self.current_index = index
            self._play_current()

    def _adjust_brightness(self, dirn):
        self._brightness = max(0.05, min(1.0, self._brightness + dirn * 0.05))
        win = Window
        if hasattr(win, 'brightness'):
            win.brightness = self._brightness
        self._show_indicator(f"亮度 {int(self._brightness*100)}%")

    def _adjust_volume(self, dirn):
        self._volume = max(0.0, min(1.0, self._volume + dirn * 0.05))
        self.video.volume = self._volume
        self._show_indicator(f"音量 {int(self._volume*100)}%")

    def _show_indicator(self, text):
        self.indicator.text = text
        self.indicator.opacity = 1
        Clock.unschedule(self._hide_indicator)
        Clock.schedule_once(self._hide_indicator, 1.2)

    def _hide_indicator(self, dt):
        self.indicator.opacity = 0

    def _toggle_panel(self, btn=None):
        self._panel_visible = not self._panel_visible
        self.panel.opacity = 1 if self._panel_visible else 0
        self.panel.disabled = not self._panel_visible
        self.hide_btn.text = "▶" if not self._panel_visible else "◀"

    def _toggle_lock(self, btn):
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
        self.video.source = ch.url
        self.video.state = "play"
        self.ch_label.text = f"{self.current_index+1}/{len(self.filtered)} {ch.name}"

    def _filter(self, *args):
        kw = self.search.text.lower()
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
        data = []
        for i, ch in enumerate(self.filtered):
            fav = "★ " if self.fav_store.exists(ch.url) else "▸ "
            data.append({"text": f"{fav}{ch.name}", "index": i})
        self.rv.data = data

    def _load_cache(self):
        try:
            if self.cache_store.exists("channels"):
                raw = self.cache_store.get("channels")["data"]
                self.channels = []
                for c in raw:
                    self.channels.append(Channel(c["name"], c["url"], c.get("group", "")))
                self._filter()
                if self.filtered:
                    self.current_index = 0
                    self._play_current()
                self._show_info("缓存已加载")
                return
        except:
            pass
        self._do_refresh()

    def _save_cache(self):
        try:
            data = [{"name": c.name, "url": c.url, "group": c.group} for c in self.channels]
            self.cache_store.put("channels", data=data)
        except:
            pass

    def _show_info(self, msg):
        self.ch_label.text = msg
        Clock.schedule_once(lambda dt: self._update_ch_label(), 2)

    def _update_ch_label(self):
        if self.filtered and self.current_index < len(self.filtered):
            self.ch_label.text = f"{self.current_index+1}/{len(self.filtered)} {self.filtered[self.current_index].name}"

    def _do_refresh(self, btn=None):
        if self._loading:
            return
        self._loading = True
        self._show_info("加载中...")
        self._do_fetch_sources(list(DEFAULT_SOURCES))

    def _do_fetch_sources(self, sources):
        if not sources:
            self._loading = False
            self._save_cache()
            self._filter()
            if self.filtered:
                self.current_index = 0
                self._play_current()
            self._update_ch_label()
            return

        name, url = sources[0]

        def on_success(req, result):
            text = result.decode("utf-8") if isinstance(result, bytes) else result
            chs = parse_m3u(text)
            if chs:
                existing = {c.url for c in self.channels}
                for c in chs:
                    if c.url not in existing:
                        self.channels.append(c)
                        existing.add(c.url)
            self._do_fetch_sources(sources[1:])

        def on_error(req, result):
            self._do_fetch_sources(sources[1:])

        fetch_url(url, on_success, on_error)

    def _switch_source(self, btn=None):
        self._do_refresh()

    def _toggle_fav(self, btn=None):
        self._show_fav = not self._show_fav
        self._filter()


class TVPlayerApp(App):
    def build(self):
        self.tv = TVApp()
        return self.tv

    def select_channel(self, index):
        self.tv.select_channel(index)


if __name__ == "__main__":
    TVPlayerApp().run()
