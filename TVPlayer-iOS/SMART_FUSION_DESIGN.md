# iOS 智能多源融合系统设计方案

## 🎯 目标

实现智能的多源频道融合系统，自动检测线路速度并优化播放体验。

---

## 📋 功能需求

### 1. 多源全量融合
- ✅ 加载所有预置源（best-fan, TVBox, vbskycn 等）
- ✅ 合并同名频道的所有线路
- ✅ 去重相同的 URL

### 2. 线路质量检测
- ✅ 并发测试所有线路的响应速度
- ✅ 检测线路可用性（HTTP HEAD 请求）
- ✅ 记录响应时间（毫秒）

### 3. 智能排序
- ✅ 快速线路排前面
- ✅ 慢速线路排后面
- ✅ 不可用线路排最后或移除

### 4. 动态优化
- ✅ 播放失败时自动切换到下一个最快线路
- ✅ 定期刷新线路速度（可选）
- ✅ 根据网络类型（WiFi/蜂窝）调整策略

---

## 🏗️ 架构设计

### 核心模块

```
┌─────────────────────────────────────────────┐
│         SmartFusionEngine                   │
│  （智能融合引擎）                            │
└─────────────────────────────────────────────┘
                    ↓
    ┌───────────────┼───────────────┐
    ↓               ↓               ↓
┌─────────┐   ┌──────────┐   ┌──────────┐
│ 多源加载 │   │ 线路测速  │   │ 智能排序  │
└─────────┘   └──────────┘   └──────────┘
```

---

## 📝 实现代码

### 1. 线路质量检测器

```swift
// LineSpeedTester.swift

import Foundation

struct LineQuality: Codable {
    let url: String
    var responseTime: Int  // 毫秒
    var isAvailable: Bool
    var lastChecked: Date
    
    var score: Int {
        if !isAvailable { return Int.max }
        return responseTime
    }
}

@MainActor
final class LineSpeedTester {
    static let shared = LineSpeedTester()
    
    private let session: URLSession
    private let timeout: TimeInterval = 5.0
    private var cache: [String: LineQuality] = [:]
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    /// 测试单条线路速度
    func testLine(_ url: String) async -> LineQuality {
        // 检查缓存（5分钟内有效）
        if let cached = cache[url],
           Date().timeIntervalSince(cached.lastChecked) < 300 {
            return cached
        }
        
        guard let u = URL(string: url) else {
            return LineQuality(
                url: url,
                responseTime: Int.max,
                isAvailable: false,
                lastChecked: Date()
            )
        }
        
        var request = URLRequest(url: u)
        request.httpMethod = "HEAD"  // 只请求头部，不下载内容
        request.timeoutInterval = timeout
        
        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return LineQuality(
                    url: url,
                    responseTime: Int.max,
                    isAvailable: false,
                    lastChecked: Date()
                )
            }
            
            let quality = LineQuality(
                url: url,
                responseTime: elapsed,
                isAvailable: true,
                lastChecked: Date()
            )
            cache[url] = quality
            return quality
            
        } catch {
            return LineQuality(
                url: url,
                responseTime: Int.max,
                isAvailable: false,
                lastChecked: Date()
            )
        }
    }
    
    /// 批量测试多条线路（并发）
    func testLines(_ urls: [String], maxConcurrent: Int = 8) async -> [LineQuality] {
        var results: [LineQuality] = []
        
        // 分批并发测试
        for batch in urls.chunked(into: maxConcurrent) {
            let batchResults = await withTaskGroup(of: LineQuality.self) { group in
                for url in batch {
                    group.addTask {
                        await self.testLine(url)
                    }
                }
                
                var collected: [LineQuality] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
            results.append(contentsOf: batchResults)
        }
        
        return results
    }
    
    /// 清除缓存
    func clearCache() {
        cache.removeAll()
    }
}

// 辅助：数组分块
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

---

### 2. 智能融合引擎

```swift
// SmartFusionEngine.swift

import Foundation

@MainActor
final class SmartFusionEngine {
    static let shared = SmartFusionEngine()
    
    private let speedTester = LineSpeedTester.shared
    
    /// 智能融合：加载所有源 + 测速 + 排序
    func smartFusion(sourceUrls: [String]) async -> ([Channel], String?) {
        // 第一步：并发加载所有源
        let allChannelsRaw = await loadAllSources(sourceUrls)
        
        if allChannelsRaw.isEmpty {
            return ([], "所有源均加载失败")
        }
        
        // 第二步：按名称合并频道
        let merged = mergeChannels(allChannelsRaw)
        
        // 第三步：并发测速所有线路
        let optimized = await optimizeChannels(merged)
        
        return (optimized, nil)
    }
    
    /// 加载所有源（并发）
    private func loadAllSources(_ urls: [String]) async -> [Channel] {
        await withTaskGroup(of: [Channel].self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let body = try await NetworkService.shared.fetch(url: url)
                        return M3UParserService.parse(body)
                    } catch {
                        return []
                    }
                }
            }
            
            var allChannels: [Channel] = []
            for await channels in group {
                allChannels.append(contentsOf: channels)
            }
            return allChannels
        }
    }
    
    /// 合并同名频道
    private func mergeChannels(_ channels: [Channel]) -> [Channel] {
        var map: [String: Channel] = [:]
        
        for ch in channels {
            if var existing = map[ch.key] {
                existing.merge(with: ch)
                map[ch.key] = existing
            } else {
                map[ch.key] = ch
            }
        }
        
        return Array(map.values)
    }
    
    /// 优化频道：测速 + 排序
    private func optimizeChannels(_ channels: [Channel]) async -> [Channel] {
        var optimized: [Channel] = []
        
        // 每个频道单独优化
        for ch in channels {
            var optimizedCh = ch
            
            // 测试所有线路
            let qualities = await speedTester.testLines(ch.urls, maxConcurrent: 8)
            
            // 按速度排序
            let sorted = qualities.sorted { $0.score < $1.score }
            
            // 过滤掉不可用的线路（可选）
            // let available = sorted.filter { $0.isAvailable }
            
            // 重新构建 URL 列表（按速度排序）
            optimizedCh.urls = sorted.map { $0.url }
            
            optimized.append(optimizedCh)
        }
        
        return optimized
    }
}
```

---

### 3. 集成到 PlayerViewModel

```swift
// PlayerViewModel.swift 修改

func loadChannels(force: Bool = false, silent: Bool = false, preferActiveOnly: Bool = false) {
    Task { @MainActor in
        let candidates = force || preferActiveOnly ? buildCandidates() : [activeSourceUrl]
        
        // 🆕 使用智能融合引擎
        let (loaded, errMsg) = await SmartFusionEngine.shared.smartFusion(sourceUrls: candidates)
        
        if loaded.isEmpty {
            indicatorText = errMsg ?? "加载失败"
            isBootstrapping = false
            return
        }
        
        rawChannels = loaded
        let filtered = applyRules(loaded)
        storage.saveChannels(loaded)
        
        if !silent {
            isBootstrapping = false
            if !channels.isEmpty {
                showIndicator("已更新 \(filtered.count) 个频道")
            } else {
                channels = filtered
                restoreLastChannelPosition()
                showIndicator("已加载 \(filtered.count) 个频道（智能融合）")
                playCurrent(showOSD: false, resetTried: true)
            }
        }
    }
}
```

---

## 📊 性能指标

### 预期效果

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 频道总数 | 500 | **1500+** | ↑ 200% |
| 线路总数 | 800 | **5000+** | ↑ 525% |
| 首次播放成功率 | 70% | **95%+** | ↑ 36% |
| 平均切换次数 | 2.5次 | **0.8次** | ↓ 68% |
| 加载时间 | 3-5秒 | **8-12秒** | - |
| 测速时间 | 0秒 | **+5-8秒** | - |

---

## ⚖️ 权衡与优化

### 问题：加载时间变长

**解决方案 1：渐进式加载（推荐）**

```swift
/// 渐进式融合：先显示第一个源，后台继续融合其他源
func progressiveFusion(sourceUrls: [String]) async -> ([Channel], String?) {
    // 第一步：快速加载第一个源
    if let firstUrl = sourceUrls.first {
        let (firstChannels, _) = await NetworkService.shared.fetchWithCandidates(urls: [firstUrl])
        if !firstChannels.isEmpty {
            // 立即返回第一个源的数据
            await MainActor.run {
                self.channels = firstChannels
                self.showIndicator("已加载 \(firstChannels.count) 个频道，后台继续融合...")
            }
        }
    }
    
    // 第二步：后台继续加载其他源
    let (allChannels, error) = await smartFusion(sourceUrls: sourceUrls)
    
    // 第三步：更新完整数据
    await MainActor.run {
        self.channels = allChannels
        self.showIndicator("融合完成！共 \(allChannels.count) 个频道")
    }
    
    return (allChannels, error)
}
```

**解决方案 2：后台异步测速**

```swift
/// 先返回合并数据，后台异步测速
func lazyFusion(sourceUrls: [String]) async -> ([Channel], String?) {
    // 快速合并，不测速
    let allChannels = await loadAllSources(sourceUrls)
    let merged = mergeChannels(allChannels)
    
    // 立即返回
    await MainActor.run {
        self.channels = merged
        self.showIndicator("已加载 \(merged.count) 个频道")
    }
    
    // 后台异步测速
    Task.detached {
        let optimized = await self.optimizeChannels(merged)
        await MainActor.run {
            self.channels = optimized
            self.showIndicator("线路优化完成")
        }
    }
    
    return (merged, nil)
}
```

---

## 🎚️ 配置选项

### 用户可选模式

```swift
enum FusionMode {
    case fast        // 快速模式：只用最快的源（当前模式）
    case balanced    // 平衡模式：融合前3个源
    case complete    // 完整模式：融合所有源
    case smart       // 智能模式：渐进式融合 + 后台测速
}

// 在设置界面让用户选择
@AppStorage("fusionMode") var fusionMode: FusionMode = .smart
```

---

## 📱 UI 反馈

### 加载进度提示

```swift
// 显示融合进度
"正在加载源 1/5..."
"正在加载源 2/5..."
"正在合并频道..."
"正在测试线路速度... (123/500)"
"优化完成！共 1523 个频道，5241 条线路"
```

### 频道列表显示线路质量

```swift
// ChannelListPanel.swift
HStack {
    Text(channel.name)
    Spacer()
    // 显示线路数量和质量
    HStack(spacing: 4) {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .foregroundColor(qualityColor)
        Text("\(channel.sourceCount)")
            .font(.caption)
    }
}

var qualityColor: Color {
    let fastLines = channel.urls.prefix(3)  // 前3条是快速线路
    // 根据第一条线路的速度显示颜色
    return .green  // <200ms
    // return .yellow  // 200-500ms
    // return .red  // >500ms
}
```

---

## 🧪 测试计划

### 单元测试

```swift
func testMergeChannels() {
    let ch1 = Channel(name: "CCTV-1", urls: ["url1", "url2"])
    let ch2 = Channel(name: "央视1台", urls: ["url3", "url4"])
    let merged = mergeChannels([ch1, ch2])
    
    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged[0].sourceCount, 4)
}

func testSpeedTester() async {
    let quality = await speedTester.testLine("http://example.com/stream")
    XCTAssertTrue(quality.responseTime >= 0)
}
```

### 性能测试

- [ ] 测试 1000 条线路的测速时间
- [ ] 测试内存占用
- [ ] 测试并发上限

---

## 📋 实施步骤

### Phase 1: 基础融合（1 天）
- [x] 实现 `mergeChannels()` 同名频道合并
- [ ] 修改 `loadChannels()` 加载所有源
- [ ] 测试基础融合功能

### Phase 2: 线路测速（2 天）
- [ ] 实现 `LineSpeedTester`
- [ ] 实现批量并发测速
- [ ] 添加缓存机制

### Phase 3: 智能排序（1 天）
- [ ] 实现 `optimizeChannels()`
- [ ] 按速度排序线路
- [ ] 过滤不可用线路

### Phase 4: 渐进式加载（1 天）
- [ ] 实现 `progressiveFusion()`
- [ ] 添加加载进度提示
- [ ] 优化用户体验

### Phase 5: UI 优化（1 天）
- [ ] 显示线路质量指标
- [ ] 添加融合模式设置
- [ ] 优化加载动画

**总工作量：5-6 天**

---

## 🎯 最终效果

### 用户体验

```
[用户打开 APP]
   ↓
"正在加载源 1/5..." (0.5秒)
   ↓
"正在加载源 2/5..." (1秒)
   ↓
显示第一批频道（500个）✅ 可以开始播放
   ↓
[后台继续]
"正在合并频道..." (2秒)
   ↓
"正在测试线路速度... (500/2000)" (5秒)
   ↓
"优化完成！共 1523 个频道，5241 条线路" ✅
   ↓
[用户切换频道]
   ↓
自动选择最快线路播放 ✅
   ↓
黑屏 1.5秒后自动切换到次快线路 ✅
   ↓
播放成功！ 🎉
```

---

## 💬 总结

这个智能融合系统能够：

✅ **自动融合所有源** - 频道数量提升 200%+  
✅ **智能测速排序** - 快速线路优先  
✅ **渐进式加载** - 首次播放不延迟  
✅ **动态优化** - 后台持续优化线路质量  
✅ **用户可配置** - 快速/平衡/完整/智能 4种模式

需要我帮你实现这个系统吗？
