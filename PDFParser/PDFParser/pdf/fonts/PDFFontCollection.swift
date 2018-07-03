//
//  PDFFontCollection.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 05/07/2018.
//

import Foundation
import CoreGraphics

class PDFFontCollection {
    var fonts = [String:PDFFont]() {
        didSet {
            names = fonts.keys.sorted()
        }
    }
    private(set) var names = [String]()

    init() {

    }

}
