import Foundation
import UniformTypeIdentifiers

struct MIMETypeDetector {
    static func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()

        let mimeMap: [String: String] = [
            "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "gif": "image/gif", "webp": "image/webp", "svg": "image/svg+xml",
            "bmp": "image/bmp", "tiff": "image/tiff", "tif": "image/tiff",
            "ico": "image/x-icon", "heic": "image/heic", "heif": "image/heif",
            "mp4": "video/mp4", "mov": "video/quicktime", "avi": "video/x-msvideo",
            "mkv": "video/x-matroska", "wmv": "video/x-ms-wmv", "flv": "video/x-flv",
            "webm": "video/webm", "m4v": "video/x-m4v", "mpg": "video/mpeg",
            "mp3": "audio/mpeg", "wav": "audio/wav", "flac": "audio/flac",
            "aac": "audio/aac", "ogg": "audio/ogg", "m4a": "audio/mp4",
            "wma": "audio/x-ms-wma",
            "pdf": "application/pdf",
            "doc": "application/msword", "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel", "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt": "application/vnd.ms-powerpoint", "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "txt": "text/plain", "rtf": "application/rtf", "csv": "text/csv",
            "html": "text/html", "htm": "text/html", "css": "text/css",
            "js": "application/javascript", "json": "application/json",
            "xml": "application/xml", "yaml": "application/x-yaml", "yml": "application/x-yaml",
            "md": "text/markdown",
            "zip": "application/zip", "rar": "application/vnd.rar", "7z": "application/x-7z-compressed",
            "tar": "application/x-tar", "gz": "application/gzip",
            "dmg": "application/x-apple-diskimage", "iso": "application/x-iso9660-image",
            "exe": "application/vnd.microsoft.portable-executable",
            "apk": "application/vnd.android.package-archive",
            "psd": "image/vnd.adobe.photoshop", "ai": "application/postscript",
            "sketch": "application/x-sketch", "fig": "application/x-figma",
            "swift": "text/x-swift", "py": "text/x-python", "rb": "text/x-ruby",
            "java": "text/x-java-source", "c": "text/x-c", "cpp": "text/x-c++",
            "h": "text/x-c", "hpp": "text/x-c++", "go": "text/x-go",
            "rs": "text/x-rust", "sh": "application/x-sh",
            "ttf": "font/ttf", "otf": "font/otf", "woff": "font/woff", "woff2": "font/woff2"
        ]

        if let mime = mimeMap[ext] {
            return mime
        }

        if let utType = UTType(filenameExtension: ext),
           let preferredMIME = utType.preferredMIMEType {
            return preferredMIME
        }

        return "application/octet-stream"
    }

    static func isImageFile(_ fileName: String) -> Bool {
        mimeType(for: fileName).hasPrefix("image/")
    }

    static func isVideoFile(_ fileName: String) -> Bool {
        mimeType(for: fileName).hasPrefix("video/")
    }

    static func isAudioFile(_ fileName: String) -> Bool {
        mimeType(for: fileName).hasPrefix("audio/")
    }
}
