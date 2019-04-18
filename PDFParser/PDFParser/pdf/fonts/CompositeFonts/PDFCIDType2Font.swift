//
//  PDFCIDType2Font.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 06/07/2018.
//

import Foundation
import CoreGraphics

class PDFCIDType2Font : PDFCIDFont {

    override init?(pdfDictionary: CGPDFDictionaryRef?) {
        super.init(pdfDictionary: pdfDictionary)
        guard let pdfDictionary = pdfDictionary else { return }
        var streamOrNameOrNil : CGPDFObjectRef?
        if
            CGPDFDictionaryGetObject(pdfDictionary, "CIDToGIDMap", &streamOrNameOrNil) {
            if let streamOrName = streamOrNameOrNil {
                let type = CGPDFObjectGetType(streamOrName)
                identity = type == CGPDFObjectType.name
                if type == .stream {
                    print("WARNING CIDType2Font: CIDtoGID stream decoded but not supported. Only /Identity is.")
                    var streamRef: CGPDFStreamRef?
                    if CGPDFObjectGetValue(streamOrName, .stream, &streamRef) {
                        if let stream = streamRef {
                            var format: CGPDFDataFormat = .raw
                            cidGidMap = CGPDFStreamCopyData(stream, &format) as Data?
                        }
                    }
                }
            }
        }
    }
}
