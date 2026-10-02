import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum StudioError: Error, LocalizedError {
  case unsupported, tooLarge, invalidRecipe, renderFailed, staleEdit
  public var errorDescription: String? {
    switch self {
    case .unsupported:
      "This file isn't a supported RAW image. Camera support depends on the system decoder."
    case .tooLarge: "Choose a RAW file up to 100 MB and 80 megapixels."
    case .invalidRecipe: "The saved adjustment recipe is invalid. Existing files were preserved."
    case .renderFailed:
      "The image couldn't be rendered. This camera may need system decoder resources."
    case .staleEdit: "This photo changed since it was opened. Reopen it before saving."
    }
  }
}
public struct Adjustments: Codable, Sendable, Equatable {
  public var exposure: Float = 0
  public var temperature: Float = 6500
  public var tint: Float = 0
  public var shadows: Float = 1
  public var boost: Float = 1
  public init() {}
  public func validate() throws {
    guard exposure.isFinite, (-4...4).contains(exposure),
      temperature.isFinite, (2000...50000).contains(temperature),
      tint.isFinite, (-150...150).contains(tint), shadows.isFinite, (0...2).contains(shadows),
      boost.isFinite, (0...1).contains(boost)
    else { throw StudioError.invalidRecipe }
  }
}
public struct RAWProject: Codable, Identifiable, Sendable, Equatable {
  public let id: UUID
  public let name: String
  public let filename: String
  public let created: Date
  public var revision: Int
  public let width: Int
  public let height: Int
  public let decoder: String
  public let initial: Adjustments
  public var adjustments: Adjustments
}
public actor RAWLibrary {
  public nonisolated let root: URL
  private let context = CIContext(options: [.cacheIntermediates: false])
  public init(root: URL) { self.root = root }
  public func projects() throws -> [RAWProject] {
    guard FileManager.default.fileExists(atPath: root.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "json" }.map { try read($0) }.sorted { $0.created > $1.created }
  }
  private func read(_ url: URL) throws -> RAWProject {
    let data = try Data(contentsOf: url)
    guard data.count < 100_000 else { throw StudioError.invalidRecipe }
    let value = try JSONDecoder().decode(RAWProject.self, from: data)
    guard value.filename == value.id.uuidString + ".raw", value.revision >= 0,
      value.width > 0, value.height > 0, Int64(value.width) * Int64(value.height) <= 80_000_000
    else { throw StudioError.invalidRecipe }
    try value.adjustments.validate()
    try value.initial.validate()
    return value
  }
  public func importRAW(_ url: URL) throws -> RAWProject {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 100_000_000 else {
      throw StudioError.tooLarge
    }
    let data = try Data(contentsOf: url)
    guard data.count <= 100_000_000 else { throw StudioError.tooLarge }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let type = CGImageSourceGetType(source), let contentType = UTType(type as String),
      contentType.conforms(to: .rawImage),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0
    else { throw StudioError.unsupported }
    guard Int64(width) * Int64(height) <= 80_000_000 else { throw StudioError.tooLarge }
    guard let filter = CIRAWFilter(imageData: data, identifierHint: type as String) else {
      throw StudioError.unsupported
    }
    var initial = Adjustments()
    initial.temperature = min(50000, max(2000, filter.neutralTemperature))
    initial.tint = min(150, max(-150, filter.neutralTint))
    initial.shadows = min(2, max(0, filter.boostShadowAmount))
    initial.boost = min(1, max(0, filter.boostAmount))
    try initial.validate()
    let id = UUID()
    let record = RAWProject(
      id: id, name: String(url.deletingPathExtension().lastPathComponent.prefix(200)),
      filename: id.uuidString + ".raw", created: Date(), revision: 0, width: width, height: height,
      decoder: filter.decoderVersion.rawValue, initial: initial, adjustments: initial)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let original = root.appendingPathComponent(record.filename)
    do {
      try data.write(to: original, options: .atomic)
      try JSONEncoder().encode(record).write(to: recipe(id), options: .atomic)
    } catch {
      try? FileManager.default.removeItem(at: original)
      throw error
    }
    return record
  }
  private func recipe(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString + ".json") }
  public func save(_ project: RAWProject) throws -> RAWProject {
    try project.adjustments.validate()
    let current = try read(recipe(project.id))
    guard current.revision == project.revision else { throw StudioError.staleEdit }
    var next = current
    next.adjustments = project.adjustments
    next.revision += 1
    try JSONEncoder().encode(next).write(to: recipe(next.id), options: .atomic)
    return next
  }
  private func image(_ project: RAWProject, original: Bool, maximum: Int) throws -> CIImage {
    try Task.checkCancellation()
    guard let filter = CIRAWFilter(imageURL: root.appendingPathComponent(project.filename)) else {
      throw StudioError.unsupported
    }
    let version = CIRAWDecoderVersion(rawValue: project.decoder)
    guard filter.supportedDecoderVersions.contains(version) else { throw StudioError.unsupported }
    filter.decoderVersion = version
    let a = original ? project.initial : project.adjustments
    try a.validate()
    filter.exposure = a.exposure
    filter.neutralTemperature = a.temperature
    filter.neutralTint = a.tint
    filter.boostShadowAmount = a.shadows
    filter.boostAmount = a.boost
    filter.scaleFactor = min(1, Float(maximum) / Float(max(project.width, project.height)))
    guard let image = filter.outputImage, !image.extent.isInfinite, !image.extent.isEmpty else {
      throw StudioError.renderFailed
    }
    return image
  }
  public func preview(_ project: RAWProject, original: Bool = false) throws -> CGImage {
    let image = try image(project, original: original, maximum: 1800)
    guard let output = context.createCGImage(image, from: image.extent) else {
      throw StudioError.renderFailed
    }
    try Task.checkCancellation()
    return output
  }
  public func exportJPEG(_ project: RAWProject) throws -> Data {
    let image = try image(project, original: false, maximum: max(project.width, project.height))
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let data = context.jpegRepresentation(
        of: image, colorSpace: space,
        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95])
    else { throw StudioError.renderFailed }
    try Task.checkCancellation()
    return data
  }
}
