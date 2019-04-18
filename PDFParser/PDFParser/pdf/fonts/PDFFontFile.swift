//
//  PDFFontFile.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 09/07/2018.
//

import Foundation
import CoreGraphics


public struct PDFFontFileInfos {
    let family: String?
    let subfamily: String?
    let fullName: String?
}


public protocol PDFFontFile {
    typealias CharacterId = Int
    typealias GlyphId = Int

    //Depending on the font program, a char can be encoding in one or two bytes.
    func unicodeScalar(forChar char:CharacterId) -> Unicode.Scalar?
    func glyphWidthInThousandthOfEM(forChar char: CharacterId) -> CGFloat?
    func fontInfos() -> PDFFontFileInfos?
}


