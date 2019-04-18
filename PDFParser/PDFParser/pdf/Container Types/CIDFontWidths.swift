//
//  CIDFontWidths.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 17/04/2019.
//  Copyright © 2019 SimpleApp. All rights reserved.
//

import Foundation
import CoreGraphics

public class CIDFontWidths {


    //Character widths are stored in a "decompressed" way for faster lookup.
    var characterWidths: [PDFFontFile.CharacterId: CGFloat] = [:]

    func width(forChar char: PDFFontFile.CharacterId) -> CGFloat? {
        return characterWidths[char]
    }

    init() { }
    convenience init(pdfArray: CGPDFArrayRef) {
        self.init()
        let len = CGPDFArrayGetCount(pdfArray)

        //parsing is done by group of two or three values.
        //the first value is always a number
        //the second value can be an array or a number. if it's an array, there's no third value.
        //the third value is a number
        var stack = [PDFFontFile.CharacterId]()
        for i in 0..<len {
            switch stack.count {
            case 0:
                var value: Int = 0
                if CGPDFArrayGetInteger(pdfArray, i, &value) {
                    stack.append(i)
                }
            case 1:
                //try to parse an array
                var arrayRef: CGPDFArrayRef? = nil
                if CGPDFArrayGetArray(pdfArray, i, &arrayRef),
                    let array = arrayRef {
                    //first format. array is an array of width for consecutive characters.
                    let widths = CIDFontWidths.parseNumberArray(array)
                    for (i,w) in widths.enumerated() {
                        characterWidths[stack[0] + i] = w
                    }
                    stack.removeAll()
                } else {
                    //parse a number. we're in the second format
                    var value: Int = 0
                    if CGPDFArrayGetInteger(pdfArray, i, &value) {
                        stack.append(i)
                    }
                }
            default: //stack size should never be above 2 anyway
                //We have two values in the stack. we're in the second format.
                //first two values are a range of characters with the same width.
                var value: CGPDFReal = 0.0
                if CGPDFArrayGetNumber(pdfArray, i, &value){
                    for cid in stack[0]...stack[1] {
                        characterWidths[cid] = value
                    }
                }
                //in any case, drop the stack
                stack.removeAll()
            }
        }
    }

    static func parseNumberArray(_ array: CGPDFArrayRef) -> [CGFloat] {
        var res = [CGFloat]()
        let arrayCount = CGPDFArrayGetCount(array)
        for i in 0..<arrayCount {
            var value: CGPDFReal = 0.0
            if CGPDFArrayGetNumber(array, i, &value){
                res.append(value)
            }
        }

        return res
    }
}
