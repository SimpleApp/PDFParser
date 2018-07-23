//
//  PDFFontFile.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 09/07/2018.
//

import Foundation
import CoreGraphics


protocol PDFFontFile {
    func glyphName(forChar originalCharCode:PDFCharacterCode) -> String?
    func glyphWidthInThousandthOfEM(forChar char:unichar, originalCharCode oChar: PDFCharacterCode) -> CGFloat?
}


