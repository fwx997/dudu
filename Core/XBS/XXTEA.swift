//
//  XXTEA.swift
//  Legado-iOS
//
//  XXTEA 加解密（香色闺阁 .xbs 书源格式兼容）
//  语义对齐社区公开的 xbsrebuild/decode 实现：
//  原始 JSON UTF-8 字节 → 零填充到 4 字节对齐 → 尾部追加小端 uint32 原始长度 → 加密
//

import Foundation

enum XXTEAError: LocalizedError {
    case invalidLength
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidLength: return "无效的 xbs 文件长度"
        case .decodeFailed: return "xbs 解密失败（密钥或格式不匹配）"
        }
    }
}

enum XXTEA {
    // 香色闺阁 .xbs 公开已知密钥（社区制源工具通用）
    private static let key: [UInt8] = [
        0xE5, 0x87, 0xBC, 0xE8, 0xA4, 0x86, 0xE6, 0xBB,
        0xBF, 0xE9, 0x87, 0x91, 0xE6, 0xBA, 0xA1, 0xE5,
    ]

    private static let delta: UInt32 = 0x9E3779B9

    private static func bytesToUInt32s(_ data: [UInt8]) -> [UInt32] {
        var out = [UInt32](repeating: 0, count: (data.count + 3) / 4)
        for (i, b) in data.enumerated() {
            out[i >> 2] |= UInt32(b) << UInt32((i & 3) * 8)
        }
        return out
    }

    private static func uint32sToBytes(_ words: [UInt32], length: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: length)
        for i in 0..<length {
            out[i] = UInt8((words[i >> 2] >> UInt32((i & 3) * 8)) & 0xFF)
        }
        return out
    }

    private static func mx(_ y: UInt32, _ z: UInt32, _ p: Int, _ e: UInt32, _ sum: UInt32, _ key: [UInt32]) -> UInt32 {
        (((z >> 5) ^ (y << 2)) &+ ((y >> 3) ^ (z << 4))) ^ ((sum ^ y) &+ (key[(p & 3) ^ Int(e)] ^ z))
    }

    private static func decrypt(_ v: inout [UInt32], _ keyWords: [UInt32]) {
        let n = v.count
        guard n >= 2 else { return }
        let roundsCount = 6 + 52 / n
        var rounds = roundsCount
        var sum = UInt32(roundsCount) &* delta
        var y = v[0]
        while rounds > 0 {
            let e = (sum >> 2) & 3
            var p = n - 1
            while p > 0 {
                let z = v[p - 1]
                v[p] = v[p] &- mx(y, z, p, e, sum, keyWords)
                y = v[p]
                p -= 1
            }
            let z = v[n - 1]
            v[0] = v[0] &- mx(y, z, 0, e, sum, keyWords)
            y = v[0]
            sum = sum &- delta
            rounds -= 1
        }
    }

    private static func encrypt(_ v: inout [UInt32], _ keyWords: [UInt32]) {
        let n = v.count
        guard n >= 2 else { return }
        var rounds = 6 + 52 / n
        var sum: UInt32 = 0
        var z = v[n - 1]
        while rounds > 0 {
            sum = sum &+ delta
            let e = (sum >> 2) & 3
            for p in 0..<(n - 1) {
                let y = v[p + 1]
                v[p] = v[p] &+ mx(y, z, p, e, sum, keyWords)
                z = v[p]
            }
            let y = v[0]
            v[n - 1] = v[n - 1] &+ mx(y, z, n - 1, e, sum, keyWords)
            z = v[n - 1]
            rounds -= 1
        }
    }

    /// JSON UTF-8 字节 → .xbs 加密字节
    static func encode(_ json: Data) -> Data {
        var buf = [UInt8](json)
        let originalLength = buf.count
        let pad = (4 - originalLength % 4) % 4
        buf.append(contentsOf: [UInt8](repeating: 0, count: pad))
        withUnsafeBytes(of: UInt32(originalLength).littleEndian) { buf.append(contentsOf: $0) }

        var words = bytesToUInt32s(buf)
        encrypt(&words, bytesToUInt32s(key))
        return Data(uint32sToBytes(words, length: buf.count))
    }

    /// .xbs 加密字节 → JSON UTF-8 字节
    static func decode(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count >= 8, bytes.count % 4 == 0 else {
            throw XXTEAError.invalidLength
        }
        var words = bytesToUInt32s(bytes)
        decrypt(&words, bytesToUInt32s(key))
        let out = uint32sToBytes(words, length: bytes.count)
        let payloadLength = bytes.count - 4
        guard payloadLength >= 0 else { throw XXTEAError.invalidLength }
        let m = UInt32(out[payloadLength])
            | UInt32(out[payloadLength + 1]) << 8
            | UInt32(out[payloadLength + 2]) << 16
            | UInt32(out[payloadLength + 3]) << 24
        let mInt = Int(m)
        guard mInt <= payloadLength, payloadLength - mInt <= 3 else {
            throw XXTEAError.decodeFailed
        }
        return Data(out.prefix(mInt))
    }
}
