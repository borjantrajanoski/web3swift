//
//  Data+Extension.swift
//  web3swift
//
//  Created by Alexander Vlasov on 15.01.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation

/// Data errors
public enum DataError: Error {
    /// Throws if data cannot be converted to string
    case hexStringCorrupted(String)
    /// Printable / user displayable description
    public var localizedDescription: String {
        switch self {
        case let .hexStringCorrupted(string):
            return "Cannot convert hex string \"\(string)\" to data"
        }
    }
}

extension Data {
    /// Returns Sha256 hash of this data
    public func sha256() -> Data {
        return digest(using: .sha256)
    }
}

extension Data {
    /// Inits with array of type
    public init<T>(raw: T) {
        let pointer = Swift.withUnsafeBytes(of: raw) { $0.bindMemory(to: T.self) }
        self.init(buffer: pointer)
    }
    public init<T>(fromArray values: [T]) {
        var values = values
        self.init(buffer: UnsafeBufferPointer(start: &values, count: values.count))
    }
    public var bytes: [UInt8] {
        return Array(self)
    }
    
    /// Represents data as array of type
    public func toArray<T>(type _: T.Type) -> [T] {
        return withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count / MemoryLayout<T>.stride))
        }
    }

    /// Constant time comparsion between two data objects
    /// - seealso: [https://codahale.com/a-lesson-in-timing-attacks/](https://codahale.com/a-lesson-in-timing-attacks/)
    public func constantTimeComparisonTo(_ other: Data?) -> Bool {
        guard let rhs = other else { return false }
        guard count == rhs.count else { return false }
        var difference = UInt8(0x00)
        for i in 0 ..< count { // compare full length
            difference |= self[i] ^ rhs[i] // constant time
        }
        return difference == UInt8(0x00)
    }

    /// Replaces all data bytes with zeroes.
	///
    /// This one needs because if data deinits, it still will stay in the memory until the override.
	///
	/// webswift uses that to clear private key from memory.
    /// - Parameter data: Data to be cleared
    public static func zero(_ data: inout Data) {
        let count = data.count
        data.withUnsafeMutableBytes { (dataPtr: UnsafeMutablePointer<UInt8>) in
            dataPtr.initialize(repeating: 0, count: count)
        }
    }
    
    /// - Parameter length: Desired data length
    /// - Returns: Random data
    public static func random(length: Int) -> Data {
        var data = Data(repeating: 0, count: length)
        var success = false
        #if !os(Linux)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0)
        }
        success = result == errSecSuccess
        #endif
        guard !success else { return data }
        data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt32>) in
            for i in 0..<length/4+1 {
                #if canImport(Darwin)
                bytes[i] = arc4random()
                #else
                bytes[i] = UInt32(bitPattern: rand())
                #endif
            }
        }
        return data
    }
    /// - Returns: Hex representation of data
    public var reversedHex: String {
        var string = ""
        withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            for i in (0..<count).reversed() {
                string += bytes[i].hex
            }
        }
        return string
    }
    
    /// - Returns: Data if string is in hex format
    /// Format: "0x0ba98fc797cfab9864bfac988fa", "0ba98fc797cfab9864bfac988fa"
    public static func fromHex(_ hex: String) -> Data? {
        return try? hex.hexToData()
    }
    
    /// - Returns: String (if its utf8 convertible) or hex string
    public var string: String {
        return String(data: self, encoding: .utf8) ?? hex
    }
    
    
    /// - Returns: Number bits
    /// - Important: Returns max of 8 bytes for simplicity
    public func bitsInRange(_ startingBit: Int, _ length: Int) -> UInt64 {
        let bytes = self[(startingBit / 8) ..< (startingBit + length + 7) / 8]
        let padding = Data(repeating: 0, count: 8 - bytes.count)
        let padded = bytes + padding
        var uintRepresentation = UInt64(bigEndian: padded.withUnsafeBytes { $0.pointee })
        uintRepresentation <<= startingBit % 8
        uintRepresentation >>= UInt64(64 - length)
        return uintRepresentation
    }
}

extension UInt8 {
    /// - Returns: Byte as hex string (from "00" to "ff")
    public var hex: String {
        if self < 0x10 {
            return "0" + String(self, radix: 16)
        } else {
            return String(self, radix: 16)
        }
    }
}
