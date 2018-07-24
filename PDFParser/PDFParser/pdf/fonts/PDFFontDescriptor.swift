//
//  PDFFontDescriptor.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 09/07/2018.
//

import Foundation
import CoreGraphics

struct PDFFontDescriptor {
    var descent: CGFloat = 0
    var ascent: CGFloat = 0
    var leading: CGFloat = 0
    var capHeight: CGFloat = 0
    var xHeight: CGFloat = 0
    var averageWidth: CGFloat = 0
    var maxWidth: CGFloat = 0
    var missingWidth: CGFloat = 0
    var verticalStemWidth: CGFloat = 0
    var horizontalStemHeigth: CGFloat = 0
    var italicAngle: CGFloat = 0
    var bounds: CGRect = .zero
    var flags: PDFFont.Flag = []
    var fontName: String = ""
    var fontFile: PDFFontFile? = nil

    init() {
    }

    init(pdfDictionary dict: CGPDFDictionaryRef) {
        var fontType : UnsafePointer<Int8>? = nil
        guard
            CGPDFDictionaryGetName(dict, "Type", &fontType),
            let fontTypeNonNil = fontType,
            String.decodePDFInt8CString(fontTypeNonNil) == "FontDescriptor" else { return }

        CGPDFDictionaryGetNumber(dict, "Ascent",        &self.ascent)
        CGPDFDictionaryGetNumber(dict, "Descent",       &self.descent)
        CGPDFDictionaryGetNumber(dict, "Leading",       &self.leading)
        CGPDFDictionaryGetNumber(dict, "CapHeight",     &self.capHeight)
        CGPDFDictionaryGetNumber(dict, "XHeight",       &self.xHeight)
        CGPDFDictionaryGetNumber(dict, "AvgWidth",      &self.averageWidth)
        CGPDFDictionaryGetNumber(dict, "MaxWidth",      &self.maxWidth)
        CGPDFDictionaryGetNumber(dict, "MissingWidth",  &self.missingWidth)
        CGPDFDictionaryGetNumber(dict, "StemV",         &self.verticalStemWidth)
        CGPDFDictionaryGetNumber(dict, "StemH",         &self.horizontalStemHeigth)
        CGPDFDictionaryGetNumber(dict, "ItalicAngle",   &self.italicAngle)

        var flagsValue: CGPDFInteger = 0
        if CGPDFDictionaryGetInteger(dict, "Flags", &flagsValue) {
            self.flags = PDFFont.Flag(rawValue: flagsValue)
        }

        var pdfFontName: UnsafePointer<Int8>? = nil
        if  CGPDFDictionaryGetName(dict, "FontName", &pdfFontName),
            let fontName = String.decodePDFInt8CString(pdfFontName) {
            self.fontName = fontName
        }

        var bboxValue: CGPDFArrayRef? = nil
        if  CGPDFDictionaryGetArray(dict, "FontBBox", &bboxValue),
            let bboxValueNonNil = bboxValue,
            CGPDFArrayGetCount(bboxValueNonNil) == 4 {

            var x : CGPDFInteger = 0,
            y : CGPDFInteger = 0,
            width : CGPDFInteger = 0,
            height : CGPDFInteger = 0

            CGPDFArrayGetInteger(bboxValueNonNil, 0, &x)
            CGPDFArrayGetInteger(bboxValueNonNil, 1, &y)
            CGPDFArrayGetInteger(bboxValueNonNil, 2, &width)
            CGPDFArrayGetInteger(bboxValueNonNil, 3, &height)

            self.bounds = CGRect(x:x, y:y, width:width, height:height)
        }

        var fontFileStream: CGPDFStreamRef? = nil
        if  CGPDFDictionaryGetStream(dict, "FontFile", &fontFileStream),
            let fontFileStreamNonNil = fontFileStream {
            var format: CGPDFDataFormat = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(fontFileStreamNonNil, &format) {
                self.fontFile = PDFType1FontFile(data:data, format: format)
            }
        } else if CGPDFDictionaryGetStream(dict, "FontFile2", &fontFileStream),
            let fontFileStreamNonNil = fontFileStream {
            var format: CGPDFDataFormat = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(fontFileStreamNonNil, &format) {
                do {
                    self.fontFile = try TrueTypeFontFile(data:data)
                } catch {
                    //TODO: report to real log system.
                    print("FontFile Error : \(error)\n")
                }
            }
        }
    }

    static let empty = PDFFontDescriptor()
}
