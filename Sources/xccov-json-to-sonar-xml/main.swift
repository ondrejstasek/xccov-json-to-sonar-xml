import XMLCoder
import Foundation
import ArgumentParser

struct Converter: ParsableCommand {

    @Option(help: "Path to .xcresult file")
    var xcresultPath: String

    @Option(help: "Path to output file")
    var outputFile: String

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

        let json = try JSONDecoder().decode([String: [JsonLineCoverage]].self, from: data)

        print(" done")
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
                            covered: line.executionCount ?? 0 > 0
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
    }

    struct JsonLineCoverage: Decodable {
        let line: Int
        let isExecutable: Bool
        let executionCount: Int?
    }

    struct XmlLineCoverage: Encodable, DynamicNodeEncoding {
        let lineNumber: Int
        let covered: Bool

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
