//
//  PDFType1Font.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation

class PDFType1Font : PDFSimpleFont {


    //Type 1 fonts find unicodes through glyphnames then Adobe glyph list reference table
    override func characterIdToUnicode(_ char: PDFFontFile.CharacterId) -> Unicode.Scalar? {
        return toUnicodeCharMapLookup(char) ?? encodingConvertCharacter([UInt8(char)]) ?? self.fontFileCharMapLookup(char)
    }

    override func guessSpaceCharacterId() {
        guard let type1FontFile = self.descriptor.fontFile as? PDFType1FontFile else {
            super.guessSpaceCharacterId()
            return
        }
        self.spaceCharId = type1FontFile.char(forGlyphname: "/space")
    }

}
