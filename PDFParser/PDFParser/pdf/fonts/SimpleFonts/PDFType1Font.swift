//
//  PDFType1Font.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation

class PDFType1Font : PDFSimpleFont {


    //Type 1 fonts find unicodes through glyphnames then Adobe glyph list reference table
    //We fallback on isoLatin1 encoding if no encoding is provided.
    override func characterIdToUnicode(_ char: PDFFontFile.CharacterId) -> Unicode.Scalar? {
        let res = toUnicodeCharMapLookup(char) ?? differences.characterIdToUnicode(char) ?? encodingConvertCharacter([UInt8(char)]) ??  self.fontFileCharMapLookup(char) ?? String(bytes: [UInt8(char)], encoding: .isoLatin1)?.unicodeScalars.first

        //TODO: fallback to isoLatin1 is probably wrong. Try to look somewhere for the proper encoding.
        return res
    }

    override func guessSpaceCharacterId() {
        super.guessSpaceCharacterId()
        if spaceCharId == nil {
            if let differencedReversedLookup = self.differences.charUnicodes.first(where: {
                $0.value == Unicode.Scalar(0x0020)
            })?.key {
                self.spaceCharId = differencedReversedLookup
            }
            else {
                //TODO: fallbak to isoLatin1 is probably wrong. Try to look somewhere for the proper encoding.
                self.spaceCharId = 0x0020
            }
        }
    }

}
