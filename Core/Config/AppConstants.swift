//
//  AppConstants.swift
//  Legado-iOS
//
//  应用配置常量
//

import Foundation

enum AppConstants {
    // MARK: - 分页配置
    static let bookPageSize = 50
    static let bookLoadDelay: UInt64 = 200_000_000  // 200ms
    
    // MARK: - 缓存配置
    static let imageCacheMemoryLimit = 100 * 1024 * 1024  // 100MB
    static let imageCacheDiskLimit = 500 * 1024 * 1024    // 500MB
    static let imageCompressionQuality: CGFloat = 0.8
    
    // MARK: - 字体配置
    static let defaultFontSize: CGFloat = 18
    static let minFontSize: CGFloat = 8
    static let maxFontSize: CGFloat = 32
    
    // MARK: - 网络配置
    static let defaultTimeout: TimeInterval = 30
    static let maxRetryCount = 3
    
    // MARK: - iCloud 配置
    static let cloudKitContainerId = "iCloud.com.chrn11.legado"
}
