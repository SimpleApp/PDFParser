//
//  PDFType0Font.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation
import CoreGraphics

class PDFType0Font : PDFFont {

    enum CIDPredefinedCMap: String {
        case identityH = "Identity-H"
        case identityV = "Identity-V"
        case unsupported = ""
    }

    var descendantFont: PDFCIDFont?

    var cidPredefinedCMap: CIDPredefinedCMap?

    //Different format than Type1 font.

    override init?(pdfDictionary: CGPDFDictionaryRef?) {
        super.init(pdfDictionary: pdfDictionary)
        //Type0Font
        guard let pdfDictionary = pdfDictionary else { return }
        parseDescendantFonts(fontDictionary: pdfDictionary)
    }


    //MARK: - Parsing

    func parseDescendantFonts(fontDictionary: CGPDFDictionaryRef) {
        var descendantFontsArrayRef: CGPDFArrayRef? = nil
        guard CGPDFDictionaryGetArray(fontDictionary, "DescendantFonts", &descendantFontsArrayRef) else { return }
        guard let descendantFontsArray = descendantFontsArrayRef else { return }
        var descendantFontDicRef: CGPDFDictionaryRef? = nil
        guard CGPDFArrayGetDictionary(descendantFontsArray, 0, &descendantFontDicRef) else { return }
        guard let descendantFontDic = descendantFontDicRef else { return }
        descendantFont = Parser.getFont(descendantFontDic) as? PDFCIDFont
    }

    //This is called by the PDFFont parseEncoding function.
    //In the case of Type0 fonts, \Encoding has a different meaning.
    override func setEncoding(name: String?) {
        self.cidPredefinedCMap = CIDPredefinedCMap(rawValue: name ?? "") ?? .unsupported
    }

    override func pdfStringToCharacterIds(_ pdfString: CGPDFStringRef) -> [PDFFontFile.CharacterId] {
        let charCount = CGPDFStringGetLength(pdfString)
        guard let charCodes = CGPDFStringGetBytePtr(pdfString),
            charCount > 0 else { return [] }

        let originalCharCodes = Data(bytes: charCodes, count: charCount)
        let unicharArray = originalCharCodes.withUnsafeBytes { (body:UnsafePointer<UInt16>) -> [UInt16] in
            var res = [UInt16]()
            for i in 0..<Int(charCount/2) {
                let val = body.advanced(by: i).pointee
                res.append(currentSystemIsLittleEndian ? val.byteSwapped : val)
            }
            return res
        }
        return unicharArray.map{ PDFFontFile.CharacterId($0)}
    }

    override func characterIdToUnicode(_ char: PDFFontFile.CharacterId) -> Unicode.Scalar? {
        //we don't handle other methods of unicode lookup.
        return self.toUnicodeCharMapLookup(char)
    }

    override func displacementInGlyphSpace(forChar char: PDFFontFile.CharacterId) -> CGPoint {
        return self.descendantFont?.displacementInGlyphSpace(forChar: char) ?? .zero
    }
}
