#  PDFParser
A pure Swift library for extracting text information from pdf files, such as text blocks with coordinates and font information. Also includes a true type font parser for glyph width computation.

Parsing code based on PDFKitten https://github.com/KurtCode/PDFKitten
TrueType parser based on  http://stevehanov.ca/blog/index.php?id=143

Parsing is done very simply, and returns TextBlocks structs, that can be later indexed by custom code.
A simple indexer is provided, assuming single column layout, aggregating words.

```Swift
var documentIndexer = SimpleDocumentIndexer()
let documentPath = Bundle.main.path(forResource: "Kurt the Cat", ofType: "pdf", inDirectory: nil, forLocalization: nil)

let parser = try! Parser(documentURL: URL(fileURLWithPath: documentPath!), delegate:self, indexer: documentIndexer)
parser.parse()
```

ViewController in the DemoApp displays UILabel for textblocks. This lets you see if the frames for the textblock returned by the parser is correct.

> This code is not ready for production. Use at your own risk.
> This code is probably way too unoptimized to be used for anything latency-sensitive. It was meant to be easy to understand and correct first and foremost. 
