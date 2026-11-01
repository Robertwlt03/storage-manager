import Foundation
import Testing

@testable import StorageManager

/// What a click on a category shows: exactly the folders behind its size.
@Suite("Category folders")
struct CategoryTests {
    /// The home folder with two folders of one category, Pictures and Music.
    private static func homeTree() -> Node { TestTree.home(also: ["Pictures", "Music"]) }

    private static func category(_ kind: CategoryKind, in root: Node) throws
        -> StorageManager.Category
    {
        try #require(
            CategoryService.compute(root: root, volume: nil)
                .first { category in
                    category.kind == kind
                })
    }

    @Test("A category opens under its own name and lists a whole folder as that very folder")
    func wholeFolder() throws {
        let root = Self.homeTree()
        let caches = try Self.category(.caches, in: root)
        let page = try #require(CategoryService.folder(of: caches))
        #expect(page.isGroup && page.displayName == CategoryKind.caches.title.translated)
        let folder = try #require(page.children.first)
        #expect(root.holds(folder))
        #expect(page.bytes == caches.bytes)
    }

    @Test("A folder that holds other categories opens without them, sized like its category")
    func folderWithoutOtherKinds() throws {
        let root = Self.homeTree()
        let user = try Self.category(.user, in: root)
        let folder = try #require(CategoryService.folder(of: user)?.children.first)
        #expect(!root.holds(folder) && !folder.isGroup)
        #expect(folder.bytes == user.bytes)
        #expect(folder.path == Paths.expand("~"))
        // Library stays for its own file, without Caches; Downloads, Pictures and Music go.
        #expect(folder.children.map(\.name).sorted() == ["Library", "Projects"])
    }

    @Test("A category of several folders lists them all, sized like the category")
    func severalFolders() throws {
        let root = Self.homeTree()
        let media = try Self.category(.media, in: root)
        let group = try #require(CategoryService.folder(of: media))
        #expect(group.isGroup && !group.listsAreas)
        #expect(group.displayName == CategoryKind.media.title.translated)
        #expect(group.bytes == media.bytes)
        #expect(group.children.map(\.name).sorted() == ["Music", "Pictures"])
    }
}
