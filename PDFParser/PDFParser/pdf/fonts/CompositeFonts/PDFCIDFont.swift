//
//  PDFCIDFont.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation
import CoreGraphics

class PDFCIDFont : PDFFont {
    var identity: Bool = true
    var cidGidMap: Data? = nil
    var cidWidths: [unichar: CGFloat] = [:]
    var cidDefaultWidth: CGFloat?

    var w: CIDFontWidths? = nil
    var dw: CGFloat = 1000 // in user units

    override init?(pdfDictionary: CGPDFDictionaryRef?) {
        super.init(pdfDictionary: pdfDictionary)
        //Type0Font
        guard let pdfDictionary = pdfDictionary else { return }
        parseDW(fontDictionary: pdfDictionary)
        parseW(fontDictionary: pdfDictionary)
    }

    //MARK: - Parsing
    func parseDW(fontDictionary: CGPDFDictionaryRef) {
        var number: CGPDFReal = 0.0
        if CGPDFDictionaryGetNumber(fontDictionary, "DW", &number) {
            self.dw = number
        }
    }

    func parseW(fontDictionary: CGPDFDictionaryRef) {
        var arrayNil: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(fontDictionary, "W", &arrayNil),
            let array = arrayNil else { return }
        self.w = CIDFontWidths(pdfArray: array)
    }
    override func string(from pdfString: CGPDFStringRef) -> (str:String, characterIds:[PDFFontFile.CharacterId]) {
        assertionFailure("should not access CIDFont string conversion method directly.")
        return super.string(from: pdfString)
    }

    override func displacementInGlyphSpace(forChar char: Int) -> CGPoint {
        return CGPoint(x: width(forCharacter: char), y: 0)
    }
    func width(forCharacter char: PDFFontFile.CharacterId) -> CGFloat {
        return w?.width(forChar: char) ?? dw
    }
}
