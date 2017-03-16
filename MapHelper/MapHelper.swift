//
//  MapHelper.swift
//  ObjectMapHelper
//
//  Created by is0bnd on 2017/3/15.
//  Copyright © 2017年 is0bnd. All rights reserved.
//

import Foundation
import XcodeKit



enum ModelType {
    case classModel, structModel
}

extension String {
    
    var prepared: String? {
        let line = trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? nil : line
    }
    
    var containsOnlyLettersAndDigits: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
    
}


typealias Map = (key: String, value: String)



class MappableModel {
    /// 所有map函数的Range
    var mapRange: XCSourceTextRange?
    /// 最后一个属性的Index
    var lastPropertyIndex = 0
    /// 选中的最后下标
    var lastIndex = 0
    /// 模型类别
    var type: ModelType?
    /// 属性列表
    var propertys = [String]()
    /// Map键值列表
    var maps = [Map]()
    /// 拥有遵守Mappable协议的父类
    var hasSuperMappabled = false
}

class MapHelper {
    
    /// 处理回调
    static func hanlder(_ invocation: XCSourceEditorCommandInvocation) {
        guard invocation.buffer.contentUTI == "public.swift-source" else { return }
        guard let lineIndex = lastSelectedLine(fromBuffer: invocation.buffer) else { return }
        let model = extractModel(from: invocation.buffer)
        model.lastIndex = lineIndex
        if lineIndex <= model.lastPropertyIndex { return }
        if model.type == nil { return }
        if model.propertys.count == 0 { return }
        let str = generateMapFunc(from: model, tabWidth: invocation.buffer.tabWidth)
        let removeRange = NSMakeRange(model.lastPropertyIndex + 1, model.lastIndex - model.lastPropertyIndex)
        invocation.buffer.lines.removeObjects(in: removeRange)
        invocation.buffer.lines.insert(str, at: model.lastPropertyIndex + 1)
        
        // select the inserted code
        let startIndex = model.lastPropertyIndex + 2
        let endIndex = startIndex + (model.hasSuperMappabled ? 7 : 5) + model.propertys.count
        let start = XCSourceTextPosition(line: startIndex, column: 0)
        let end = XCSourceTextPosition(line: endIndex, column: 0)
        invocation.buffer.selections.setArray([XCSourceTextRange(start: start, end: end)])
        
    }
    
    
    /// 获取所有选中行的index
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
    
    
    
}

//MARK: - 提取Mappable Model
extension MapHelper {
    fileprivate static func extractModel(from buffer: XCSourceTextBuffer) -> MappableModel {
        let model = MappableModel()
        let indexs = getSelectedLinesIndexes(fromBuffer: buffer)
        for index in indexs {
            guard let aline = buffer.lines[index] as? String else { preconditionFailure() }
            guard let line = aline.prepared else { continue }
            if line.hasPrefix("class") || line.hasPrefix("struct") {
                model.type = extractModelType(from: line)
            }else if line.hasPrefix("var") {
                let propertys = getPropertys(from: line)
                model.propertys.append(contentsOf: propertys)
                model.lastPropertyIndex = propertys.count > 0 ? index : model.lastPropertyIndex
            }else if line.contains("<-") {
                guard let map = getMap(from: line) else { continue }
                model.maps.append(map)
            }else if line.contains("super.mapping(map: map)") || line.contains("super.init(map: map)") {
                model.hasSuperMappabled = true
            }
        }
        return model
    }
    
}

//MARK: - 提取类型
extension MapHelper {
    /// 从类型字符串提取类别
    fileprivate static func extractModelType(from line: String) -> ModelType? {
        if line.contains("class") {
            return.classModel
        }else if line.contains("struct") {
            return.structModel
        }
        return nil
    }
    
    /// 从属性字符串提取属性
    fileprivate static func getPropertys(from line: String) -> [String] {
        /// 去除var
        let index = line.index(line.startIndex, offsetBy: "var".characters.count)
        let dropProperty = line.substring(from: index)
        /// 以逗号分隔获取所有属性
        let propertys = dropProperty.components(separatedBy: ",").map {
            /// 获取属性名
            prepareProperty($0)
        }
        
        /// 去除空格
        let cleanPropertys = propertys.map { $0.trimmingCharacters(in: .whitespaces) }
        return cleanPropertys.filter{
            $0.containsOnlyLettersAndDigits
        }
        
    }
    
    /// 处理属性
    fileprivate static func prepareProperty(_ text: String) -> String {
        let beforeEquality = text.components(separatedBy: "=")[0] // in case of a raw value
        let beforeBracket = beforeEquality.components(separatedBy: ":")[0] // in case of an associated value
        let beforeComments = beforeBracket.components(separatedBy: "//")[0] // in case of comments
        return beforeComments
    }
    
    /// 从map函数字符串提取键值关系
    static func getMap(from str: String) -> Map? {
        let strings = str.components(separatedBy: "<-")
        if strings.first ?? "" == "" || strings.last ?? "" == "" {
            return nil
        }
        let key = strings.first!.trimmingCharacters(in: .whitespaces)
        let valueComponents = strings.last!.components(separatedBy: "\"")
        if valueComponents.count != 3 {
            return nil
        }
        let value = valueComponents[1]
        if key == "" || value == "" {
            return nil
        }
        return (key, value)
    }


}




extension MapHelper {
    
    fileprivate static func lastSelectedLine(fromBuffer buffer: XCSourceTextBuffer) -> Int? {
        return (buffer.selections.lastObject as? XCSourceTextRange)?.end.line
    }
    
    fileprivate static func generateMapFunc(from model: MappableModel, tabWidth: Int) -> String {
        
        let indent = String(repeating: " ", count: tabWidth)
        let doubleIndent = indent + indent
        let superInitFuncStr = doubleIndent + "super.init(map: map)\n"
        let superMappingFuncStr = doubleIndent + "super.mapping(map: map)\n"
        let endStr = "}\n\n"
        let overrideStr = "override "
        
        let requiredInitWithMapFuncStr = "required init?(map: Map) {\n"
        let normalInitWithMapFuncStr = "init?(map: Map) {\n"
        var initWithMapFuncStr = model.type == .classModel ? requiredInitWithMapFuncStr : normalInitWithMapFuncStr
        
        
        let normalMappingFuncStr = "func mapping(map: Map) {\n"
        let mutatingMappingFuncStr = "mutating func mapping(map: Map) {\n"
        var mappingFuncStr = model.type == .classModel ? normalMappingFuncStr : mutatingMappingFuncStr
        
        
        if model.hasSuperMappabled {
            initWithMapFuncStr = indent + initWithMapFuncStr + superInitFuncStr + indent + endStr
            mappingFuncStr = indent + overrideStr + mappingFuncStr + superMappingFuncStr
        }else {
            initWithMapFuncStr = indent + initWithMapFuncStr + indent + endStr
            mappingFuncStr = indent + mappingFuncStr
        }
        
        let mapStr = model.propertys.map {
            guard model.maps.count > 0 else { return "\(doubleIndent)\($0) <- map[\"\($0)\"]\n" }
            for map in model.maps {
                if map.key == $0 {
                    return "\(doubleIndent)\($0) <- map[\"\(map.value)\"]\n"
                }
            }
            return "\(doubleIndent)\($0) <- map[\"\($0)\"]\n"
            }.joined()
        
        return "\n" + initWithMapFuncStr + mappingFuncStr + mapStr + indent + endStr + endStr
    }
}
