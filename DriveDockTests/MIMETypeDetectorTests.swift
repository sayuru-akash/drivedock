import XCTest
@testable import DriveDock

final class MIMETypeDetectorTests: XCTestCase {

    // MARK: - Image Types

    func testJPEGTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "photo.jpg"), "image/jpeg")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "photo.jpeg"), "image/jpeg")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "PHOTO.JPG"), "image/jpeg")
    }

    func testPNGType() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "image.png"), "image/png")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "IMAGE.PNG"), "image/png")
    }

    func testOtherImageTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "anim.gif"), "image/gif")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "pic.webp"), "image/webp")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "icon.svg"), "image/svg+xml")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "photo.bmp"), "image/bmp")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "scan.tiff"), "image/tiff")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "photo.heic"), "image/heic")
    }

    // MARK: - Video Types

    func testVideoTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "clip.mp4"), "video/mp4")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "movie.mov"), "video/quicktime")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "old.avi"), "video/x-msvideo")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "rip.mkv"), "video/x-matroska")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "clip.webm"), "video/webm")
    }

    // MARK: - Audio Types

    func testAudioTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "song.mp3"), "audio/mpeg")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "recording.wav"), "audio/wav")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "lossless.flac"), "audio/flac")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "podcast.aac"), "audio/aac")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "track.ogg"), "audio/ogg")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "song.m4a"), "audio/mp4")
    }

    // MARK: - Document Types

    func testDocumentTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "report.pdf"), "application/pdf")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "doc.doc"), "application/msword")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "notes.txt"), "text/plain")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "data.csv"), "text/csv")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "page.html"), "text/html")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "page.htm"), "text/html")
    }

    func testSpreadsheetTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "sheet.xls"), "application/vnd.ms-excel")
        XCTAssertEqual(
            MIMETypeDetector.mimeType(for: "sheet.xlsx"),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
    }

    func testPresentationTypes() {
        XCTAssertEqual(
            MIMETypeDetector.mimeType(for: "deck.ppt"),
            "application/vnd.ms-powerpoint"
        )
        XCTAssertEqual(
            MIMETypeDetector.mimeType(for: "deck.pptx"),
            "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        )
    }

    // MARK: - Archive Types

    func testArchiveTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "archive.zip"), "application/zip")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "archive.rar"), "application/vnd.rar")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "archive.7z"), "application/x-7z-compressed")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "archive.tar"), "application/x-tar")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "archive.gz"), "application/gzip")
    }

    // MARK: - Code Types

    func testCodeTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "main.swift"), "text/x-swift")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "script.py"), "text/x-python")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "app.rb"), "text/x-ruby")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "Main.java"), "text/x-java-source")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "main.c"), "text/x-c")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "main.cpp"), "text/x-c++")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "main.go"), "text/x-go")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "main.rs"), "text/x-rust")
    }

    // MARK: - Font Types

    func testFontTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "font.ttf"), "font/ttf")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "font.otf"), "font/otf")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "font.woff"), "font/woff")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "font.woff2"), "font/woff2")
    }

    // MARK: - macOS Specific Types

    func testMacOSTypes() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "app.dmg"), "application/x-apple-diskimage")
    }

    // MARK: - JSON and YAML

    func testJSONAndYAML() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "config.json"), "application/json")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "config.yaml"), "application/x-yaml")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "config.yml"), "application/x-yaml")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "readme.md"), "text/markdown")
    }

    // MARK: - Unknown Types

    func testUnknownTypeDefaultsToOctetStream() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "file.xyz"), "application/octet-stream")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "file.unknown123"), "application/octet-stream")
    }

    // MARK: - Detection Helpers

    func testIsImageFile() {
        XCTAssertTrue(MIMETypeDetector.isImageFile("photo.jpg"))
        XCTAssertTrue(MIMETypeDetector.isImageFile("image.png"))
        XCTAssertTrue(MIMETypeDetector.isImageFile("anim.gif"))
        XCTAssertFalse(MIMETypeDetector.isImageFile("video.mp4"))
        XCTAssertFalse(MIMETypeDetector.isImageFile("doc.pdf"))
    }

    func testIsVideoFile() {
        XCTAssertTrue(MIMETypeDetector.isVideoFile("clip.mp4"))
        XCTAssertTrue(MIMETypeDetector.isVideoFile("movie.mov"))
        XCTAssertTrue(MIMETypeDetector.isVideoFile("rip.mkv"))
        XCTAssertFalse(MIMETypeDetector.isVideoFile("photo.jpg"))
        XCTAssertFalse(MIMETypeDetector.isVideoFile("song.mp3"))
    }

    func testIsAudioFile() {
        XCTAssertTrue(MIMETypeDetector.isAudioFile("song.mp3"))
        XCTAssertTrue(MIMETypeDetector.isAudioFile("recording.wav"))
        XCTAssertTrue(MIMETypeDetector.isAudioFile("lossless.flac"))
        XCTAssertFalse(MIMETypeDetector.isAudioFile("photo.jpg"))
        XCTAssertFalse(MIMETypeDetector.isAudioFile("clip.mp4"))
    }

    // MARK: - Case Insensitivity

    func testCaseInsensitiveExtension() {
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "FILE.JPG"), "image/jpeg")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "FILE.PNG"), "image/png")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "FILE.PDF"), "application/pdf")
        XCTAssertEqual(MIMETypeDetector.mimeType(for: "FILE.MP4"), "video/mp4")
    }
}
