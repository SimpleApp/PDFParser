//
//  PDFFont.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.
//  Inspired by PDFKitten library https://github.com/KurtCode/PDFKitten

import Foundation
import CoreGraphics

typealias PDFCharacterCode = UInt8

public class PDFFont {
    enum Encoding {
        case unknown
        case standard // Defined in Type1 font programs
        case macRoman
        case winAnsi
        case pdfDoc
        case macExpert

        func toNative() -> String.Encoding {
            switch self {
            case .macRoman:
                return String.Encoding.macOSRoman
            case .winAnsi:
                return String.Encoding.windowsCP1252
            default:
                return String.Encoding.utf8
            }
        }
    }

    struct Flag: OptionSet {
        let rawValue: Int

        static let fixedPitch   = 1 << 0
        static let serif        = 1 << 1
        static let symbolic     = 1 << 2
        static let script       = 1 << 3
        static let nonSymbolic  = 1 << 5
        static let italic       = 1 << 6
        static let allCap       = 1 << 16
        static let smallCap     = 1 << 17
        static let forceBold    = 1 << 18
    }

   
    var toUnicode = CMap()
    var widths = [PDFCharacterCode:CGFloat]() // width of char using original character encoding.
    var descriptor = PDFFontDescriptor.empty
    var ligatures = [String:unichar]()
    let minY: CGFloat = 0
    let maxY: CGFloat = 0
    var widthsRange = NSMakeRange(0, 0)
    var baseFontName = ""
    var encoding = Encoding.unknown
    var spaceCharEncoded: PDFCharacterCode?

    init() {
    }

    //MARK: - Public api
    /* Given a PDF string, returns a Unicode string */

    init?(pdfDictionary: CGPDFDictionaryRef?) {
        guard let pdfDictionary = pdfDictionary else { return }
        // Populate the glyph widths store
        setWidths(fontDictionary: pdfDictionary)

        // Initialize the font descriptor
        setFontDescriptor(fontDictionary: pdfDictionary)

        // Parse ToUnicode map
        setToUnicode(fontDictionary: pdfDictionary)

        // Set the font's base font
        var fontName : UnsafePointer<Int8>? = nil
        if  CGPDFDictionaryGetName(pdfDictionary, "BaseFont", &fontName),
            let fontNameNonNill = fontName
        {
            baseFontName = String(cString:fontNameNonNill)
        }
    }

    func string(from pdfString:CGPDFStringRef) -> (str:String, originalCharCodes:[PDFCharacterCode])  {

        guard let characterCodes = CGPDFStringGetBytePtr(pdfString) else {
            return ("", [])
        }

        let characterCodeCount = CGPDFStringGetLength(pdfString)

        var str: String = ""
        var originalCharCodes = [PDFCharacterCode]()
        for i in 0 ..< characterCodeCount {
            let charCode: PDFCharacterCode = characterCodes[i]
            originalCharCodes.append(charCode)
            if var value = toUnicode.unicodeCharacter(forPDFCharacter: charCode) {
                str.append(String(utf16CodeUnits: &value, count: 1))
            } else if let glyphName = descriptor.fontFile?.glyphName(forChar:charCode),
                var value = PDFAGL.unicodeForGlyphName[glyphName] {
                str.append(String(utf16CodeUnits: &value, count: 1) )
            } else {
                str.append(String(bytes: [charCode], encoding: encoding.toNative()) ?? "\u{FFFD}")
            }
        }
        return (str, originalCharCodes)
    }



    func setEncoding(fontDictionary: CGPDFDictionaryRef?) {
        guard let fontDictionary = fontDictionary else { return }
        var encodingName: UnsafePointer<Int8>? = nil
        if !CGPDFDictionaryGetName(fontDictionary, "Encoding", &encodingName)
        {
            var encodingDict: CGPDFDictionaryRef? = nil

            if CGPDFDictionaryGetDictionary(fontDictionary, "Encoding", &encodingDict),
                let encodingDictNonNil = encodingDict {
                CGPDFDictionaryGetName(encodingDictNonNil,"BaseEncoding", &encodingName)
            }
            // TODO: Also get differences from font encoding dictionary
        }

        if let encodingNameNonNil = encodingName {
            setEncoding(name:String(cString:encodingNameNonNil))
        }
    }

    func setEncoding(name: String?) {
        switch name {
        case "MacRomanEncoding":
            encoding = .macRoman
        case "WinAnsiEncoding":
            encoding = .winAnsi
        default:
            encoding = .unknown
        }

        spaceCharEncoded = PDFCharacterCode(" ".cString(using: encoding.toNative())?.first ?? 0)
    }

    func setWidths(fontDictionary: CGPDFDictionaryRef) {
        //Sublcass should override this.
    }

    func setFontDescriptor(fontDictionary: CGPDFDictionaryRef) {
        var descriptor: CGPDFDictionaryRef? = nil
        guard
            CGPDFDictionaryGetDictionary(fontDictionary, "FontDescriptor", &descriptor),
            let descriptorNonNil = descriptor  else { return }
        self.descriptor = PDFFontDescriptor(pdfDictionary:descriptorNonNil)
    }

    func setToUnicode(fontDictionary: CGPDFDictionaryRef){
        var stream: CGPDFStreamRef? = nil
        guard
            CGPDFDictionaryGetStream(fontDictionary, "ToUnicode", &stream),
            let streamNonNil = stream else { return }
        self.toUnicode = CMap(stream:streamNonNil)
    }


    func displacementInGlyphSpace(forChar char: unichar, originalCharCode oChar:PDFCharacterCode) -> CGPoint {
        return CGPoint(x: widths[oChar] ??
            (descriptor.missingWidth > 0 ? descriptor.missingWidth : descriptor.fontFile?.glyphWidthInThousandthOfEM(forChar:char, originalCharCode:oChar)
                ?? 0)  , y: 0)
    }

    //scale by a thousandth
    static let defaultFontMatrix = CGAffineTransform(a:  0.001 ,b:  0,
                                                     c:  0     ,d:  0.001,
                                                     tx: 0     ,ty: 0)
    func fontMatrix() -> CGAffineTransform {
        return PDFFont.defaultFontMatrix
    }

}
