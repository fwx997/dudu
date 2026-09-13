//
//  CloudKitSyncManager.swift
//  Legado-iOS
//
//  iCloud 同步管理器（完整版）
//

import Foundation
import CloudKit
import CoreData

/// iCloud 同步状态
enum iCloudStatus {
    case available       // 可用
    case notLoggedIn     // 未登录
    case notAvailable    // 不可用
    case restricted      // 受限
    
    var description: String {
        switch self {
        case .available: return "iCloud 同步已就绪"
        case .notLoggedIn: return "未登录 iCloud"
        case .notAvailable: return "iCloud 不可用"
        case .restricted: return "iCloud 受限"
        }
    }
    
    var icon: String {
        switch self {
        case .available: return "checkmark.icloud"
        case .notLoggedIn: return "exclamationmark.icloud"
        case .notAvailable: return "slash.icloud"
        case .restricted: return "lock.icloud"
        }
    }
}

final class CloudKitSyncManager: NSObject, ObservableObject {
    static let shared = CloudKitSyncManager()
    
    // MARK: - 属性
    @Published var currentStatus: iCloudStatus = .notAvailable
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    
    private let container: CKContainer
    
    // MARK: - 初始化
    init(containerId: String = "iCloud.com.chrn11.legado") {
        container = CKContainer(identifier: containerId)
        super.init()
        setupNotifications()
        Task { await refreshCloudStatus() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 设置通知
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountChanged),
            name: .CKAccountChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    // MARK: - 检查 iCloud 状态
    func checkCloudKitStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.currentStatus = .available
                case .noAccount:
                    self?.currentStatus = .notLoggedIn
                case .restricted:
                    self?.currentStatus = .restricted
                case .couldNotDetermine:
                    self?.currentStatus = .notAvailable
                @unknown default:
                    self?.currentStatus = .notAvailable
                }
            }
        }
    }

    @MainActor
    func refreshCloudStatus() async {
        let status = await withCheckedContinuation { continuation in
            container.accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }

        switch status {
        case .available:
            currentStatus = .available
        case .noAccount:
            currentStatus = .notLoggedIn
        case .restricted:
            currentStatus = .restricted
        case .couldNotDetermine:
            currentStatus = .notAvailable
        @unknown default:
            currentStatus = .notAvailable
        }
    }
    
    // MARK: - 请求 iCloud 访问
    func requestiCloudAccess(completion: @escaping (Bool, Error?) -> Void) {
        container.accountStatus { status, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            switch status {
            case .available:
                completion(true, nil)
            case .noAccount, .restricted, .couldNotDetermine:
                completion(false, nil)
            @unknown default:
                completion(false, nil)
            }
        }
    }
    
    // MARK: - 手动同步
    @MainActor
    func manualSync() async throws {
        guard !isSyncing else {
            throw CloudKitError.syncFailed
        }
        
        guard currentStatus == .available else {
            throw CloudKitError.notAvailable
        }
        
        isSyncing = true
        
        do {
            try await CoreDataStack.shared.syncToCloud()
            lastSyncDate = Date()
            isSyncing = false
        } catch {
            isSyncing = false
            throw error
        }
    }
    
    // MARK: - 处理远程变化
    @objc private func handleRemoteChange() {
        print("📡 iCloud 远程变化通知")
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
        }
    }
    
    // MARK: - iCloud 账号变化
    @objc private func accountChanged() {
        Task { @MainActor in
            await refreshCloudStatus()
            if currentStatus == .available {
                do {
                    try await manualSync()
                } catch {
                    print("❌ iCloud 自动同步失败：\(error)")
                }
            }
        }
    }
    
    // MARK: - 清除 iCloud 数据
    func clearCloudData(completion: @escaping (Bool, Error?) -> Void) {
        let privateDatabase = container.privateCloudDatabase
        privateDatabase.delete(withRecordZoneID: CKRecordZone.default().zoneID) { _, error in
            completion(error == nil, error)
        }
    }
}

// MARK: - SwiftUI 扩展
#if canImport(SwiftUI)
import SwiftUI

extension CloudKitSyncManager {
    var statusText: String { currentStatus.description }
    var statusIcon: String { currentStatus.icon }
    var canSync: Bool { currentStatus == .available && !isSyncing }
}
#endif
