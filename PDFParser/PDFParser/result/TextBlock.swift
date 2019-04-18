//
//  TextBlock.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.

import UIKit


public struct TextBlock {
    public var chars: String
    public var characterIds:[PDFFontFile.CharacterId]
    public var renderingState: PDFRenderingState
    public var frame: CGRect
    public var attributes: TextAtttributes

    public init(chars: String, characterIds:[PDFFontFile.CharacterId],renderingState: PDFRenderingState, frame: CGRect) {
        self.chars = chars
        self.characterIds = characterIds
        self.renderingState = renderingState
        self.frame = frame
        self.attributes = TextAtttributes(rendering: renderingState)
    }
}
