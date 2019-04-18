//
//  RenderingState.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.

import Foundation
import CoreGraphics

public class PDFRenderingState {
    var lineMatrix: CGAffineTransform = .identity
    var textMatrix: CGAffineTransform = .identity
    var ctm: CGAffineTransform = .identity
    var deviceSpaceMatrix : CGAffineTransform {
        return textMatrix.concatenating(ctm)
    }
    var leading: CGFloat = 0
    public internal(set) var wordSpacing: CGFloat = 0
    public internal(set) var characterSpacing: CGFloat = 0
    var horizontalScaling: CGFloat = 1
    var textRise: CGFloat = 0
    public var font: PDFFont = PDFFont.init()
    var fontSize: CGFloat = 0

    public init() {
    }

    public convenience init(state: PDFRenderingState) {
        self.init()
        lineMatrix = state.lineMatrix
        textMatrix = state.textMatrix
        ctm = state.ctm
        leading = state.leading
        wordSpacing = state.wordSpacing
        characterSpacing = state.characterSpacing
        horizontalScaling = state.horizontalScaling
        textRise = state.textRise
        font = state.font
        fontSize = state.fontSize
    }

    //Note : translation is expressed in unscaled text space units. That is, value will NOT be multipled by fontSize later
    func translateTextMatrix(by delta: CGSize) {
        textMatrix.tx += delta.width
        textMatrix.ty += delta.height
        //Note : do not use textMatrix.translatedBy because it would apply scaling to the translation.
    }

    func convertHorizontalGlyphSpaceToTextSpace(_ value: CGFloat) -> CGFloat {
        return font.fontMatrix().a * value
    }
    func convertVerticalGlyphSpaceToTextSpace(_ value: CGFloat) -> CGFloat {
        return font.fontMatrix().d * value
    }

    func setTextMatrix(_ matrix: CGAffineTransform, replaceLineMatrix:Bool) {
        textMatrix = matrix
        if (replaceLineMatrix) {
            lineMatrix = matrix
        }
    }

    func newLine() {
        newLine(leading: leading, indent: 0, save: false)
    }

    func newLine(leading:CGFloat, indent:CGFloat, save:Bool) {
        let t = lineMatrix.translatedBy(x: indent, y:leading)
        setTextMatrix(t, replaceLineMatrix:true)
        if save {
            self.leading = leading
        }
    }

    public func sizeInDeviceSpace(forCharacters characters:[PDFFontFile.CharacterId], horizontal: Bool = true) -> (deviceSpaceSize:CGSize, textMatrixTranslation:CGSize) {
        assert(horizontal, "vertical writing not supported")
        var strSize = CGSize(width: 0, height: fontSize)

        for char in characters {
            let charDisplacement = font.displacementInGlyphSpace(forChar: char)
            /*
             var chars = [char]
            print ("char \(String(utf16CodeUnits:&chars, count:1)) [\(char)] , displacement: \(charDisplacement)")
             */
            strSize = CGSize(width: strSize.width
                    + fontSize * convertHorizontalGlyphSpaceToTextSpace(charDisplacement.x)
                    + characterSpacing
                    + (char == font.spaceCharId ? wordSpacing : 0),

                             height: max(strSize.height,
                    textRise
                    + fontSize * convertVerticalGlyphSpaceToTextSpace(charDisplacement.y)))

        }
        /*if str.contains("n s’") {
            print("check")
        }*/
        let textSpaceScaling = CGAffineTransform.init(scaleX: horizontalScaling * textMatrix.a, y: textMatrix.d)
        let textMatrixTranslation = strSize.applying(textSpaceScaling)
        let deviceSpaceSize = textMatrixTranslation.applying(ctm)
        return (deviceSpaceSize, textMatrixTranslation)
    }

    func deviceSpaceFrame(forCharacters chars:[PDFFontFile.CharacterId],  horizontal: Bool = true) -> (deviceSpaceFrame:CGRect, textMatrixTranslation: CGSize) {
        assert(horizontal, "vertical writing not supported")
        let trm = deviceSpaceMatrix
        let (deviceSpaceSize, textMatrixTranslation) = sizeInDeviceSpace(forCharacters:chars)
        let res = CGRect(x: trm.tx, y: trm.ty,
                      width: deviceSpaceSize.width,
                      height: deviceSpaceSize.height)
        return (res, textMatrixTranslation)
    }
}
