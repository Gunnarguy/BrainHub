//  Parsers.swift
//  BrainHub
//  Unified parsing layer for many document types (extensible).
//  Each parser returns normalized UTF-8 text + lightweight metadata.

import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

struct ParsedDocument {
    let title: String
    let text: String
    let meta: [String: Any]
}

protocol DocumentParser {
    /// Return nil if parser does not handle the input.
    func parse(url: URL) throws -> ParsedDocument?
    func parse(data: Data, suggestedName: String) throws -> ParsedDocument?
}

// MARK: - Plain Text / UTF-8
struct PlainTextParser: DocumentParser {
    func parse(url: URL) throws -> ParsedDocument? {
        let exts = ["txt","md","markdown","csv","log","json","yaml","yml"]
        guard exts.contains(url.pathExtension.lowercased()) else { return nil }
        let s = try String(contentsOf: url, encoding: .utf8)
        return ParsedDocument(title: url.deletingPathExtension().lastPathComponent, text: s, meta: ["ext": url.pathExtension.lowercased()])
    }
    func parse(data: Data, suggestedName: String) throws -> ParsedDocument? {
        guard let s = String(data: data, encoding: .utf8) else { return nil }
        return ParsedDocument(title: suggestedName, text: s, meta: ["inferred": true])
    }
}

// MARK: - PDF
struct PDFTextParser: DocumentParser {
    func parse(url: URL) throws -> ParsedDocument? {
        guard url.pathExtension.lowercased() == "pdf" else { return nil }
        #if canImport(PDFKit)
        guard let doc = PDFDocument(url: url) else { return nil }
        var agg = ""; for i in 0..<doc.pageCount { if let p = doc.page(at: i), let t = p.string { agg += t + "\n" } }
        return ParsedDocument(title: url.deletingPathExtension().lastPathComponent, text: agg, meta: ["pages": doc.pageCount])
        #else
        return nil
        #endif
    }
    func parse(data: Data, suggestedName: String) throws -> ParsedDocument? { nil }
}

// MARK: - Fallback Heuristic (attempt UTF-8 decode)
struct FallbackUTF8Parser: DocumentParser {
    func parse(url: URL) throws -> ParsedDocument? {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return ParsedDocument(title: url.deletingPathExtension().lastPathComponent, text: s, meta: ["ext": url.pathExtension.lowercased(), "fallback": true])
    }
    func parse(data: Data, suggestedName: String) throws -> ParsedDocument? {
        guard let s = String(data: data, encoding: .utf8) else { return nil }
        return ParsedDocument(title: suggestedName, text: s, meta: ["fallback": true])
    }
}

// Registry
struct ParserRegistry {
    private let parsers: [DocumentParser] = [PlainTextParser(), PDFTextParser(), FallbackUTF8Parser()]
    func parse(url: URL) throws -> ParsedDocument? {
        for p in parsers { if let r = try p.parse(url: url) { return r } }
        return nil
    }
    func parse(data: Data, suggestedName: String) throws -> ParsedDocument? {
        for p in parsers { if let r = try p.parse(data: data, suggestedName: suggestedName) { return r } }
        return nil
    }
}
