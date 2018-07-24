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
    lazy var attributes: TextAtttributes = {
        return TextAtttributes(rendering: renderingState)
    }()

    init(chars: String, originalCharCodes:[PDFCharacterCode],renderingState: PDFRenderingState, frame: CGRect) {
        self.chars = chars
        self.originalCharCodes = originalCharCodes
        self.renderingState = renderingState
        self.frame = frame
    }
}
