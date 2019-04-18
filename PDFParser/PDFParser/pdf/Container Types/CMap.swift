//
//  CMap.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.
//

import Foundation
import CoreGraphics

public class CMap {

    typealias OperatorHandler = (_ cmap: CMap, _ value: String, _ context: inout Context) -> ()
    struct Operator {
        var startTag: String
        var endTag: String
        var handler: OperatorHandler

        static func handleCodeSpaceRange(_ cmap: CMap, _ value: String, _ context: inout Context) {
            let value = valueOfTag(tagString: value)
            guard context.paramStack.count >= 1 else
            {
                context.paramStack.append(value)
                return;
            }
            cmap.codeSpaceRanges.append(rangeValue(context.paramStack[0], value))
            context.paramStack.removeAll()
        }

        static func handleCharacter(_ cmap: CMap, _ value: String, _ context: inout Context) {
            let value = valueOfTag(tagString: value)
            guard context.paramStack.count >= 1 else
            {
                context.paramStack.append(value)
                return;
            }
            cmap.characterMappings[context.paramStack[0]] = unichar(value)
            context.paramStack.removeAll()
        }

        static func handleCharacterRange(_ cmap: CMap, _ value: String, _ context: inout Context) {
            let value = valueOfTag(tagString: value)
            guard context.paramStack.count >= 2 else
            {
                context.paramStack.append(value)
                return;
            }
            cmap.characterRangeMappings[rangeValue(context.paramStack[0], context.paramStack[1])] = unichar(value)
            context.paramStack.removeAll()
        }

        static func rangeValue(_ low: Int, _ high: Int) -> ClosedRange<Int> {
            let high = max(high, low)
            return low...high
        }

        static let tagSet = CharacterSet(charactersIn: "<>")
        static func valueOfTag(tagString: String) -> Int {
            var res: UInt32 = 0
            let tagString = tagString.trimmingCharacters(in: tagSet)
            let scanner = Scanner(string: tagString)
            scanner.scanHexInt32(&res)
            return Int(res)
        }
    }

    struct Context {
        var paramStack: [Int]
        var cmapOperator: Operator?
    }

    var context: Context?

    /* CMap ranges */
    var codeSpaceRanges = [ClosedRange<PDFFontFile.CharacterId>]()

    /* Character mappings */
    var characterMappings = [PDFFontFile.CharacterId:unichar]()

    /* Character range mappings */
    var characterRangeMappings = [ClosedRange<PDFFontFile.CharacterId>:unichar]()

    static let sharedOperators : [String: Operator] = [
        "begincodespacerange": Operator(startTag: "begincodespacerange", endTag: "endcodespacerange", handler: Operator.handleCodeSpaceRange),
        "beginbfchar": Operator(startTag: "beginbfchar", endTag: "endbfchar", handler: Operator.handleCharacter),
        "beginbfrange": Operator(startTag: "beginbfrange", endTag: "endbfrange", handler: Operator.handleCharacterRange),
    ]

    /* Operator mapping */
    func cmapOperator(withStartingToken token:String) -> Operator? {
        return CMap.sharedOperators[token]
    }

    convenience init(string: String) {
        self.init()
        parse(string)
    }

    convenience init(stream: CGPDFStreamRef) {
        self.init()
        var format:CGPDFDataFormat = .raw
        guard
            let data = CGPDFStreamCopyData(stream, &format),
            let text = String(data:data as Data, encoding:String.Encoding.utf8)else { return }

        parse(text)
    }

    private func isInCodeSpaceRange(_ cid: PDFFontFile.CharacterId) -> Bool {
        return codeSpaceRanges.first { $0.contains(cid) } != nil
    }

    /**!
     * Returns the next token that is not a comment. Only remainder-of-line comments are supported.
     * The scanner is advanced to past the returned token.
     *
     * @param scanner a scanner
     * @return next non-comment token
     */
    static let commentMarker: String = "%%"
    func tokenByTrimmingComments(scanner: Scanner) -> String?
    {
        var tokenNSString: NSString?
        var token: String?
        scanner.scanUpToCharacters(from: tokenDelimiterSet(), into: &tokenNSString)
        token = tokenNSString as String?

        if token == nil {
            // There's no token delimiters left in the scanner, so we need to scan to the end.

            // Advance the scanner to the end of the string
            // Get the remainder of the scanner's string
            let remainder = String(scanner.string.suffix(from: scanner.string.index(scanner.string.startIndex, offsetBy:scanner.scanLocation)))
            scanner.scanString(remainder, into:nil)
            token = remainder
        }

        if let commentMarkerRange = token?.range(of:CMap.commentMarker) {
            scanner.scanUpToCharacters(from: tokenDelimiterSet(), into:nil)
            if let prefix = token?.prefix(upTo:commentMarkerRange.lowerBound) {
                token = String(prefix)
                if token?.count == 0 {
                    return tokenByTrimmingComments(scanner: scanner)
                }
            }
        }

        return token
    }

    //MARK: - Public method

    func tokenDelimiterSet() -> CharacterSet {
        return CharacterSet.whitespacesAndNewlines
    }

    func unicodeCharacter(forChar cid: PDFFontFile.CharacterId) -> Unicode.Scalar? {
        if !isInCodeSpaceRange(cid) { return nil }

        if let directMapping = characterMappings[cid] { return Unicode.Scalar(directMapping)}

        for (range, lowRangeChar) in characterRangeMappings {
            if range.contains(cid) {
                return Unicode.Scalar(lowRangeChar.advanced(by: (cid - range.lowerBound)))
            }
        }
        return nil
    }

    //Perform reverse lookup
    func characterForUnicode(_ scalar: Unicode.Scalar) -> PDFFontFile.CharacterId? {
        for (cid,unic) in characterMappings {
            if Unicode.Scalar(unic) == scalar {
                return cid
            }
        }
        for (range, unicStart) in characterRangeMappings {
            let distToUnicStart = Int(scalar.value) - Int(unicStart)
            guard distToUnicStart >= 0 && distToUnicStart < range.count else { continue }
            return range.lowerBound.advanced(by: distToUnicStart)
        }
        return nil
    }

    func parse(_ cMapString: String) {

        let spacedItemsString = cMapString.replacingOccurrences(of: "><", with: "> <")
        let scanner = Scanner(string:spacedItemsString)
        while !scanner.isAtEnd
        {
            guard let token = tokenByTrimmingComments(scanner: scanner) else { continue }

            if let cmapOperator = self.cmapOperator(withStartingToken: token)
            {
                // Start a new context
                context = Context(paramStack:[], cmapOperator: cmapOperator)
            }
            else if var context = self.context
            {
                if context.cmapOperator?.endTag == token {
                    self.context = nil
                } else {
                    context.cmapOperator?.handler(self, token, &context)
                    self.context = context
                }
            }
        }
    }
}


