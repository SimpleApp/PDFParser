//
//  SimpleDocumentIndexer.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 11/07/2018.
//

import Foundation
import CoreGraphics
import UIKit

fileprivate extension TextBlock {
    func isBold() -> Bool {
        return attributes.fontTraits.contains(UIFontDescriptor.SymbolicTraits.traitBold)
    }

    func wordSpacing(errorFactor:CGFloat = 0.99) -> CGFloat {
        var spaceOriginaCharIds = [PDFFontFile.CharacterId]()
        var res: CGFloat = 0.0
        if let spaceCharId = renderingState.font.spaceCharId {
            spaceOriginaCharIds = [spaceCharId]
            res = renderingState.sizeInDeviceSpace(forCharacters: spaceOriginaCharIds).deviceSpaceSize.width
        }
        if res > 0 { return errorFactor * res }
        res = renderingState.wordSpacing
        if res > 0 { return errorFactor * res }
        res = renderingState.characterSpacing
        if res > 0 { return errorFactor * res }

        return errorFactor * frame.width / CGFloat(min(1,chars.count))
    }
}

public class SimpleDocumentIndexer {

    public class PageIndex {
        public private(set) var textBlocks = [TextBlock]()
        public private(set) var lines = [CGFloat:LineTextBlock]()

        init(){}

        func push(_ originalTextBlock: TextBlock){
            //We want to backup the rendering state, because it is going to mutate.
            var textBlock = originalTextBlock
            textBlock.renderingState = PDFRenderingState(state: textBlock.renderingState)
            textBlocks.append(textBlock)
            var line = lines[textBlock.frame.origin.y, default: LineTextBlock()]
            line.blocks.append(textBlock)
            lines[textBlock.frame.origin.y] = line
        }

        func coalesceWords() {
            lines = lines.mapValues{ return $0.wordCoalesced() }
        }

        func allLinesDescription(coalesceWords: Bool = true) -> String {
            if coalesceWords {
                self.coalesceWords()
            }
            var res = ""
            for lineY in lines.keys.sorted() {
                res.append("\(lineY) : " + lines[lineY]!.string() + "\n")
            }
            return res
        }


    }

    public struct LineTextBlock {
        var blocks = [TextBlock]()

        func string() -> String {
            return blocks.sorted(by:{ return $0.frame.origin.x < $1.frame.origin.x }).reduce("") { (res:String, block:TextBlock) -> String in
                res.appending((res.endsWithCharInSet(set: .alphanumerics) && block.chars.beginsWithCharInSet(set: .alphanumerics) ? " " : "") + block.chars)
            }
        }

        static func canCoalesce(previousBlockFont: PDFFont, with nextBlockFont: PDFFont) -> Bool {
            return
                previousBlockFont.baseFontName == nextBlockFont.baseFontName
        }

        //Left to right reading
        func wordCoalesced() -> LineTextBlock {
            var res = [TextBlock]()
            var tmpBlockOrNil: TextBlock? = self.blocks.first
            var iNext = 1
            while let tmpBlock = tmpBlockOrNil,
                iNext < blocks.count {
                    let nextBlock = blocks[iNext]
                    if let coalescedBlock = LineTextBlock.coalesceWords(previous: tmpBlock, with: nextBlock) {
                        tmpBlockOrNil = coalescedBlock
                    } else {
                        res.append(tmpBlock)
                        tmpBlockOrNil = nextBlock
                    }
                    iNext += 1
            }
            if let tmpBlock = tmpBlockOrNil {
                res.append(tmpBlock)
            }
            return LineTextBlock(blocks: res)
        }

        static func coalesceWords(previous: TextBlock, with next: TextBlock) -> TextBlock? {
            let blockSpacing = next.frame.minX - previous.frame.maxX
            let spaceWidth = widthOfSpaceInDeviceSpace(renderingState: previous.renderingState)
            if
                canCoalesce(previousBlockFont: previous.renderingState.font, with: next.renderingState.font) &&
                    previous.chars.canFormWord(with: next.chars) &&
                    previous.renderingState.deviceSpaceFontSize == next.renderingState.deviceSpaceFontSize &&
                    blockSpacing < spaceWidth {
                print ("coalesce \(previous.chars) [\(previous.frame)] with \(next.chars) [\(next.frame)]\n")

                var res = previous
                res.chars.append(next.chars)
                res.characterIds.append(contentsOf: next.characterIds)
                res.frame = CGRect(x: previous.frame.minX,y:previous.frame.minY,
                                   width: next.frame.maxX - previous.frame.minX,
                                   height: previous.frame.height)
                return res
            }
            return nil
        }


        static func widthOfSpaceInDeviceSpace(renderingState: PDFRenderingState ) -> CGFloat {
            return renderingState.sizeInDeviceSpace(forCharacters: [renderingState.font.spaceCharId ?? 0x20] ).deviceSpaceSize.width
        }



    }


    public internal(set) var pageIndexes = [Int: PageIndex]()

    var currentPageIndex: PageIndex
    var currentPageNumber: Int
    var currentPageSize: CGSize
    init() {
        currentPageIndex = PageIndex()
        currentPageNumber = 0
        currentPageSize = .zero
        pageIndexes[currentPageNumber] = currentPageIndex
    }


}

extension TextBlock {
    func averageCharWidth() -> CGFloat {
        return frame.width / CGFloat(chars.count)
    }
}


extension Unicode.Scalar {
    func isIn(_ set: CharacterSet) -> Bool {
        return set.contains(self)
    }
}
extension String {
    public func endsWithCharInSet(set: CharacterSet) -> Bool {
        return unicodeScalars.last?.isIn(set) ?? false
    }
    public func beginsWithCharInSet(set: CharacterSet) -> Bool {
        return unicodeScalars.first?.isIn(set) ?? false
    }
    public func canFormWord(with str2: String) -> Bool {
        return endsWithCharInSet(set: .letters) && str2.beginsWithCharInSet(set: .letters)
    }
}

extension SimpleDocumentIndexer : DocumentIndexer {
    public func beginNewPage(pageNumber: Int, pageSize: CGSize) {
        currentPageNumber = pageNumber
        currentPageIndex = PageIndex()
        currentPageSize = pageSize
        pageIndexes[currentPageNumber] = currentPageIndex
    }


    public func didScanTextBlock(_ textBlock: TextBlock) {
        //Revert Y-Orientation
        var revertedTextBlock = textBlock
        revertedTextBlock.frame = CGRect(x:textBlock.frame.origin.x.rounded(.toNearestOrAwayFromZero),
                                 y: (currentPageSize.height - textBlock.frame.origin.y).rounded(.toNearestOrAwayFromZero),
                                 width: textBlock.frame.width.rounded(.toNearestOrAwayFromZero),
                                 height: textBlock.frame.height.rounded(.toNearestOrAwayFromZero))
        currentPageIndex.push(revertedTextBlock)
    }
}

extension PDFRenderingState {
    public var deviceSpaceFontSize : CGFloat {
        return deviceSpaceMatrix.a * fontSize
    }

}

