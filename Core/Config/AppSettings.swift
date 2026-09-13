//
//  AppSettings.swift
//  Legado-iOS
//
//  全局应用设置管理器
//

import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 搜索设置

    /// 搜索结果过滤方式: 0-不过滤, 1-包含关键字, 2-匹配关键字
    @Published var searchFilterType: Int {
        didSet { defaults.set(searchFilterType, forKey: "search_filterResultT") }
    }

    /// 搜索站点类型: text/comic/audio/video
    @Published var searchSourceType: String {
        didSet { defaults.set(searchSourceType, forKey: "search_filterSourceT") }
    }

    /// 显示搜索热词
    @Published var showSearchHotWords: Bool {
        didSet { defaults.set(showSearchHotWords, forKey: "search_showRel") }
    }

    /// 显示搜索历史
    @Published var showSearchHistory: Bool {
        didSet { defaults.set(showSearchHistory, forKey: "search_showHis") }
    }

    /// 过滤提示
    @Published var showFilterTip: Bool {
        didSet { defaults.set(showFilterTip, forKey: "search_showFilterTip") }
    }

    // MARK: - 阅读设置

    /// 繁简转换: 0-保持原文, 1-简体, 2-繁体
    @Published var textConversion: Int {
        didSet { defaults.set(textConversion, forKey: "fanjianZi") }
    }

    /// 启动后继续上次阅读
    @Published var autoRead: Bool {
        didSet { defaults.set(autoRead, forKey: "autoRead") }
    }

    /// 阅读时屏幕常亮
    @Published var keepScreenOn: Bool {
        didSet { defaults.set(keepScreenOn, forKey: "changLiang") }
    }

    /// 阅读时侧滑返回方式: 0-禁用, 1-防误触, 2-总是开启
    @Published var popGestureType: Int {
        didSet { defaults.set(popGestureType, forKey: "r_popGestureType") }
    }

    /// 阅读时顶部状态栏样式: 0-不显示, 1-白色, 3-黑色
    @Published var statusBarStatus: Int {
        didSet { defaults.set(statusBarStatus, forKey: "r_statusBarStatus") }
    }

    /// 显示章节标题
    @Published var showChapterTitle: Bool {
        didSet { defaults.set(showChapterTitle, forKey: "tr_showCpTitle") }
    }

    /// 显示章节页进度
    @Published var showPageProgress: Bool {
        didSet { defaults.set(showPageProgress, forKey: "tr_showProgress") }
    }

    /// 显示全书百分比进度
    @Published var showBookProgress: Bool {
        didSet { defaults.set(showBookProgress, forKey: "tr_showFProgress") }
    }

    /// 显示电池电量
    @Published var showBatteryLabel: Bool {
        didSet { defaults.set(showBatteryLabel, forKey: "tr_showBatLabel") }
    }

    /// 显示电池图标
    @Published var showBatteryIcon: Bool {
        didSet { defaults.set(showBatteryIcon, forKey: "tr_showBatView") }
    }

    /// 显示时间
    @Published var showTime: Bool {
        didSet { defaults.set(showTime, forKey: "tr_showTime") }
    }

    /// 阅读时自动深色模式
    @Published var autoDarkMode: Bool {
        didSet { defaults.set(autoDarkMode, forKey: "tr_autoDarkModel") }
    }

    /// iPad 横屏显示 2 列
    @Published var iPadDoubleColumn: Bool {
        didSet { defaults.set(iPadDoubleColumn, forKey: "tr_iPadDoubleCol") }
    }

    /// 阅读时自动隐藏小横条
    @Published var autoHideHomeIndicator: Bool {
        didSet { defaults.set(autoHideHomeIndicator, forKey: "tr_autoHomeIndicator") }
    }

    /// 文本阅读界面长按选择文字
    @Published var useLongPress: Bool {
        didSet { defaults.set(useLongPress, forKey: "tr_useLongPress") }
    }

    // MARK: - 朗读设置

    /// 朗读模式: 0-按页朗读, 1-按章朗读
    @Published var speakType: Int {
        didSet { defaults.set(speakType, forKey: "tr_speakType") }
    }

    /// 朗读字体大小
    @Published var speakFontSize: Int {
        didSet { defaults.set(speakFontSize, forKey: "tr_fontSize") }
    }

    // MARK: - 漫画阅读设置

    /// 快速滚动
    @Published var comicFastScroll: Bool {
        didSet { defaults.set(comicFastScroll, forKey: "cr_fastS") }
    }

    /// 显示分割线
    @Published var comicShowSeparator: Bool {
        didSet { defaults.set(comicShowSeparator, forKey: "cr_showS") }
    }

    /// 显示滚动条
    @Published var comicShowScrollbar: Bool {
        didSet { defaults.set(comicShowScrollbar, forKey: "cr_showSI") }
    }

    // MARK: - 书架设置

    /// 书架更新策略: 0-不更新, -1-启动时更新, 600-10分钟, 1800-30分钟, 3600-1小时, 86400-24小时
    @Published var bookshelfUpdateType: Int {
        didSet { defaults.set(bookshelfUpdateType, forKey: "bs_updateType") }
    }

    /// 书架排序方式: 0-按阅读时间, 1-按添加时间, 2-按更新排, 3-综合排序
    @Published var bookshelfSortType: Int {
        didSet { defaults.set(bookshelfSortType, forKey: "bs_sortType") }
    }

    /// 试读提示
    @Published var showTrialTip: Bool {
        didSet { defaults.set(showTrialTip, forKey: "bs_shiDu") }
    }

    // MARK: - iCloud 设置

    /// 增量备份
    @Published var incrementalBackup: Bool {
        didSet { defaults.set(incrementalBackup, forKey: "incCloud") }
    }

    /// 自动备份
    @Published var autoBackup: Bool {
        didSet { defaults.set(autoBackup, forKey: "autoCloud") }
    }

    // MARK: - 初始化

    private init() {
        // 搜索设置
        self.searchFilterType = defaults.integer(forKey: "search_filterResultT")
        if defaults.object(forKey: "search_filterResultT") == nil {
            self.searchFilterType = 1 // 默认包含关键字
        }

        self.searchSourceType = defaults.string(forKey: "search_filterSourceT") ?? "text"
        self.showSearchHotWords = defaults.object(forKey: "search_showRel") as? Bool ?? true
        self.showSearchHistory = defaults.object(forKey: "search_showHis") as? Bool ?? true
        self.showFilterTip = defaults.object(forKey: "search_showFilterTip") as? Bool ?? true

        // 阅读设置
        self.textConversion = defaults.integer(forKey: "fanjianZi")
        self.autoRead = defaults.bool(forKey: "autoRead")
        self.keepScreenOn = defaults.bool(forKey: "changLiang")
        self.popGestureType = defaults.object(forKey: "r_popGestureType") as? Int ?? 2
        self.statusBarStatus = defaults.integer(forKey: "r_statusBarStatus")

        self.showChapterTitle = defaults.object(forKey: "tr_showCpTitle") as? Bool ?? true
        self.showPageProgress = defaults.object(forKey: "tr_showProgress") as? Bool ?? true
        self.showBookProgress = defaults.bool(forKey: "tr_showFProgress")
        self.showBatteryLabel = defaults.bool(forKey: "tr_showBatLabel")
        self.showBatteryIcon = defaults.bool(forKey: "tr_showBatView")
        self.showTime = defaults.bool(forKey: "tr_showTime")

        self.autoDarkMode = defaults.bool(forKey: "tr_autoDarkModel")
        self.iPadDoubleColumn = defaults.bool(forKey: "tr_iPadDoubleCol")
        self.autoHideHomeIndicator = defaults.object(forKey: "tr_autoHomeIndicator") as? Bool ?? true
        self.useLongPress = defaults.object(forKey: "tr_useLongPress") as? Bool ?? true

        // 朗读设置
        self.speakType = defaults.integer(forKey: "tr_speakType")
        self.speakFontSize = defaults.object(forKey: "tr_fontSize") as? Int ?? 20

        // 漫画设置
        self.comicFastScroll = defaults.bool(forKey: "cr_fastS")
        self.comicShowSeparator = defaults.bool(forKey: "cr_showS")
        self.comicShowScrollbar = defaults.bool(forKey: "cr_showSI")

        // 书架设置
        self.bookshelfUpdateType = defaults.object(forKey: "bs_updateType") as? Int ?? 1800
        self.bookshelfSortType = defaults.object(forKey: "bs_sortType") as? Int ?? 3
        self.showTrialTip = defaults.bool(forKey: "bs_shiDu")

        // iCloud 设置
        self.incrementalBackup = defaults.object(forKey: "incCloud") as? Bool ?? true
        self.autoBackup = defaults.object(forKey: "autoCloud") as? Bool ?? true
    }

    // MARK: - 辅助方法

    /// 重置所有设置
    func resetToDefaults() {
        searchFilterType = 1
        searchSourceType = "text"
        showSearchHotWords = true
        showSearchHistory = true
        showFilterTip = true

        textConversion = 0
        autoRead = false
        keepScreenOn = false
        popGestureType = 2
        statusBarStatus = 0

        showChapterTitle = true
        showPageProgress = true
        showBookProgress = false
        showBatteryLabel = false
        showBatteryIcon = false
        showTime = false

        autoDarkMode = false
        iPadDoubleColumn = false
        autoHideHomeIndicator = true
        useLongPress = true

        speakType = 0
        speakFontSize = 20

        comicFastScroll = false
        comicShowSeparator = false
        comicShowScrollbar = false

        bookshelfUpdateType = 1800
        bookshelfSortType = 3
        showTrialTip = false

        incrementalBackup = true
        autoBackup = true
    }

    /// 获取搜索过滤类型描述
    var searchFilterTypeDescription: String {
        switch searchFilterType {
        case 0: return "不过滤"
        case 1: return "包含关键字"
        case 2: return "匹配关键字"
        default: return "未知"
        }
    }

    /// 获取搜索站点类型描述
    var searchSourceTypeDescription: String {
        switch searchSourceType {
        case "text": return "文本/小说"
        case "comic": return "图片/漫画"
        case "audio": return "音频/听书"
        case "video": return "视频/电影"
        default: return "全部"
        }
    }

    /// 获取繁简转换描述
    var textConversionDescription: String {
        switch textConversion {
        case 0: return "保持原文"
        case 1: return "简体"
        case 2: return "繁体"
        default: return "未知"
        }
    }
}
