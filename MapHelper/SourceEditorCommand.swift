//
//  SourceEditorCommand.swift
//  MapHelper
//
//  Created by is0bnd on 2017/3/14.
//  Copyright © 2017年 is0bnd. All rights reserved.
//

import Foundation
import XcodeKit


class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        defer { completionHandler(nil) }
        MapHelper.hanlder(invocation)
        completionHandler(nil)
    }
    
    
}


