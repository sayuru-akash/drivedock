import Foundation
import AppKit

struct FileDropHandler {
    static let maxFileCount = 50_000

    struct ScanProgress {
        var filesScanned: Int
        var totalSize: Int64
        var isComplete: Bool
    }

    static func processDroppedItems(
        _ urls: [URL],
        progressCallback: ((ScanProgress) -> Void)? = nil
    ) -> [LocalFileInfo] {
        let fileManager = FileManager.default
        var files: [LocalFileInfo] = []
        let settings = AppSettings.shared

        for url in urls {
            guard files.count < maxFileCount else { break }

            let path = url.path

            guard fileManager.fileExists(atPath: path) else { continue }

            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                let folderFiles = scanFolder(path: path, settings: settings, currentCount: files.count, progressCallback: progressCallback)
                files.append(contentsOf: folderFiles)
            } else {
                guard let file = processSingleFile(at: url, settings: settings) else { continue }
                files.append(file)
                progressCallback?(ScanProgress(filesScanned: files.count, totalSize: files.reduce(0) { $0 + $1.fileSize }, isComplete: false))
            }
        }

        progressCallback?(ScanProgress(filesScanned: files.count, totalSize: files.reduce(0) { $0 + $1.fileSize }, isComplete: true))
        return files
    }

    private static func processSingleFile(at url: URL, settings: AppSettings) -> LocalFileInfo? {
        let fileManager = FileManager.default
        let path = url.path
        let fileName = url.lastPathComponent

        if settings.ignoreDSStore && fileName == ".DS_Store" { return nil }
        if settings.ignoreHiddenFiles && fileName.hasPrefix(".") { return nil }

        let resolvedPath = resolveSymlinks(path: path)

        guard fileManager.isReadableFile(atPath: resolvedPath) else { return nil }

        do {
            let attrs = try fileManager.attributesOfItem(atPath: resolvedPath)
            let fileSize = attrs[.size] as? Int64 ?? 0
            let mimeType = MIMETypeDetector.mimeType(for: fileName)

            return LocalFileInfo(
                fileName: fileName,
                filePath: resolvedPath,
                fileSize: fileSize,
                mimeType: mimeType,
                relativePath: nil
            )
        } catch {
            return nil
        }
    }

    static func scanFolder(
        path: String,
        settings: AppSettings,
        currentCount: Int = 0,
        progressCallback: ((ScanProgress) -> Void)? = nil
    ) -> [LocalFileInfo] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return [] }

        var files: [LocalFileInfo] = []
        var runningSize: Int64 = 0
        var scanCount = 0

        while let relativePath = enumerator.nextObject() as? String {
            guard files.count + currentCount < maxFileCount else { break }

            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            let fileName = (fullPath as NSString).lastPathComponent

            if settings.ignoreDSStore && fileName == ".DS_Store" { continue }
            if settings.ignoreHiddenFiles && fileName.hasPrefix(".") { continue }

            let resolvedPath = resolveSymlinks(path: fullPath)

            guard fileManager.isReadableFile(atPath: resolvedPath) else { continue }

            guard let attrs = try? fileManager.attributesOfItem(atPath: resolvedPath),
                  let fileType = attrs[.type] as? FileAttributeType,
                  fileType == .typeRegular else { continue }

            let fileSize = attrs[.size] as? Int64 ?? 0
            let mimeType = MIMETypeDetector.mimeType(for: fileName)

            files.append(LocalFileInfo(
                fileName: fileName,
                filePath: resolvedPath,
                fileSize: fileSize,
                mimeType: mimeType,
                relativePath: relativePath
            ))
            runningSize += fileSize
            scanCount += 1

            if scanCount % 100 == 0 {
                progressCallback?(ScanProgress(
                    filesScanned: files.count + currentCount,
                    totalSize: runningSize,
                    isComplete: false
                ))
            }
        }

        return files
    }

    static func folderInfo(path: String) -> (fileCount: Int, totalSize: Int64) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return (0, 0) }

        var count = 0
        var size: Int64 = 0

        while let relativePath = enumerator.nextObject() as? String {
            guard count < maxFileCount else { break }

            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            let resolvedPath = resolveSymlinks(path: fullPath)

            if let attrs = try? fileManager.attributesOfItem(atPath: resolvedPath),
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
            guard count < maxFileCount else { break }

            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                let info = folderInfo(path: url.path)
                count += info.fileCount
                size += info.totalSize
            } else {
                let resolvedPath = resolveSymlinks(path: url.path)
                if let attrs = try? fileManager.attributesOfItem(atPath: resolvedPath) {
                    count += 1
                    size += (attrs[.size] as? Int64 ?? 0)
                }
            }
        }

        return (count, size)
    }

    private static func resolveSymlinks(path: String) -> String {
        let fileManager = FileManager.default
        guard let resolved = try? fileManager.destinationOfSymbolicLink(atPath: path) else {
            return path
        }
        if resolved.hasPrefix("/") {
            return resolved
        }
        return (path as NSString).deletingLastPathComponent + "/" + resolved
    }
}
