//
//  PDFFont.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.
//  Inspired by PDFKitten library https://github.com/KurtCode/PDFKitten

import Foundation
import CoreGraphics

public typealias PDFCharacterByte = UInt8

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
    public var descriptor = PDFFontDescriptor.empty
    var ligatures = [String:unichar]()
    let minY: CGFloat = 0
    let maxY: CGFloat = 0
    public var baseFontName = ""
    var encoding: Encoding? = nil
    public var spaceCharId: PDFFontFile.CharacterId?
    var currentSystemIsLittleEndian: Bool = false

    init() {
    }

    //MARK: - Constructor
    init?(pdfDictionary: CGPDFDictionaryRef?) {
        currentSystemIsLittleEndian = Int(littleEndian: 1) == 1

        guard let pdfDictionary = pdfDictionary else { return }

        //Parsing all possible entries. When an entry key depends on the font type, it is provided as a parameter (eg: for widths)
        parseFontDescriptor(fontDictionary: pdfDictionary)
        parseToUnicode(fontDictionary: pdfDictionary)
        parseEncoding(fontDictionary: pdfDictionary)

        // Set the font's base font
        parseBaseFontName(fontDictionary: pdfDictionary)

        // TODO: parse \Differences


        guessSpaceCharacterId()

    }

    //MARK: - Public functions
    /*** Text parsing
     */
    func string(from pdfString:CGPDFStringRef) -> (str:String, characterIds:[PDFFontFile.CharacterId])  {
        let charIds = self.pdfStringToCharacterIds(pdfString)
        let scalars: [Unicode.Scalar] = charIds.map{ characterIdToUnicode($0) ?? Unicode.Scalar(0xFFFD)! }
        let str = String(String.UnicodeScalarView(scalars))
        return (str, charIds)

    }

    /*** Metrics
    **/
    func displacementInGlyphSpace(forChar char:PDFFontFile.CharacterId) -> CGPoint {
        assertionFailure("Override in subclasses")
        return .zero
    }


    //MARK: - Text decoding functions
    func pdfStringToCharacterIds(_ pdfString:CGPDFStringRef) -> [PDFFontFile.CharacterId] {
        assertionFailure("Override in subclasses")
        return []
    }

    func characterIdToUnicode(_ char:PDFFontFile.CharacterId) -> Unicode.Scalar? {
        assertionFailure("Override in subclasses")
        return nil // Replacement character
    }



    //MARK: per property

    func toUnicodeCharMapLookup(_ char: PDFFontFile.CharacterId) -> Unicode.Scalar? {
        return self.toUnicode.unicodeCharacter(forChar: char)
    }

    func fontFileCharMapLookup(_ char: PDFFontFile.CharacterId) -> Unicode.Scalar? {
        return descriptor.fontFile?.unicodeScalar(forChar: char)
    }


    //MARK: - PDF Font dictionary parsing functions
    func parseBaseFontName(fontDictionary: CGPDFDictionaryRef) {
        var pdfFontName : UnsafePointer<Int8>? = nil
        if  CGPDFDictionaryGetName(fontDictionary, "BaseFont", &pdfFontName),
            let fontName = String.decodePDFInt8CString(pdfFontName)
        {
            baseFontName = fontName
        }
    }

    func parseEncoding(fontDictionary: CGPDFDictionaryRef) {
        var pdfEncodingName: UnsafePointer<Int8>? = nil
        if !CGPDFDictionaryGetName(fontDictionary, "Encoding", &pdfEncodingName)
        {
            var encodingDict: CGPDFDictionaryRef? = nil

            if CGPDFDictionaryGetDictionary(fontDictionary, "Encoding", &encodingDict),
                let encodingDictNonNil = encodingDict {
                CGPDFDictionaryGetName(encodingDictNonNil,"BaseEncoding", &pdfEncodingName)
            }
        }

        if let encodingName = String.decodePDFInt8CString(pdfEncodingName) {
            setEncoding(name:encodingName)
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


    }

    func guessSpaceCharacterId() {
        //from encoding
        if
            let encoding = encoding,
            let spaceCode = " ".data(using: encoding.toNative())?[0],
            encoding != .unknown {
            spaceCharId = Int(spaceCode)
        } else if let toUnicodeLookup = self.toUnicode.characterForUnicode(Unicode.Scalar(0x20)) {
            spaceCharId = toUnicodeLookup
        }
    }

    

    func parseFontDescriptor(fontDictionary: CGPDFDictionaryRef) {
        var descriptor: CGPDFDictionaryRef? = nil
        guard
            CGPDFDictionaryGetDictionary(fontDictionary, "FontDescriptor", &descriptor),
            let descriptorNonNil = descriptor  else { return }
        self.descriptor = PDFFontDescriptor(pdfDictionary:descriptorNonNil)
    }

    func parseToUnicode(fontDictionary: CGPDFDictionaryRef){
        var stream: CGPDFStreamRef? = nil
        guard
            CGPDFDictionaryGetStream(fontDictionary, "ToUnicode", &stream),
            let streamNonNil = stream else { return }
        self.toUnicode = CMap(stream:streamNonNil)
    }



    //scale by a thousandth
    static let defaultFontMatrix = CGAffineTransform(a:  0.001 ,b:  0,
                                                     c:  0     ,d:  0.001,
                                                     tx: 0     ,ty: 0)
    func fontMatrix() -> CGAffineTransform {
        return PDFFont.defaultFontMatrix
    }

}
