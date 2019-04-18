//
//  TextAttributes.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 24/07/2018.
//  Copyright © 2018 SimpleApp. All rights reserved.
//

import Foundation
import UIKit

public struct TextAtttributes {
    public typealias FontFeatureEntry = [UIFontDescriptor.FeatureKey: Int]

    public var fontTraits: UIFontDescriptor.SymbolicTraits
    var fontFeatures: [FontFeatureEntry]

    init(rendering: PDFRenderingState) {
        fontTraits = TextAtttributes.traits(forFont: rendering.font)
        fontFeatures = []
        TextAtttributes.fillFeatures(settings: &fontFeatures, fromFont: rendering.font)
    }

    static func traits(forFont font: PDFFont) -> UIFontDescriptor.SymbolicTraits {
        return traits(fromFontName: font.descriptor.fontName)
            .union(traits(fromFontName: font.baseFontName))
        .union(traits(fromFontName: font.descriptor.fontFile?.fontInfos()?.subfamily))
    }

    static func traits(fromFontName name: String? ) -> UIFontDescriptor.SymbolicTraits {
        var res = UIFontDescriptor.SymbolicTraits()
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

    static func fillFeatures(settings: inout [FontFeatureEntry], fromFont font:PDFFont) {
        fillFeatures(settings: &settings, fromFontName: font.baseFontName)
        //print("Font descriptor : \(font.descriptor)")
    }
    static func fillFeatures(settings: inout [FontFeatureEntry], fromFontName name:String?) {
        guard let lowercased = name?.lowercased() else { return }
        if lowercased.contains("smallcaps") || lowercased.contains("small capital") {
            settings.append([UIFontDescriptor.FeatureKey.featureIdentifier:kLowerCaseType,
                             UIFontDescriptor.FeatureKey.typeIdentifier:kLowerCaseSmallCapsSelector])
        }
    }

    private func featureValuesFor(feature: Int) -> [Int] {
        return fontFeatures.reduce(into: [Int](),
                                   { (_ newRes:inout [Int], _ entry:[UIFontDescriptor.FeatureKey : Int]) in
                                    if entry[UIFontDescriptor.FeatureKey.featureIdentifier] == feature,
                                        let val = entry[UIFontDescriptor.FeatureKey.typeIdentifier] {
                                        newRes.append(val)
                                    }})
    }

    public func isSmallCaps() -> Bool {
        return featureValuesFor(feature: kLowerCaseType).contains(kLowerCaseSmallCapsSelector)
    }
}


