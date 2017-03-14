//
//  SourceEditorCommand.swift
//  MapHelper
//
//  Created by is0bnd on 2017/3/14.
//  Copyright © 2017年 is0bnd. All rights reserved.
//

import Foundation
import XcodeKit

extension String {
    
    var prepared: String? {
        let line = trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? nil : line
    }
    
    var containsOnlyLettersAndDigits: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
}

fileprivate class PropertyExtractor {
    fileprivate static func getSelectedLinesIndexes(fromBuffer buffer: XCSourceTextBuffer) -> [Int] {
        var result: [Int] = []
        for range in buffer.selections {
            guard let range = range as? XCSourceTextRange else { preconditionFailure() }
            for lineNumber in range.start.line...range.end.line {
                result.append(lineNumber)
            }
        }
        return result
    }
    
    fileprivate static func prepareProperty(_ text: String) -> String {
        let beforeEquality = text.components(separatedBy: "=")[0] // in case of a raw value
        let beforeBracket = beforeEquality.components(separatedBy: ":")[0] // in case of an associated value
        let beforeComments = beforeBracket.components(separatedBy: "//")[0] // in case of comments
        return beforeComments
    }
    
    static func extractPropertys(fromBuffer buffer: XCSourceTextBuffer) -> [String] {
        var result: [String] = []
        let indexs = getSelectedLinesIndexes(fromBuffer: buffer)
        for index in indexs {
            guard let aline = buffer.lines[index] as? String else { preconditionFailure() }
            guard let line = aline.prepared else { continue }
            let varStr = "var"
            if line.hasPrefix(varStr) {
                /// 去除var
                let index = line.index(line.startIndex, offsetBy: varStr.characters.count)
                let dropProperty = line.substring(from: index)
                /// 以逗号分隔获取所有属性
                let propertys = dropProperty.components(separatedBy: ",").map {
                    /// 获取属性名
                    prepareProperty($0)
                }
                
                /// 去除空格
                let cleanCases = propertys.map { $0.trimmingCharacters(in: .whitespaces) }
                /// 填充数组
                result.append(contentsOf: cleanCases.filter { $0.containsOnlyLettersAndDigits })
            }
        }
        return result
    }

    
}


class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    enum ModelType {
        case classModel, structModel
    }
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
        defer { completionHandler(nil) }
        test(invocation: invocation)
        completionHandler(nil)
    }
    
    func test(invocation: XCSourceEditorCommandInvocation) {
         // error looks ugly, just do nothing in case of an error
        
        guard invocation.buffer.contentUTI == "public.swift-source" else { return }
        guard let lineIndex = lastSelectedLine(fromBuffer: invocation.buffer) else { return }
        let propertys = PropertyExtractor.extractPropertys(fromBuffer: invocation.buffer)
        
        guard propertys.count > 0 else { return }
        
        let str = generateMap(from: propertys, tabWidth: invocation.buffer.tabWidth)
        invocation.buffer.lines.insert(str, at: lineIndex + 2)
        
        // select the inserted code
        let start = XCSourceTextPosition(line: lineIndex + 2, column: 0)
        let end = XCSourceTextPosition(line: lineIndex + propertys.count + 2, column: 0)
        invocation.buffer.selections.setArray([XCSourceTextRange(start: start, end: end)])

    }
    
    private func lastSelectedLine(fromBuffer buffer: XCSourceTextBuffer) -> Int? {
        return (buffer.selections.lastObject as? XCSourceTextRange)?.end.line
    }
    
    private func generateMap(from propertys: [String], tabWidth: Int) -> String {
        let indent = String(repeating: " ", count: tabWidth)
        let mapStr = propertys.map { "\(indent)\($0) <- map[\"\($0)\"]\n"}.joined()
        return mapStr
    }
    
    
    
}
