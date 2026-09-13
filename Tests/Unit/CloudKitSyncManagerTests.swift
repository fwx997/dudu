//
//  CloudKitSyncManagerTests.swift
//  Legado-iOS Tests
//
//  iCloud 同步管理器单元测试
//

import XCTest
import CloudKit
@testable import Legado

@MainActor
final class CloudKitSyncManagerTests: XCTestCase {
    
    var manager: CloudKitSyncManager!
    
    override func setUp() async throws {
        try await super.setUp()
        manager = CloudKitSyncManager.shared
    }
    
    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试单例
    func testSharedInstance() {
        let instance1 = CloudKitSyncManager.shared
        let instance2 = CloudKitSyncManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    /// 测试 iCloud 状态检查
    func testStatusCheck() async {
        manager.checkCloudKitStatus()
        
        XCTAssertTrue([.available, .notLoggedIn, .notAvailable, .restricted].contains(manager.currentStatus))
    }
    
    /// 测试状态描述
    func testStatusDescription() {
        manager.currentStatus = .available
        XCTAssertEqual(manager.statusText, "iCloud 同步已就绪")
        
        manager.currentStatus = .notLoggedIn
        XCTAssertEqual(manager.statusText, "未登录 iCloud")
        
        manager.currentStatus = .notAvailable
        XCTAssertEqual(manager.statusText, "iCloud 不可用")
        
        manager.currentStatus = .restricted
        XCTAssertEqual(manager.statusText, "iCloud 受限")
    }
    
    /// 测试同步按钮状态
    func testCanSync() {
        manager.currentStatus = .available
        manager.isSyncing = false
        XCTAssertTrue(manager.canSync)
        
        manager.isSyncing = true
        XCTAssertFalse(manager.canSync)
        
        manager.currentStatus = .notLoggedIn
        XCTAssertFalse(manager.canSync)
    }
    
    /// 测试同步（需要 iCloud 登录）
    func testSync() async throws {
        guard manager.currentStatus == .available else {
            throw XCTSkip("iCloud 未登录")
        }
        
        try await manager.manualSync()
        
        XCTAssertNotNil(manager.lastSyncDate)
        XCTAssertFalse(manager.isSyncing)
    }
    
    /// 测试清除 iCloud 数据
    func testClearCloudData() async throws {
        guard manager.currentStatus == .available else {
            throw XCTSkip("iCloud 未登录")
        }
        
        let expectation = self.expectation(description: "Clear completion")
        
        manager.clearCloudData { success, error in
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10)
    }
}
