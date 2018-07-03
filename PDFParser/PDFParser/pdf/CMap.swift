//
//  CMap.swift
//  PDFParser
//
//  Created by Benjamin Garrigues on 27/06/2018.
//

import Foundation
import CoreGraphics

extension Range : Hashable where Bound == unichar {
    public var hashValue: Int {
        return (lowerBound+upperBound).hashValue
    }
}

public class CMap {

    typealias OperatorHandler = (_ value: String, _ context: inout Context) -> ()
    struct Operator {
        var startTag: String
        var endTag: String
        var handler: OperatorHandler

        static func handleCodeSpaceRange(value: String, context: inout Context) {

        }

        static func handleCharacter(value: String, context: inout Context) {

        }

        static func handleCharacterRange(value: String, context: inout Context) {

        }
    }

    struct Context {
        var cmapOperator: Operator?
    }

    var context: Context?

    /* CMap ranges */
    var codeSpaceRanges = [Range<unichar>]()

    /* Character mappings */
    var  characterMappings = [unichar:unichar]()

    /* Character range mappings */
    var characterRangeMappings = [Range<unichar>:Int]()

    func unicodeCharacter(forPDFCharacter charCode: PDFCharacterCode) -> unichar? {
        return characterMappings[unichar(charCode)]
    }

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


    private func isInCodeSpaceRange(_ cid: unichar) -> Bool {
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

    func unicodeCharacter(cid: unichar) -> unichar? {
        if !isInCodeSpaceRange(cid) { return nil }

        for (range, offset) in characterRangeMappings {
            if range.contains(cid) {
                return cid.advanced(by: offset)
            }
        }

        return characterMappings[cid]
    }

    func parse(_ cMapString: String) {
        let scanner = Scanner(string:cMapString)
        while !scanner.isAtEnd
        {
            guard let token = tokenByTrimmingComments(scanner: scanner) else { continue }

            if let cmapOperator = self.cmapOperator(withStartingToken: token)
            {
                // Start a new context
                context = Context(cmapOperator: cmapOperator)
            }
            else if var context = self.context
            {
                if context.cmapOperator?.endTag == token {
                    self.context = nil
                } else {
                    context.cmapOperator?.handler(token, &context)
                    self.context = context
                }
            }
        }
    }
}


