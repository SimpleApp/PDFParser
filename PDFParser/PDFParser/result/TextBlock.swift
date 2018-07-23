//
//  TextBlock.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.

import UIKit


public struct TextBlock {
    var chars: String
    var originalCharCodes:[PDFCharacterCode]
    var renderingState: PDFRenderingState
    var frame: CGRect
}
