//
//  IBAN.swift
//  web3swift
//
//  Created by Alexander Vlasov on 25.05.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import BigInt
import Foundation

public struct ICAP {
    public var asset: String
    public var institution: String
    public var client: String
}

public struct IBAN {
    public var iban: String

    public var isDirect: Bool {
        return iban.count == 34 || iban.count == 35
    }

    public var isIndirect: Bool {
        return iban.count == 20
    }

    public var checksum: String {
        return iban[2 ..< 4]
    }

    public var asset: String {
        if isIndirect {
            return iban[4 ..< 7]
        } else {
            return ""
        }
    }

    public var institution: String {
        if isIndirect {
            return iban[7 ..< 11]
        } else {
            return ""
        }
    }

    public var client: String {
        if isIndirect {
            return iban[11...]
        } else {
            return ""
        }
    }

    public func toEthereumAddress() -> EthereumAddress? {
        if isDirect {
            let base36 = iban[4...]
            guard let asBigNumber = BigUInt(base36, radix: 36) else { return nil }
            let addressString = String(asBigNumber, radix: 16).leftPadding(toLength: 40, withPad: "0")
            return EthereumAddress(addressString.withHex)
        } else {
            return nil
        }
    }

    internal static func decodeToInts(_ iban: String) -> String {
//        let codePointForA = "A".asciiValue
//        let codePointForZ = "Z".asciiValue

        let uppercasedIBAN = iban.replacingOccurrences(of: " ", with: "").uppercased()
        let begining = String(uppercasedIBAN[0 ..< 4])
        let end = String(uppercasedIBAN[4...])
        let IBAN = end + begining
        var arrayOfInts = [Int]()
        for ch in IBAN {
            guard let dataPoint = String(ch).data(using: .ascii) else { return "" }
            guard dataPoint.count == 1 else { return "" }
            let code = Int(dataPoint[0])
            if code >= 65 && code <= 90 {
                arrayOfInts.append(code - 65 + 10)
            } else {
                arrayOfInts.append(code - 48)
            }
        }
        let joinedString = arrayOfInts.map({ (intCh) -> String in
            String(intCh)
        }).joined()
        return joinedString
    }

    internal static func calculateChecksumMod97(_ preparedString: String) -> Int {
        var m = 0
        for digit in preparedString.split(intoChunksOf: 1) {
            m = m * 10
            m = m + Int(digit)!
            m = m % 97
        }
        return m
    }

    public static func isValidIBANaddress(_ iban: String, noValidityCheck: Bool = false) -> Bool {
        let regex = "^XE[0-9]{2}(ETH[0-9A-Z]{13}|[0-9A-Z]{30,31})$"
        let matcher = try! NSRegularExpression(pattern: regex, options: NSRegularExpression.Options.dotMatchesLineSeparators)
        let match = matcher.matches(in: iban, options: NSRegularExpression.MatchingOptions.anchored, range: iban.fullNSRange)
        guard match.count == 1 else {
            return false
        }
        if iban.hasPrefix("XE") && !noValidityCheck {
            let remainder = calculateChecksumMod97(decodeToInts(iban))
            return remainder == 1
        } else {
            return true
        }
    }

    public init?(_ ibanString: String) {
        let matched = ibanString.replacingOccurrences(of: " ", with: "").uppercased()
        guard IBAN.isValidIBANaddress(matched) else { return nil }
        iban = matched
    }
    public static func check(_ address: EthereumAddress) -> Bool {
        return address.addressData.base36.count <= 30
    }
    public init(_ address: EthereumAddress) {
        let padded = address.addressData.base36.leftPadding(toLength: 30, withPad: "0")
        let prefix = "XE"
        let remainder = IBAN.calculateChecksumMod97(IBAN.decodeToInts(prefix + "00" + padded))
        let checkDigits = "0" + String(98 - remainder)
        let twoDigits = checkDigits[checkDigits.count - 2 ..< checkDigits.count]
        let fullIban = prefix + twoDigits + padded
        iban = fullIban.uppercased()
    }
}

private extension Data {
    var base36: String {
        let bigNumber = BigUInt(self)
        return String(bigNumber, radix: 36)
    }
}
