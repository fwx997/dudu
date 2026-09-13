//
//  UTType+EPUB.swift
//  Legado-iOS
//
//  UTType 扩展 - EPUB 文件类型支持
//

import UniformTypeIdentifiers

extension UTType {
    /// EPUB 文件类型
    static var epub: UTType {
        UTType(importedAs: "org.idpf.epub-container")
    }
    
    /// JSON 书源文件类型
    static var jsonSource: UTType {
        UTType(importedAs: "public.json")
    }
}