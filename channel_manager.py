"""频道源管理模块"""
import requests
import re
from typing import List, Dict, Tuple
import time


class Channel:
    """频道类"""
    def __init__(self, name: str, url: str = "", group: str = "", logo: str = "", urls: list = None):
        self.name = (name or "未知").strip() or "未知"
        self.group = (group or "未分组").strip() or "未分组"
        self.logo = logo or ""
        self.is_available = None
        self.response_time = 0
        self._urls: list = []
        if urls:
            for u in urls:
                self.add_url(u)
        elif url:
            self.add_url(url)

    @property
    def url(self) -> str:
        return self._urls[0] if self._urls else ""

    @url.setter
    def url(self, value: str):
        if value and value.strip():
            clean = value.strip()
            if clean not in self._urls:
                self._urls.insert(0, clean)

    def add_url(self, url: str):
        clean = (url or "").strip()
        if clean and clean not in self._urls:
            self._urls.append(clean)

    def get_urls(self) -> list:
        return list(self._urls)

    def get_source_count(self) -> int:
        return len(self._urls)


class ChannelManager:
    """频道源管理器"""
    
    # 预置的直播源列表
    SOURCE_URLS = [
        "https://raw.githubusercontent.com/best-fan/iptv-sources/main/cn_all.m3u8",
        "https://raw.githubusercontent.com/Supprise0901/TVBox_live/main/live.txt",
        "https://raw.githubusercontent.com/vbskycn/iptv/master/tv/tv.m3u",
    ]
    
    # GitHub镜像源
    MIRROR_URLS = [
        "https://ghfast.top/raw.githubusercontent.com/",
        "https://raw.gitmirror.com/",
        "https://raw.kkgithub.com/",
    ]
    
    def __init__(self):
        self.channels: List[Channel] = []
        self.groups: Dict[str, List[Channel]] = {}
        self.current_source_index = 0
        
    def get_mirrored_url(self, url: str) -> List[str]:
        """生成带镜像的URL列表"""
        urls = [url]
        for mirror in self.MIRROR_URLS:
            if "raw.githubusercontent.com" in url:
                mirrored = url.replace("https://raw.githubusercontent.com/", mirror)
                urls.append(mirrored)
        return urls
    
    def fetch_source(self, url: str = None) -> bool:
        """获取直播源"""
        if url is None:
            url = self.SOURCE_URLS[self.current_source_index % len(self.SOURCE_URLS)]
        
        urls_to_try = self.get_mirrored_url(url)
        
        for try_url in urls_to_try:
            try:
                print(f"正在获取源: {try_url}")
                headers = {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
                response = requests.get(try_url, headers=headers, timeout=15)
                response.raise_for_status()
                
                content = response.text
                if content:
                    self.parse_m3u(content)
                    print(f"成功获取 {len(self.channels)} 个频道")
                    return True
            except Exception as e:
                print(f"获取失败 {try_url}: {e}")
                continue
        
        return False
    
    def parse_m3u(self, content: str) -> None:
        """解析M3U格式的直播源"""
        self.channels.clear()
        self.groups.clear()

        from collections import OrderedDict
        channels_map: "OrderedDict[str, Channel]" = OrderedDict()

        lines = content.strip().split('\n')
        pending_name = None
        pending_group = "未分组"
        pending_logo = ""

        for line in lines:
            line = line.strip()
            if not line:
                continue

            if line.startswith('#EXTINF:'):
                info = line[8:]
                group_match = re.search(r'group-title="([^"]*)"', info)
                pending_group = group_match.group(1) if group_match else "其他频道"
                logo_match = re.search(r'tvg-logo="([^"]*)"', info)
                pending_logo = logo_match.group(1) if logo_match else ""
                name_match = re.search(r',(.+)$', info)
                pending_name = name_match.group(1).strip() if name_match else "未知频道"
            elif line.startswith('#') or pending_name is None:
                continue
            else:
                # 合并同名频道的多个 URL
                key = pending_name.lower().strip()
                if key not in channels_map:
                    channels_map[key] = Channel(name=pending_name, group=pending_group, logo=pending_logo)
                channels_map[key].add_url(line)
                pending_name = None
                pending_group = "未分组"
                pending_logo = ""

        self.channels = list(channels_map.values())
        for ch in self.channels:
            if ch.group not in self.groups:
                self.groups[ch.group] = []
            self.groups[ch.group].append(ch)
    
    def check_channel_availability(self, channel: Channel, timeout: int = 5) -> bool:
        """检测频道是否可用"""
        try:
            start_time = time.time()
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            response = requests.head(channel.url, headers=headers, timeout=timeout, allow_redirects=True)
            channel.response_time = int((time.time() - start_time) * 1000)
            channel.is_available = response.status_code == 200
            return channel.is_available
        except:
            channel.is_available = False
            return False
    
    def get_channels_by_group(self, group: str) -> List[Channel]:
        """获取指定组的频道"""
        return self.groups.get(group, [])
    
    def get_all_groups(self) -> List[str]:
        """获取所有分组"""
        return list(self.groups.keys())
    
    def switch_source(self) -> bool:
        """切换到下一个源"""
        self.current_source_index = (self.current_source_index + 1) % len(self.SOURCE_URLS)
        return self.fetch_source()
    
    def refresh(self) -> bool:
        """刷新当前源"""
        return self.fetch_source()
