//
//  ViewController.swift
//  ObjectMapHelper
//
//  Created by is0bnd on 2017/3/14.
//  Copyright © 2017年 is0bnd. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var alertLabel: NSTextField!
    @IBOutlet weak var label: NSTextFieldCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        label.title = "This guy is too lazy\nThere's nothing here, and you can close it now"
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

