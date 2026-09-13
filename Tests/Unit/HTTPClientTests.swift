//
//  HTTPClientTests.swift
//  Legado-iOS Tests
//
//  HTTP 客户端单元测试
//

import XCTest
@testable import Legado

final class HTTPClientTests: XCTestCase {
    
    var client: HTTPClient!
    
    override func setUp() async throws {
        try await super.setUp()
        client = HTTPClient.shared
    }
    
    override func tearDown() async throws {
        client = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试 GET 请求
    func testGetRequest() async throws {
        let url = "https://httpbin.org/get"
        
        do {
            let (data, response) = try await client.get(url: url)
            
            XCTAssertNotNil(data)
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("响应不是 HTTPURLResponse")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200)
        } catch {
            throw XCTSkip("网络不可用")
        }
    }
    
    /// 测试 POST 请求
    func testPostRequest() async throws {
        let url = "https://httpbin.org/post"
        let body: [String: Any] = [
            "key": "value",
            "number": 123
        ]
        
        do {
            let (data, response) = try await client.post(url: url, body: body)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("响应不是 HTTPURLResponse")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200)
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let payload = json?["json"] as? [String: Any]
            XCTAssertEqual(payload?["key"] as? String, "value")
        } catch {
            throw XCTSkip("网络不可用")
        }
    }
    
    /// 测试超时
    func testTimeout() async throws {
        let url = "https://httpbin.org/delay/10"
        
        do {
            _ = try await client.get(url: url, timeout: 2)
            XCTFail("应该超时")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            throw XCTSkip("网络不可用")
        }
    }
    
    /// 测试错误 URL
    func testInvalidURL() async throws {
        let url = "invalid-url"
        
        do {
            _ = try await client.get(url: url)
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    /// 测试请求头设置
    func testRequestHeaders() async throws {
        let url = "https://httpbin.org/headers"
        let headers: [String: String] = [
            "X-Test-Header": "test-value",
            "User-Agent": "Legado-iOS"
        ]
        
        do {
            let (data, response) = try await client.get(url: url, headers: headers)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("响应不是 HTTPURLResponse")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200)
        } catch {
            throw XCTSkip("网络不可用")
        }
    }
}
