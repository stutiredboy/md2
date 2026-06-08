import Foundation
import Testing
@testable import MD2App
@testable import MD2Core

@MainActor
struct DocumentStoreTests {
    @Test func newStoreIsReusableEmptyDocument() {
        let store = DocumentStore()

        #expect(store.isReusableEmptyDocument)
        #expect(store.fileURL == nil)
        #expect(!store.isDirty)
        #expect(store.displayTitle == "Untitled.md")
    }

    @Test func editingMarksDirtyAndNotReusable() {
        let store = DocumentStore()
        store.text = "# Changed\n\nNew body."

        #expect(store.isDirty)
        #expect(!store.isReusableEmptyDocument)
        #expect(store.displayTitle == "Untitled.md *")
    }

    @Test func reassigningSameTextDoesNotMarkDirty() {
        let store = DocumentStore()
        store.text = store.text

        #expect(!store.isDirty)
        #expect(store.isReusableEmptyDocument)
    }

    @Test func renderedDocumentTracksTextChanges() {
        let store = DocumentStore()
        store.text = "# Heading One\n\nSome words here."

        #expect(store.rendered.outline.first?.title == "Heading One")
        #expect(store.rendered.html.contains("Heading One"))
        #expect(store.rendered.stats.words > 0)
    }
}
