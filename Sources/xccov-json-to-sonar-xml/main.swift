import XMLCoder
import Foundation
import ArgumentParser

struct Converter: ParsableCommand {

    @Option(name: .long, help: "Path to .xcresult file")
    var xcresultPath: String

    @Option(name: .long, help: "Path to output file")
    var outputFile: String

    @Option(name: .long, help: "Pattern to match against file names and include only that will match")
    var filenameFilter: String?

    @Option(name: .long, help: "Prefix to strip from the begining of filepath to make it relative (must begin and end with '/')")
    var relativePathPrefix: String?

    @Flag(name: .short, help: "Whether to filter also files out of relative path prefix or not")
    var filterFilesOutOfRelativePathPrefix = false

    mutating func run() throws {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.arguments = ["xcrun", "xccov", "view", "--archive", "--json", xcresultPath]
        task.launchPath = "/usr/bin/env"
        task.standardInput = nil
        task.standardError = nil
        task.launch()

        print("Loading xcresult file...", terminator: "")

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        print(" done")
        print("Decoding JSON...", terminator: "")

        var json = try JSONDecoder().decode([String: [JsonLineCoverage]].self, from: data)

        print(" done")

        if let filenameFilter {
            print("Filtering files...", terminator: "")
            guard let regex = try? NSRegularExpression(pattern: filenameFilter) else {
                throw Error.invalidFilterPattern
            }
            json = json.filter { (filename, _) in
                regex.numberOfMatches(
                    in: filename,
                    range: NSRange(filename.startIndex..<filename.endIndex, in: filename)
                ) > 0
            }
            print(" done")
        }

        if let relativePathPrefix {
            print("Stripping prefix...", terminator: "")
            guard relativePathPrefix.prefix(1) == "/", relativePathPrefix.suffix(1) == "/" else {
                throw Error.invalidRelativePathPrefix
            }
            json = Dictionary(
                uniqueKeysWithValues: try json.compactMap { (filename, coverage) in
                    guard filename.hasPrefix(relativePathPrefix) else {
                        if filterFilesOutOfRelativePathPrefix {
                            return nil
                        }
                        throw Error.fileOutOfRelativePathPrefix(filename)
                    }
                    return (String(filename.dropFirst(relativePathPrefix.count)), coverage)
                }
            )
            print(" done")
        }

        print("Converting...", terminator: "")

        let xml = XmlProjectCoverage(
            files: json.map { (filename, lines) in
                XmlFileCoverage(
                    filename: filename,
                    lines: lines.filter { line in
                        line.isExecutable
                    } .map { line in
                        XmlLineCoverage(
                            lineNumber: line.line,
                            covered: line.executed,
                            branchesToCover: line.subranges?.count.advanced(by: 1),
                            coveredBranches: line.subranges?.filter { $0.executionCount > 0 }.count.advanced(by: line.executed ? 1 : 0)
                        )
                    }
                )
            }


        )

        print(" done")
        print("Encoding XML...", terminator: "")

        let xmlData = try XMLEncoder().encode(xml, withRootKey: "coverage", rootAttributes: ["version": "1"])

        print(" done")
        print("Writing XML to file...", terminator: "")

        try xmlData.write(to: URL(fileURLWithPath: outputFile), options: .atomic)

        print(" done")
    }

    mutating func validate() throws {
        guard FileManager.default.isReadableFile(atPath: xcresultPath) else {
            throw Error.invalidInputFile
        }
    }

    enum Error: Swift.Error {
        case invalidInputFile
        case invalidFilterPattern
        case invalidRelativePathPrefix
        case fileOutOfRelativePathPrefix(String)
    }

    struct JsonLineCoverage: Decodable {
        let line: Int
        let isExecutable: Bool
        let executionCount: Int?
        let subranges: [Subrange]?

        var executed: Bool {
            executionCount ?? 0 > 0
        }
    }

    struct Subrange: Decodable {
        let column: Int
        let executionCount: Int
        let length: Int
    }

    struct XmlLineCoverage: Encodable, DynamicNodeEncoding {
        let lineNumber: Int
        let covered: Bool
        let branchesToCover: Int?
        let coveredBranches: Int?

        static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
            .attribute
        }
    }

    struct XmlFileCoverage: Encodable, DynamicNodeEncoding {
        let filename: String
        let lines: [XmlLineCoverage]

        enum CodingKeys: String, CodingKey {
            case filename = "path"
            case lines = "lineToCover"
        }

        static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
            switch key {
            case XmlFileCoverage.CodingKeys.filename: return .attribute
            default: return .element
            }
        }
    }

    struct XmlProjectCoverage: Encodable, DynamicNodeEncoding {
        let files: [XmlFileCoverage]

        enum CodingKeys: String, CodingKey {
            case files = "file"
        }

        static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
            .element
        }
    }

}

Converter.main()
