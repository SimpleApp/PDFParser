//
//  ViewController.swift
//  ParserDemoApp
//
//  Created by Benjamin Garrigues on 27/06/2018.
//

import UIKit

class ViewController: UIViewController {

    var documentIndexer = SimpleDocumentIndexer()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let documentPath = Bundle.main.path(forResource: "Kurt the Cat", ofType: "pdf", inDirectory: nil, forLocalization: nil)

        let parser = try! Parser(documentURL: URL(fileURLWithPath: documentPath!), delegate:self, indexer: documentIndexer)
        parser.parse()

        print( "Raw dump : \n")
        print(documentIndexer.pageIndexes[1]!.textBlocks)

        print( "\nLines : \n")
        print(documentIndexer.pageIndexes[1]!.allLinesDescription())
        showPage(pageIndex: documentIndexer.pageIndexes[1]!)
    }

    func showPage(pageIndex: SimpleDocumentIndexer.PageIndex) {
        /*for (_, l) in pageIndex.lines {
            showLine(l)
        }
        */
        for b in pageIndex.textBlocks {
            showBlock(b)
        }
    }

    func showLine(_ line: SimpleDocumentIndexer.LineTextBlock) {
        for b in line.blocks {
            showBlock(b)
        }
    }

    func showBlock(_ textBlock: TextBlock) {
        let lbl = UILabel(frame: textBlock.frame.insetBy(dx: 0, dy: -textBlock.renderingState.fontSize * 2).offsetBy(dx: 0, dy: textBlock.renderingState.fontSize))
        lbl.font = UIFont(name: "Baskerville", size: textBlock.renderingState.fontSize * textBlock.renderingState.textMatrix.a)
        lbl.backgroundColor = UIColor.clear
        lbl.lineBreakMode = .byClipping
        lbl.text = textBlock.chars
        lbl.textColor = UIColor.black
        self.view.addSubview(lbl)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController: ParserDelegate {
    func parser(p: Parser, didCompleteWithError error: Error?) {
        if let error = error {
            print(error)
        }
    }
}
