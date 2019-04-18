//
//  PDFType1FontFile.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 18/07/2018.
//

import Foundation
import CoreGraphics

struct PDFType1FontFile {

    static let headerLength: Int = 6
    var data: Data {
        didSet {

        }
    }

    private(set) var text: String
    private(set) var asciiTextLength: Int
    private(set) var names: [Int:String]
    init(data: CFData, format: CGPDFDataFormat) {
        self.data = data as Data
        (self.asciiTextLength, self.text) = PDFType1FontFile.dataToText(self.data)
        let scanner = Scanner(string:self.text)

        names = [Int:String]()

        var nsBuffer: NSString?

        while !scanner.isAtEnd {
            if !scanner.scanUpToCharacters(from: .whitespacesAndNewlines, into: &nsBuffer) {
                break;
            }
            let buffer = nsBuffer as String?

            if buffer?.hasPrefix("%") == true {
                scanner.scanUpToCharacters(from: .newlines, into: nil)
                continue
            }

            if (buffer == "dup")
            {
                var code: Int = 0
                var nsName: NSString?
                scanner.scanInt(&code)
                scanner.scanUpToCharacters(from: .whitespacesAndNewlines, into: &nsName)
                if let name = nsName as String? {
                    names[code] = name
                }
            }
        }
    }

    static func dataToText(_ data: Data) -> (asciiTextLength: Int, text: String) {
        // ASCII segment length (little endian)
        var text: String = ""
        var asciiTextLength: Int = 0
        data.withUnsafeBytes { (rawBytes: UnsafeRawBufferPointer) -> Void in
            let bytes = rawBytes.bindMemory(to: UInt8.self)
            if (data.count > 0 && bytes[0] == 0x80)
            {
                asciiTextLength = Int(bytes[2]) | Int(bytes[3]) << 8 | Int(bytes[4]) << 16 | Int(bytes[5]) << 24
                let headerEndIndex = data.index(data.startIndex, offsetBy: PDFType1FontFile.headerLength)
                let asciiTextEndIndex = headerEndIndex.advanced(by: asciiTextLength)
                let textData = data[headerEndIndex..<asciiTextEndIndex]
                text = String(data:textData, encoding:.ascii) ?? ""
            }
            else
            {
                text = String(data:data, encoding:.ascii) ?? ""
            }
        }
        return (asciiTextLength, text)
    }

    //MARK: - Lookup functions

    func char(forGlyphname name: String) -> CharacterId? {
        return names.first(where: {$1 == name})?.key
    }

    func glyphName(forChar char:CharacterId) -> String? {
        return names[char]
    }
}

extension PDFType1FontFile: PDFFontFile {
    func glyphWidthInThousandthOfEM(forChar char: CharacterId) -> CGFloat? {
        return nil
    }
    
    func unicodeScalar(forChar char:CharacterId) -> Unicode.Scalar? {
        guard let glyphName = glyphName(forChar:char),
            let uchar = PDFAGL.unicodeForGlyphName[glyphName] else { return nil }
        return Unicode.Scalar(uchar)
    }

    func fontInfos() -> PDFFontFileInfos? {
        return nil
    }
}
