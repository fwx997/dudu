# Legado iOS

📚 基于 Legado 的 iOS 原生阅读应用  纯vibe coding玩具

[![iOS CI](https://github.com/chrn11/legado-ios/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/chrn11/legado-ios/actions/workflows/ios-ci.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2016.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.10-orange)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## ✨ 特性

### 核心功能
- 📖 **书源管理** - 支持自定义书源规则，导入/导出书源，批量操作
- 🔍 **聚合搜索** - 多书源并发搜索，智能排序，搜索历史
- 📱 **书架管理** - 网格/列表视图，分组管理，进度追踪
- 📖 **阅读器** - 仿真翻页、自动翻页、多主题支持
- 🎯 **规则引擎** - 支持 CSS/XPath/JSONPath/正则/JavaScript，模板语法
- 💾 **本地书籍** - 支持 TXT/EPUB 格式
- 🔄 **替换净化** - 广告替换，内容净化，正则支持

### 高级功能
- 🔊 **TTS 语音朗读** - 系统语音引擎，朗读控制
- ☁️ **WebDAV 同步** - 增量同步，进度备份
- 📊 **阅读统计** - 时长统计，阅读记录
- 📡 **RSS 订阅** - 自定义规则，全文抓取
- 🔧 **书源调试器** - 实时调试，规则验证
- 🌙 **阅读增强** - 护眼提醒，夜间模式

## 📋 项目结构

```
Legado-iOS/
├── App/                      # 应用入口
├── Core/                     # 核心模块
│   ├── Persistence/         # CoreData 持久化
│   ├── Network/             # 网络请求
│   └── RuleEngine/          # 规则解析引擎 ⭐
├── Features/                 # 功能模块
│   ├── Bookshelf/           # 书架
│   ├── Reader/              # 阅读器
│   ├── Search/              # 搜索
│   ├── Source/              # 书源管理
│   └── Config/              # 设置
└── UIComponents/            # 通用 UI 组件
```

## 🚀 快速开始

### 环境要求

- Xcode 15.0+
- iOS 16.0+
- Swift 5.10+
- macOS 13+ (编译需要)

### 安装依赖

```bash
cd Legado-iOS
xcodebuild -resolvePackageDependencies -scheme Legado
```

### 运行项目

1. 在 Xcode 中打开 `Legado.xcodeproj`
2. 选择目标设备（真机或模拟器）
3. 点击运行（⌘R）

### GitHub Actions 编译

项目在以下情况会自动编译：
- Push 到 main/develop 分支
- 创建 Pull Request
- 手动触发 workflow

编译产物会上传到 Actions Artifacts，可以在 [Actions](https://github.com/chrn11/legado-ios/actions) 页面下载。

## 📖 书源规则

### 支持的选择器类型

- **CSS 选择器**: `div.book@text`, `a@href`
- **XPath**: `//div[@class='book']`
- **JSONPath**: `$.book.name`, `$.list[0].title`
- **正则**: `regex:\d+`
- **JavaScript**: `{{js result + ' suffix'}}`

### 模板语法

支持变量替换和嵌套模板：

```
{{key}}              // 搜索关键词
{{page}}             // 页码
{{$.jsonPath}}       // JSONPath 取值
{{key,default}}      // 默认值
@put,{key,value}     // 变量存储
@get,{key}           // 变量读取
```

### 书源导入格式

```json
{
  "bookSourceUrl": "https://example.com",
  "bookSourceName": "示例书源",
  "bookSourceGroup": "分组",
  "bookSourceType": 0,
  "searchUrl": "https://example.com/search?keyword={{key}}",
  "ruleSearch": {
    "bookList": "div.book-item",
    "name": "h2@text",
    "author": "span.author@text",
    "bookUrl": "a@href"
  },
  "ruleContent": {
    "content": "div.content@html"
  }
}
```

## 🛠 开发进度

| 里程碑 | 描述 | 状态 |
|--------|------|------|
| M0 | 基础架构（项目骨架、CoreData、网络层、规则引擎） | ✅ 完成 |
| M1 | 书源与搜索（书源管理、搜索功能、书籍详情） | ✅ 完成 |
| M2 | 阅读主链路（目录解析、阅读器、书架管理） | ✅ 完成 |
| M3 | 替换规则（ReplaceEngine、规则调试工具） | ✅ 完成 |
| M4 | 本地书籍（TXT/EPUB 解析） | ✅ 完成 |
| M5 | 高级功能（TTS、WebDAV、阅读统计、RSS） | ✅ 完成 |

### 详细功能清单

<details>
<summary>点击展开完整功能列表</summary>

#### 阅读器
- [x] 仿真翻页（CurlPageView）
- [x] 自动翻页（定时/按章）
- [x] 多主题支持
- [x] 阅读进度保存
- [x] 书签管理
- [x] 章节缓存

#### 书源管理
- [x] 书源导入/导出
- [x] 批量操作（启用/禁用/删除）
- [x] 书源订阅
- [x] 书源调试器
- [x] QR 码导入

#### 规则引擎
- [x] CSS 选择器
- [x] XPath 支持
- [x] JSONPath 支持
- [x] 正则表达式
- [x] JavaScript 执行
- [x] 模板引擎（@put/@get）

#### 数据同步
- [x] WebDAV 同步
- [x] 增量备份
- [x] 数据迁移兼容
- [x] JSON 导入/导出

#### 其他
- [x] TTS 语音朗读
- [x] RSS 订阅
- [x] 阅读统计
- [x] 阅读提醒
- [x] 发现页

</details>

## 📸 截图

待更新...

## 🔧 技术栈

- **UI**: SwiftUI + UIKit
- **架构**: MVVM + Clean Architecture
- **数据库**: CoreData
- **网络**: URLSession
- **HTML 解析**: SwiftSoup
- **XPath**: Kanna
- **JS 引擎**: JavaScriptCore
- **EPUB**: EPUBKit

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 开源协议

本项目遵循 GPL-3.0 协议。

## 🔗 链接

- [原项目 (Android)](https://github.com/gedoor/legado)
- [帮助文档](https://www.legado.top/)
- [书源规则教程](https://mgz0227.github.io/The-tutorial-of-Legado/)

## ⚠️ 免责声明

本应用仅供学习交流使用，请勿用于商业目的。
使用本应用时请遵守相关法律法规，尊重版权。
