//
//  JSONDocument.swift
//  LifeHub
//

import SwiftUI
import UniformTypeIdentifiers

/// A minimal `FileDocument` wrapping raw JSON — used by the backup exporter.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
