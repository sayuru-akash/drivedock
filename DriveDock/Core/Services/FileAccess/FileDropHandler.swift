import Foundation
import AppKit

struct FileDropHandler {
    static func processDroppedItems(_ urls: [URL]) -> [LocalFileInfo] {
        let fileManager = FileManager.default
        var files: [LocalFileInfo] = []
        let settings = AppSettings.shared

        for url in urls {
            let path = url.path

            guard fileManager.fileExists(atPath: path) else { continue }

            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                let folderFiles = scanFolder(path: path, settings: settings)
                files.append(contentsOf: folderFiles)
            } else {
                let fileName = url.lastPathComponent
                if settings.ignoreDSStore && fileName == ".DS_Store" { continue }
                if settings.ignoreHiddenFiles && fileName.hasPrefix(".") { continue }

                if let attrs = try? fileManager.attributesOfItem(atPath: path) {
                    let fileSize = attrs[.size] as? Int64 ?? 0
                    let mimeType = MIMETypeDetector.mimeType(for: fileName)

                    files.append(LocalFileInfo(
                        fileName: fileName,
                        filePath: path,
                        fileSize: fileSize,
                        mimeType: mimeType,
                        relativePath: nil
                    ))
                }
            }
        }

        return files
    }

    static func scanFolder(path: String, settings: AppSettings) -> [LocalFileInfo] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return [] }

        var files: [LocalFileInfo] = []

        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            let fileName = (fullPath as NSString).lastPathComponent

            if settings.ignoreDSStore && fileName == ".DS_Store" { continue }
            if settings.ignoreHiddenFiles && fileName.hasPrefix(".") { continue }

            guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                  let fileType = attrs[.type] as? FileAttributeType,
                  fileType == .typeRegular else { continue }

            let fileSize = attrs[.size] as? Int64 ?? 0
            let mimeType = MIMETypeDetector.mimeType(for: fileName)

            files.append(LocalFileInfo(
                fileName: fileName,
                filePath: fullPath,
                fileSize: fileSize,
                mimeType: mimeType,
                relativePath: relativePath
            ))
        }

        return files
    }

    static func folderInfo(path: String) -> (fileCount: Int, totalSize: Int64) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return (0, 0) }

        var count = 0
        var size: Int64 = 0

        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileType = attrs[.type] as? FileAttributeType,
               fileType == .typeRegular {
                count += 1
                size += (attrs[.size] as? Int64 ?? 0)
            }
        }

        return (count, size)
    }

    static func estimateTotalSize(_ urls: [URL]) -> (itemCount: Int, totalSize: Int64) {
        let fileManager = FileManager.default
        var count = 0
        var size: Int64 = 0

        for url in urls {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                let info = folderInfo(path: url.path)
                count += info.fileCount
                size += info.totalSize
            } else {
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path) {
                    count += 1
                    size += (attrs[.size] as? Int64 ?? 0)
                }
            }
        }

        return (count, size)
    }
}
