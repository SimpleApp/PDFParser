//
//  Differences.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 11/06/2019.
//  Copyright © 2019 SimpleApp. All rights reserved.
//

import CoreGraphics

class Differences {

    var charDifferences:[PDFFontFile.CharacterId: String] = [:]
    var charUnicodes : [PDFFontFile.CharacterId: UnicodeScalar] = [:]

    convenience init(arrayRef: CGPDFArrayRef) {
        self.init()
        charDifferences = [:]
        charUnicodes = [:]
        let arrayCount = CGPDFArrayGetCount(arrayRef)
        var baseChar: PDFFontFile.CharacterId = 0
        var baseCharIndex:Int = 0
        var charPDFInt: CGPDFInteger = 0
        var charPDFNameRef: UnsafePointer<Int8>? = nil
        for i in 0..<arrayCount {
            if CGPDFArrayGetName(arrayRef, i, &charPDFNameRef),
                let charPDFName = charPDFNameRef {
                charDifferences[baseChar+(i-baseCharIndex) - 1] = String(cString: charPDFName)
            } else if CGPDFArrayGetInteger(arrayRef, i, &charPDFInt) {
                baseChar = charPDFInt
                baseCharIndex = i
            }
        }
        charUnicodes = charDifferences.compactMapValues({
            if let unic = PDFAGL.unicodeForGlyphName[$0] {
                return Unicode.Scalar(unic)
            }
            return nil
        })
        print("charUnicodes: \(charUnicodes)")
    }
    func characterIdToUnicode(_ char: PDFFontFile.CharacterId) -> UnicodeScalar? {
        return charUnicodes[char]
    }
}
