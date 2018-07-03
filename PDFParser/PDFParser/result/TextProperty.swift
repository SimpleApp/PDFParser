//
//  TextProperty.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.

import Foundation
import UIKit

public enum TextProperty {
    case fontName(name: String)
    case fontSize(size: Float)
    case backgroundColor(color: UIColor)

    public func isSamePropertyAs (_ tp: TextProperty) -> Bool {
        switch (self,tp) {
        case (.fontName(_), .fontName(_)),
             (.fontSize(_), .fontSize(_)),
             (.backgroundColor(_), .backgroundColor(_)):
            return true
        default:
            return false
        }
    }
}
