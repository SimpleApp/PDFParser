//
//  PDFSimpleFont.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation
import CoreGraphics

class PDFSimpleFont : PDFFont {

    override init?(pdfDictionary: CGPDFDictionaryRef?) {
        super.init(pdfDictionary: pdfDictionary)
        setEncoding(fontDictionary: pdfDictionary)
    }

    override func setWidths(fontDictionary dict: CGPDFDictionaryRef) {
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
                widths[PDFCharacterCode(firstChar+i)] = width
        }
    }
}
