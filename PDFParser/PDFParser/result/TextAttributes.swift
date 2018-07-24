//
//  TextAttributes.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 24/07/2018.
//  Copyright © 2018 SimpleApp. All rights reserved.
//

import Foundation
import UIKit

struct TextAtttributes {
    var fontTraits: UIFontDescriptorSymbolicTraits
    var attributes: [NSAttributedStringKey: Any]

    init(rendering: PDFRenderingState) {
        fontTraits = TextAtttributes.traits(forFont: rendering.font)
        attributes = TextAtttributes.attributes(forRendering: rendering)
    }

    static func traits(forFont font: PDFFont) -> UIFontDescriptorSymbolicTraits {
        return traits(fromFontName: font.descriptor.fontName)
            .union(traits(fromFontName: font.baseFontName))
        .union(traits(fromFontName: font.descriptor.fontFile?.fontInfos()?.subfamily))
    }

    static func traits(fromFontName name: String? ) -> UIFontDescriptorSymbolicTraits {
        var res = UIFontDescriptorSymbolicTraits()
        guard let lowercased = name?.lowercased() else { return res }
        if lowercased.contains("bold") {
            res.insert(.traitBold)
        }
        if lowercased.contains("italic") {
            res.insert(.traitItalic)
        }
        if lowercased.contains("condensed") {
            res.insert(.traitCondensed)
        }
        return res
    }

    static func attributes(forRendering: PDFRenderingState) -> [NSAttributedStringKey:Any] {
        //TODO
        return [:]
    }
}


