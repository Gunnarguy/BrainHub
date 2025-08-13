//  HashUtil.swift
//  BrainHub
//  Provides stable content hashing for deduplication.

import Foundation
import CryptoKit

enum HashUtil {
    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    static func sha256Hex(_ string: String) -> String { sha256Hex(Data(string.utf8)) }
}
