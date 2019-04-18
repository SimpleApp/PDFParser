//
//  PDFTrueTypeFont.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation

class PDFTrueTypeFont : PDFSimpleFont {

    //TrueType fonts directly map throught their internal CMAP table
    override func characterIdToUnicode(_ char: PDFFontFile.CharacterId) -> Unicode.Scalar? {
        if let toUnicodeChar = toUnicodeCharMapLookup(char) {
            return toUnicodeChar
        }
        return encodingConvertCharacter([UInt8(char)]) ??  descriptor.fontFile?.unicodeScalar(forChar: char)
    }

}
