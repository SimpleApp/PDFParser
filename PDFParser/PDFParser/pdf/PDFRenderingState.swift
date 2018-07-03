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
    var leading: CGFloat = 0
    var wordSpacing: CGFloat = 0
    var characterSpacing: CGFloat = 0
    var horizontalScaling: CGFloat = 1
    var textRise: CGFloat = 0
    var font: PDFFont = PDFFont.init()
    var fontSize: CGFloat = 0

    init() {
    }

    convenience init(state: PDFRenderingState) {
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

    //Note : translation is expressed in unscaled text space units. That is, value will NOT be multipled by fontSize later.
    func translateTextMatrix(by delta: CGSize) {
        textMatrix = textMatrix.translatedBy(x: delta.width, y: delta.height)
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

    func sizeInDeviceSpace(ofText str:String, originalCharCodes oCharCodes:[Int], horizontal: Bool = true) -> CGSize {
        assert(horizontal, "vertical writing not supported")
        let trm = textMatrix.concatenating(ctm)
        var strSize = CGSize(width: 0, height: fontSize)
        for (i,char) in str.utf16.enumerated() {

            let charDisplacement = font.displacementInGlyphSpace(forChar: char, originalCharCode: oCharCodes[i])
            /*
             var chars = [char]
            print ("char \(String(utf16CodeUnits:&chars, count:1)) [\(char)] , displacement: \(charDisplacement)")
             */
            strSize = CGSize(width: strSize.width
                    + fontSize * convertHorizontalGlyphSpaceToTextSpace(charDisplacement.x)
                    + characterSpacing
                    + (char == 0x20 ? wordSpacing : 0),

                             height: max(strSize.height,
                    textRise
                    + fontSize * convertVerticalGlyphSpaceToTextSpace(charDisplacement.y)))

        }
        /*if str.contains("n s’") {
            print("check")
        }*/
        return strSize.applying(CGAffineTransform.init(scaleX: horizontalScaling * trm.a,
                                                       y: trm.d))
    }

    func deviceSpaceFrameForText(_ str:String, originalCharCodes oCharCodes:[Int],  horizontal: Bool = true) -> CGRect {
        assert(horizontal, "vertical writing not supported")
        let trm = textMatrix.concatenating(ctm)
        let strSize = sizeInDeviceSpace(ofText: str, originalCharCodes:oCharCodes)
        let res = CGRect(x: trm.tx, y: trm.ty,
                      width: strSize.width,
                      height: strSize.height)
        return res
    }
}
