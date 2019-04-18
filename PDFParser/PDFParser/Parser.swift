//
//  Parser.swift
//  Parser
//
//  Created by Benjamin Garrigues on 27/06/2018.

import Foundation
import UIKit


public protocol ParserDelegate {
    func parser(p: Parser, didParse page:Int, outOf nbPages:Int)
    func parser(p: Parser, didCompleteWithError error: Error?, cgPDFDocument: CGPDFDocument?)
}

public class Parser {

    enum ParserError: Error {
        case couldNotCreateOperatorTableRef
        case invalidDocumentURL(url: URL)
    }

    let documentURL:URL
    let delegate: ParserDelegate
    var renderingStateStack = [PDFRenderingState]()
    var renderingState: PDFRenderingState {
        guard let res =  renderingStateStack.last else { fatalError("empty renderingStateStack")}
        return res
    }
    let indexer: DocumentIndexer
    let log: Bool
    var fontCollection = PDFFontCollection()

    public init(documentURL: URL, delegate: ParserDelegate, indexer: DocumentIndexer, log: Bool = false) throws {
        self.documentURL = documentURL
        self.delegate = delegate
        self.indexer = indexer
        self.log = log
    }

    //MARK: - Operators
    func createOperatorTable() -> CGPDFOperatorTableRef? {
        guard let operatorTable = CGPDFOperatorTableCreate() else {
            return nil
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tj", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.printString(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "\'", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.printStringNewLine(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "\"", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.printStringNewLineSetSpacing(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "TJ", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.printStringsAndSpaces(scanner: s, parser: Parser.unwrapInfos(v))})

        // Text-positioning operators
        CGPDFOperatorTableSetCallback(operatorTable, "Tm", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.setTextMatrix(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "Td", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.newLineWithLeading(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "TD", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.newLineSetLeading(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "T*", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.newLine(scanner: s, parser: Parser.unwrapInfos(v))
        });

        // Text state operators
        CGPDFOperatorTableSetCallback(operatorTable, "Tw", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.setWordSpacing(scanner: s, parser: Parser.unwrapInfos(v))});
        CGPDFOperatorTableSetCallback(operatorTable, "Tc", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.setCharacterSpacing(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "TL", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.setTextLeading(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "Tz", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.setHorizontalScale(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "Ts", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.setTextRise(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "Tf", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.setFont(scanner: s, parser: Parser.unwrapInfos(v))})

        // Graphics state operators
        CGPDFOperatorTableSetCallback(operatorTable, "cm", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.applyTransformation(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "q", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.pushRenderingState(scanner: s, parser: Parser.unwrapInfos(v))})
        CGPDFOperatorTableSetCallback(operatorTable, "Q", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.popRenderingState(scanner: s, parser: Parser.unwrapInfos(v))})

        CGPDFOperatorTableSetCallback(operatorTable, "BT", {(s: CGPDFScannerRef, v: UnsafeMutableRawPointer?) in
            Parser.newParagraph(scanner: s, parser: Parser.unwrapInfos(v))})

        return operatorTable
    }

    //MARK: - Logging {
    func log(_ str: String) {
        guard self.log else { return }
        print(str)
    }

    //MARK: - Parsing
    public func parse() {
        guard let cgDoc = CGPDFDocument(documentURL as CFURL) else {
            delegate.parser(p: self, didCompleteWithError: ParserError.invalidDocumentURL(url: (documentURL)), cgPDFDocument: nil)
            return
        }
        guard let operatorTableRef = createOperatorTable() else {
            delegate.parser(p: self, didCompleteWithError: ParserError.couldNotCreateOperatorTableRef, cgPDFDocument: nil)
            return
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
     
        for p in 1...cgDoc.numberOfPages {
            guard let page = cgDoc.page(at: p) else { continue }
            let rect = page.getBoxRect(.cropBox)
            renderingStateStack.removeAll()
            renderingStateStack.append(PDFRenderingState())
            indexer.beginNewPage(pageNumber: p, pageSize: rect.size)
            parsePage(page, operators: operatorTableRef, selfPtr:selfPointer)
            delegate.parser(p: self, didParse: p, outOf: cgDoc.numberOfPages)
        }
        delegate.parser(p: self, didCompleteWithError: nil, cgPDFDocument: cgDoc)
    }

    func parsePage(_ page: CGPDFPage, operators: CGPDFOperatorTableRef, selfPtr: UnsafeMutableRawPointer) {

        self.fontCollection = Parser.fontCollection(with: page) ?? PDFFontCollection()
        let contentStream = CGPDFContentStreamCreateWithPage(page)
        let scanner = CGPDFScannerCreate(contentStream, operators, selfPtr)

        CGPDFScannerScan(scanner)

        CGPDFScannerRelease(scanner)
        CGPDFContentStreamRelease(contentStream)
    }

    //Helper functions

    static func fontCollection(with page: CGPDFPage) -> PDFFontCollection? {
        guard let dict = page.dictionary else {
            print ("Parser: fontCollectionWithPage: page dictionary missing")
            return nil
        }

        var resources: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(dict, "Resources", &resources),
            let resourcesNonNil = resources else {
            print ("Parser: fontCollectionWithPage: resources dictionary missing")
            return nil
        }

        var fonts: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourcesNonNil, "Font", &fonts),
            let fontsNonNil = fonts else {
            return nil
        }

        return getFontCollection(fontsNonNil)
    }


    static func unwrapInfos(_ infos: UnsafeMutableRawPointer?) -> Parser {
        guard let infos = infos else {
            fatalError("no infos to unwrap")
        }
        return Unmanaged.fromOpaque(infos).takeUnretainedValue() as Parser
    }

    static func popArray(_ pdfScanner: CGPDFScannerRef) -> CGPDFArrayRef? {
        var res: CGPDFArrayRef?
        CGPDFScannerPopArray(pdfScanner, &res)
        return res
    }

    static func popString(_ pdfScanner: CGPDFScannerRef) -> CGPDFStringRef? {
        var res: CGPDFStringRef?
        CGPDFScannerPopString(pdfScanner, &res)
        return res
    }

    static func getStringValue(_ pdfObject: CGPDFObjectRef) -> CGPDFStringRef? {
        var res: CGPDFStringRef?
        CGPDFObjectGetValue(pdfObject, CGPDFObjectType.string, &res);
        return res
    }
    static func popNumber(_ scanner: CGPDFScannerRef) -> CGPDFReal {
        var res: CGPDFReal = 0
        CGPDFScannerPopNumber(scanner, &res)
        return res
    }
    static func popName(_ scanner: CGPDFScannerRef) ->  UnsafePointer<Int8>? {
        var res: UnsafePointer<Int8>? = UnsafePointer<Int8>(bitPattern: 0)
        CGPDFScannerPopName(scanner, &res)
        return res
    }


    static func getNumericalValue(_ pdfObject: CGPDFObjectRef, type: CGPDFObjectType) -> CGFloat {
        if (type == CGPDFObjectType.real) {
            var tx: CGPDFReal = 0.0
            CGPDFObjectGetValue(pdfObject, type, &tx);
            return tx
        }
        else if (type == CGPDFObjectType.integer) {
            var tx: CGPDFInteger = 0
            CGPDFObjectGetValue(pdfObject, type, &tx);
            return CGFloat(tx)
        }

        return 0.0
    }

    static func popTransform(_ scanner: CGPDFScannerRef) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        transform.ty = popNumber(scanner)
        transform.tx = popNumber(scanner)
        transform.d = popNumber(scanner)
        transform.c = popNumber(scanner)
        transform.b = popNumber(scanner)
        transform.a = popNumber(scanner)
        return transform
    }

    static func getObject(_ pdfArray: CGPDFArrayRef, _ index: Int) ->
        CGPDFObjectRef?  {
            var res: CGPDFObjectRef?
            CGPDFArrayGetObject(pdfArray, index, &res)
            return res
    }


    static func getFontCollection(_ dictionary: CGPDFDictionaryRef) -> PDFFontCollection {
        let res = PDFFontCollection()
        let resPtr = Unmanaged.passUnretained(res).toOpaque()

        CGPDFDictionaryApplyFunction(dictionary, { (key, object, collectionPtr) in
            var dict: CGPDFDictionaryRef?
            let collection: PDFFontCollection = Unmanaged.fromOpaque(collectionPtr!).takeUnretainedValue()
            guard
                CGPDFObjectGetType(object) == CGPDFObjectType.dictionary,
                CGPDFObjectGetValue(object, CGPDFObjectType.dictionary, &dict),
                let font = Parser.getFont(dict),
                let name = String.decodePDFInt8CString(key) else { return }
            collection.fonts[name] = font

        }, resPtr)

        return res
    }

    static func getFont(_ dictionary: CGPDFDictionaryRef? ) -> PDFFont? {
        guard let dictionary = dictionary else { return nil }

        var dicTypePtr : UnsafePointer<Int8>? = nil
            CGPDFDictionaryGetName(dictionary, "Type", &dicTypePtr)

        let dicType = String.decodePDFInt8CString(dicTypePtr)
        guard dicType == "Font" else { return nil }

        var dicSubtypePtr : UnsafePointer<Int8>? = nil
        CGPDFDictionaryGetName(dictionary, "Subtype", &dicSubtypePtr)
        if let dicSubtype = dicSubtypePtr {
            let subtype = String.decodePDFInt8CString(dicSubtype)
            switch subtype {
            case "Type0":
                return PDFType0Font(pdfDictionary: dictionary)
            case "Type1":
                return PDFType1Font(pdfDictionary: dictionary)
            case "MMType1":
                return PDFMMType1Font(pdfDictionary: dictionary)
            case "Type3":
                return PDFType3Font(pdfDictionary: dictionary)
            case "TrueType":
                return PDFTrueTypeFont(pdfDictionary: dictionary)
            case "CIDFontType0":
                return PDFCIDType0Font(pdfDictionary: dictionary)
            case "CIDFontType2":
                return PDFCIDType2Font(pdfDictionary: dictionary)
            default: break
            }
        }

        return PDFFont(pdfDictionary: dictionary)
    }

    static func didScanString(_ pdfString: CGPDFStringRef?, parser: Parser) {
        guard let pdfString = pdfString else { return }

        let renderingState = parser.renderingState
        let (str, characterIds) = renderingState.font.string(from: pdfString)
        parser.log( "didScanString \(str)")

        let (deviceSpaceFrame, textMatrixTranslation) = renderingState.deviceSpaceFrame(forCharacters:characterIds)

        parser.indexer.didScanTextBlock(
            TextBlock( chars: str,
                       characterIds: characterIds,
                       renderingState: renderingState,
                       frame:deviceSpaceFrame))
        renderingState.translateTextMatrix(by: CGSize(width: textMatrixTranslation.width, height:0))
    }

    static func didScanNewLine(scanner: CGPDFScannerRef, parser: Parser, persistLeading: Bool) {
        var tx: CGPDFReal = 0
        var ty: CGPDFReal = 0
        CGPDFScannerPopNumber(scanner, &ty);
        CGPDFScannerPopNumber(scanner, &tx);
        parser.renderingState.newLine(leading:ty, indent:tx, save:persistLeading)
    }

    static func didScanPositionAdjustment(value: CGFloat, parser: Parser) {
        guard let renderingState = parser.renderingStateStack.last else { return }
        parser.log("didScanPositionAdjustment : \(value)")
        renderingState.translateTextMatrix(by: CGSize(
            width: renderingState.convertHorizontalGlyphSpaceToTextSpace(-value) * renderingState.fontSize * renderingState.textMatrix.a,
            height:0))
    }



    //Parsing callbacks
    static func newLine( scanner : CGPDFScannerRef, parser: Parser){
        parser.renderingState.newLine()
    }

    static func printString( scanner : CGPDFScannerRef, parser: Parser) {
           didScanString(popString(scanner), parser: parser)
    }

    static func printStringNewLine( scanner : CGPDFScannerRef, parser: Parser) {
        newLine(scanner: scanner, parser: parser)
        printString(scanner: scanner, parser: parser)
    }

    static func printStringNewLineSetSpacing( scanner : CGPDFScannerRef, parser:Parser) {
        setWordSpacing(scanner: scanner, parser: parser)
        setCharacterSpacing(scanner: scanner, parser: parser)
        printStringNewLine(scanner: scanner, parser: parser);
    }

    static func printStringsAndSpaces( scanner : CGPDFScannerRef, parser: Parser) {
        guard let array = popArray(scanner) else { return }
        for  i in 0 ..< CGPDFArrayGetCount(array) {
            guard let pdfObject = getObject(array, i) else { continue }
            let valueType = CGPDFObjectGetType(pdfObject)

            if (valueType == CGPDFObjectType.string) {
                didScanString(getStringValue(pdfObject), parser:parser);
            }
            else {
                didScanPositionAdjustment(value: getNumericalValue(pdfObject, type: valueType), parser: parser);
            }
        }
    }
    static func setTextMatrix( scanner : CGPDFScannerRef, parser : Parser) {
        parser.log( "didScan Tm")
        parser.renderingState.setTextMatrix(popTransform(scanner), replaceLineMatrix:true)
    }
    static func newLineSetLeading( scanner : CGPDFScannerRef, parser : Parser) {
        didScanNewLine(scanner:scanner, parser: parser, persistLeading: true)
    }

    static func setWordSpacing( scanner : CGPDFScannerRef, parser : Parser){
        parser.renderingState.wordSpacing = popNumber(scanner)
    }

    static func setCharacterSpacing( scanner : CGPDFScannerRef, parser : Parser){
        parser.renderingState.characterSpacing = popNumber(scanner)
    }

    static func newLineWithLeading( scanner : CGPDFScannerRef, parser : Parser){
        didScanNewLine(scanner: scanner, parser: parser, persistLeading: false)
    }

    static func setTextLeading( scanner : CGPDFScannerRef, parser : Parser){
        parser.renderingState.leading = popNumber(scanner)
    }

    static func setHorizontalScale( scanner : CGPDFScannerRef, parser : Parser){
        parser.renderingState.horizontalScaling = popNumber(scanner) / 100
    }

    static func setTextRise( scanner : CGPDFScannerRef, parser : Parser){
        parser.renderingState.textRise = popNumber(scanner)
    }

    static func setFont( scanner : CGPDFScannerRef, parser : Parser){
        let fontSize: CGPDFReal = popNumber(scanner)

        guard
            let pdfFontName = popName(scanner),
            let fontName = String.decodePDFInt8CString(pdfFontName) else {
            parser.log("Invalid font name in font with size \(fontSize) \n")
            return
        }

        let renderingState = parser.renderingState
        guard let font = parser.fontCollection.fonts[fontName] else {
            parser.log("unknown font \(fontName) \n")
            return
        }
        renderingState.font = font
        renderingState.fontSize = fontSize
    }

    static func applyTransformation( scanner : CGPDFScannerRef, parser : Parser){
        let renderingState = parser.renderingState
        renderingState.ctm = renderingState.ctm.concatenating(popTransform(scanner))
        parser.log ("ctm => \(renderingState.ctm)")
    }
    
    static func pushRenderingState( scanner : CGPDFScannerRef, parser : Parser){
        parser.renderingStateStack.append(PDFRenderingState(state: parser.renderingState))

    }
    static func popRenderingState( scanner : CGPDFScannerRef,parser : Parser){
        parser.log("popRenderingState")
        _ = parser.renderingStateStack.popLast()
    }
    static func newParagraph( scanner : CGPDFScannerRef, parser : Parser){
        parser.renderingState.setTextMatrix(CGAffineTransform.identity, replaceLineMatrix: true)
    }
}

