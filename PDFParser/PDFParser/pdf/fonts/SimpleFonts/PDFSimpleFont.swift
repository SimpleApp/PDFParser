//
//  PDFSimpleFont.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation
import CoreGraphics

class PDFSimpleFont : PDFFont {

    var widthsRange = NSMakeRange(0, 0)
    var widths = [PDFFontFile.CharacterId:CGFloat]()
    let fallbackGlyphWidth: CGFloat = 1000 // fallback for standard14 fonts with no font descriptor info.

    override init?(pdfDictionary: CGPDFDictionaryRef?) {
        super.init(pdfDictionary: pdfDictionary)
        guard let pdfDictionary = pdfDictionary else { return }
        parseWidths(fontDictionary: pdfDictionary)
    }

    func parseWidths(fontDictionary dict: CGPDFDictionaryRef) {
        var arrayNil: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Widths", &arrayNil),
            let array = arrayNil else { return }
        let count = CGPDFArrayGetCount(array)
        var firstChar: CGPDFInteger = 0, lastChar: CGPDFInteger = 0
        guard
            CGPDFDictionaryGetInteger(dict, "FirstChar", &firstChar),
            CGPDFDictionaryGetInteger(dict, "LastChar", &lastChar) else { return }

        widthsRange = NSMakeRange(firstChar, lastChar-firstChar)
        for i in 0 ..< count {
            var width: CGPDFReal = 0.0
            guard CGPDFArrayGetNumber(array, i, &width) else { continue }
            widths[firstChar+i] = width
        }
    }

    override func displacementInGlyphSpace(forChar char: PDFFontFile.CharacterId) -> CGPoint {
        let dx = self.widths[char] ?? (self.descriptor.missingWidth > 0 ? descriptor.missingWidth : descriptor.fontFile?.glyphWidthInThousandthOfEM(forChar: char) ?? fallbackGlyphWidth)
        return CGPoint(x: dx, y: 0)
    }

    //Simple fonts don't have the notion of CIDs. We're just returning the original array of UInt8
    override func pdfStringToCharacterIds(_ pdfString:CGPDFStringRef) -> [PDFFontFile.CharacterId] {
        guard let characterCodes = CGPDFStringGetBytePtr(pdfString) else {
            return []
        }
        let characterCodeCount = CGPDFStringGetLength(pdfString)
        return Data(bytes: characterCodes, count: characterCodeCount).map{ Int($0) }
    }

    func encodingConvertCharacter(_ bytes: [UInt8]) -> Unicode.Scalar? {
        guard let encoding = self.encoding, encoding != .unknown else { return nil }
        return String(bytes: bytes, encoding: encoding.toNative())?.unicodeScalars.first
    }


 
}
