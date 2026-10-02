import Foundation
import Testing

@testable import RAWCore

@Test func adjustmentsRejectNonFiniteAndOutOfRangeValues() throws {
  var recipe = Adjustments()
  try recipe.validate()
  recipe.exposure = .nan
  #expect(throws: StudioError.invalidRecipe) { try recipe.validate() }
  recipe.exposure = 5
  #expect(throws: StudioError.invalidRecipe) { try recipe.validate() }
  recipe.exposure = 0
  recipe.temperature = 1000
  #expect(throws: StudioError.invalidRecipe) { try recipe.validate() }
}
@Test func invalidImportDoesNotCreateLibrary() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let file = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".dng")
  try Data("invalid".utf8).write(to: file)
  defer { try? FileManager.default.removeItem(at: file) }
  let library = RAWLibrary(root: root)
  await #expect(throws: StudioError.unsupported) { _ = try await library.importRAW(file) }
  #expect(!FileManager.default.fileExists(atPath: root.path))
}

@Test func realDNGDecodeSaveAndExport() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Fixtures/ColorChart.dng")
  let library = RAWLibrary(root: root)
  let original = try await library.importRAW(fixture)
  #expect(original.width == 256 && original.height == 192)
  let preview = try await library.preview(original)
  #expect(preview.width > 0 && preview.height > 0)
  var edited = original
  edited.adjustments.exposure = 1
  let saved = try await library.save(edited)
  #expect(saved.revision == 1)
  let reopened = try await RAWLibrary(root: root).projects()
  #expect(reopened.first?.adjustments.exposure == 1)
  await #expect(throws: StudioError.staleEdit) { _ = try await library.save(edited) }
  let jpeg = try await library.exportJPEG(saved)
  #expect(jpeg.starts(with: [0xff, 0xd8]))
  #expect(
    try Data(contentsOf: root.appendingPathComponent(original.filename))
      == Data(contentsOf: fixture))
}
