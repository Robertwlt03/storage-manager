import Foundation
import Testing

@testable import StorageManager

/// The scanned tree, built by hand: no disk access, no real file names.
@Suite("Scanned tree")
struct TreeTests {
    private static let bigFile = ScanLimits.smallestListedBytes * 3
    private static let smallFile = ScanLimits.smallestListedBytes / 2

    private struct SampleTree {
        let root: Node
        let scanRoot: Node
        let media: Node
        let notes: Node
    }

    /// /scan/media with one big and one small file, and /scan/notes with one small file.
    private static func sampleTree() -> SampleTree {
        let root = Node.virtualRoot()
        let scanRoot = Node(name: "/scan", parent: root)
        let media = Node(name: "media", parent: scanRoot)
        media.addFile(bigFile) { "film.mov" }
        media.addFile(smallFile) { "note.txt" }
        media.finish()
        let notes = Node(name: "notes", parent: scanRoot)
        notes.addFile(smallFile) { "todo.txt" }
        notes.finish()
        scanRoot.adopt(media)
        scanRoot.adopt(notes)
        scanRoot.finish()
        scanRoot.attach(to: root)
        return SampleTree(root: root, scanRoot: scanRoot, media: media, notes: notes)
    }

    @Test("Big files are listed, small ones fold into one row")
    func smallFilesFold() {
        let media = Self.sampleTree().media
        #expect(media.files.map(\.name) == ["film.mov"])
        #expect(media.restCount == 1)
        #expect(media.restBytes == Self.smallFile)
        #expect(media.bytes == Self.bigFile + Self.smallFile)
    }

    @Test("Small folders fold into their parent's row, big ones stay")
    func smallFoldersFold() {
        let tree = Self.sampleTree()
        #expect(tree.scanRoot.children == [tree.media])
        #expect(tree.scanRoot.restCount == 1)
        #expect(tree.scanRoot.fileCount == 3)
    }

    @Test("Paths and the way back to the scan root")
    func paths() {
        let tree = Self.sampleTree()
        #expect(tree.media.path == "/scan/media")
        #expect(tree.media.nodesFromRoot == [tree.scanRoot, tree.media])
        #expect(tree.root.descendant(at: "/scan/media") === tree.media)
        #expect(tree.root.descendant(at: "/scan/missing") == nil)
    }

    @Test("Removing a folder subtracts its size from every folder above")
    func detachSubtracts() {
        let tree = Self.sampleTree()
        let sizeBefore = tree.scanRoot.bytes
        tree.media.detach()
        #expect(tree.scanRoot.bytes == sizeBefore - tree.media.bytes)
        #expect(tree.scanRoot.children.isEmpty)
    }

    @Test("A folder's contents list folders, files and the folded row")
    func contents() {
        let tree = Self.sampleTree()
        let entries = Entry.contents(of: tree.media)
        #expect(entries.count == 2)
        #expect(entries.last?.itemCount == 1)
        #expect(Entry.contents(of: tree.notes).allSatisfy { entry in entry.path == nil })
    }

    @Test("Search finds names in the chosen scope, biggest first")
    func search() {
        let root = Self.sampleTree().root
        #expect(SearchService.search("  ", scope: .all, in: root).isEmpty)
        let folders = SearchService.search("media", scope: .folders, in: root)
        #expect(folders.map(\.name) == ["media"])
        #expect(SearchService.search("media", scope: .files, in: root).isEmpty)
        #expect(SearchService.search("FILM", scope: .all, in: root).count == 1)
    }

    @Test("Large files are those at or above the threshold, biggest first")
    func largeFiles() {
        let root = Self.sampleTree().root
        #expect(SearchService.largeFiles(atLeast: Self.bigFile, in: root).count == 1)
        #expect(SearchService.largeFiles(atLeast: Self.bigFile + 1, in: root).isEmpty)
    }

    @Test("Attaching a folder adds its size to the new parent, clearing empties the tree")
    func attachAndClear() {
        let root = Node.virtualRoot()
        let scanRoot = TestTree.folder("/other", in: root)
        #expect(root.bytes == scanRoot.bytes)
        #expect(root.children == [scanRoot])
        root.removeAll()
        #expect(root.bytes == 0)
        #expect(root.children.isEmpty)
    }

    @Test("A path with ~ points into the home folder")
    func expandHome() {
        #expect(Paths.expand("~/Downloads") == Paths.home + "/Downloads")
        #expect(Paths.expand("/Applications") == "/Applications")
    }

    @Test("Only the home folder itself and what lies inside it are shown with ~")
    func homeShownWithTilde() {
        #expect(Paths.displayName(Paths.home + "/Downloads") == "~/Downloads")
        #expect(Paths.displayName(Paths.home + "-backup") == Paths.home + "-backup")
    }

    @Test("A folder or listed file has a size; a folded file has none")
    func entrySizes() {
        let tree = Self.sampleTree()
        #expect(tree.root.entryBytes(at: "/scan/media") == tree.media.bytes)
        #expect(tree.root.entryBytes(at: "/scan/media/film.mov") == Self.bigFile)
        #expect(tree.root.entryBytes(at: "/scan/media/note.txt") == nil)
    }

    @Test("A detached folder no longer changes the tree it left")
    func detachedFolderStaysOut() {
        let tree = Self.sampleTree()
        tree.media.detach()
        let bytesAfterFirstDetach = tree.scanRoot.bytes
        tree.media.detach()
        #expect(tree.media.parent == nil)
        #expect(tree.scanRoot.bytes == bytesAfterFirstDetach)
    }
}
