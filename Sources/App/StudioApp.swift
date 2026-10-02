import SwiftUI
import UniformTypeIdentifiers

@main struct StudioApp: App {
  var body: some Scene { WindowGroup { StudioView() }.defaultSize(width: 1100, height: 760) }
}
struct JPEGDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.jpeg] }
  let data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
@MainActor @Observable final class StudioModel {
  let library: RAWLibrary
  var projects: [RAWProject] = []
  var selected: RAWProject?
  var preview: CGImage?
  var before: CGImage?
  var error: String?
  var busy = false
  var saved = true
  private var task: Task<Void, Never>?
  private var token = UUID()
  init() {
    let name =
      ProcessInfo.processInfo.environment["RAW_TEST_STORE"].map { "RAWTests-" + $0 }
      ?? "RAW Photo Studio"
    library = RAWLibrary(root: URL.applicationSupportDirectory.appendingPathComponent(name))
  }
  func load() async {
    do { projects = try await library.projects() } catch { self.error = error.localizedDescription }
  }
  func select(_ project: RAWProject) {
    cancel()
    selected = project
    saved = true
    before = nil
    preview = nil
    render()
  }
  func cancel() {
    task?.cancel()
    token = UUID()
    busy = false
  }
  func importFile(_ url: URL) {
    cancel()
    busy = true
    let id = token
    task = Task {
      do {
        let project = try await library.importRAW(url)
        guard token == id, !Task.isCancelled else { return }
        projects = try await library.projects()
        select(project)
      } catch {
        if token == id && !Task.isCancelled {
          self.error = error.localizedDescription
          busy = false
        }
      }
    }
  }
  func change(_ value: Adjustments) {
    selected?.adjustments = value
    saved = false
    render()
  }
  func render() {
    cancel()
    guard let project = selected else { return }
    busy = true
    let id = token
    task = Task {
      do {
        try await Task.sleep(for: .milliseconds(180))
        let rendered = try await library.preview(project)
        let baseline = before == nil ? try await library.preview(project, original: true) : before
        guard token == id, selected?.id == project.id, !Task.isCancelled else { return }
        preview = rendered
        before = baseline
        busy = false
      } catch {
        if token == id && !Task.isCancelled {
          self.error = error.localizedDescription
          busy = false
        }
      }
    }
  }
  func save() async {
    guard let project = selected else { return }
    do {
      let result = try await library.save(project)
      guard selected?.id == project.id else { return }
      // Preserve edits made while the actor was writing the previous recipe.
      selected?.revision = result.revision
      saved = selected?.adjustments == result.adjustments
      projects = try await library.projects()
    } catch { self.error = error.localizedDescription }
  }
}
struct StudioView: View {
  @State private var model = StudioModel()
  @State private var importing = false
  @State private var compare = false
  @State private var exporting = false
  @State private var exportDocument: JPEGDocument?
  @State private var exportTask: Task<Void, Never>?
  @State private var exportBusy = false
  @State private var pendingSelection: RAWProject?
  @State private var confirmDiscard = false
  var body: some View {
    NavigationSplitView {
      List {
        ForEach(model.projects) { project in
          Button {
            if !model.saved {
              pendingSelection = project
              confirmDiscard = true
            } else {
              model.select(project)
            }
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(project.name).font(.headline)
              Text("\(project.width) × \(project.height)").font(.caption).foregroundStyle(
                .secondary)
            }
          }.buttonStyle(.plain).accessibilityIdentifier("raw-project-" + project.id.uuidString)
        }
      }.navigationTitle("RAW Studio").navigationSplitViewColumnWidth(min: 210, ideal: 250)
        .toolbar {
          Button("Import RAW", systemImage: "square.and.arrow.down") { importing = true }.disabled(
            !model.saved)
        }
    } detail: {
      if let project = model.selected {
        VStack(spacing: 0) {
          HStack {
            Text(project.name).font(.headline)
            Spacer()
            if model.busy {
              ProgressView().controlSize(.small)
              Button("Stop preview") { model.cancel() }
            }
            Toggle("Before", isOn: $compare).toggleStyle(.button).disabled(model.before == nil)
          }.padding()
          ZStack {
            Rectangle().fill(.black.opacity(0.9))
            if let image = compare ? model.before : model.preview {
              Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit).padding(
                16)
            } else {
              ContentUnavailableView("Preparing preview", systemImage: "camera.aperture")
            }
          }.frame(minHeight: 180)
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                Text("Adjustments").font(.title3.bold())
                Spacer()
                Text(model.saved ? "Saved" : "Unsaved changes").foregroundStyle(.secondary)
              }
              control("Exposure", key: \.exposure, range: -4...4, format: "%.1f EV")
              control("Temperature", key: \.temperature, range: 2000...50000, format: "%.0f K")
              control("Tint", key: \.tint, range: -150...150, format: "%.0f")
              control("Shadows", key: \.shadows, range: 0...2, format: "%.2f")
              control("Tone curve", key: \.boost, range: 0...1, format: "%.2f")
              HStack {
                Button("Reset adjustments") { model.change(project.initial) }
                Spacer()
              }
              Text("Decoder \(project.decoder) · Original preserved · JPEG export uses sRGB")
                .font(.caption).foregroundStyle(.secondary)
            }.padding()
          }.frame(maxHeight: 310)
        }.navigationTitle(project.name)
          .toolbar {
            Button("Save adjustments", systemImage: "checkmark") { Task { await model.save() } }
              .disabled(model.saved).keyboardShortcut("s")
            Button("Export JPEG", systemImage: "square.and.arrow.up") {
              exportTask?.cancel()
              exportBusy = true
              exportTask = Task {
                defer { exportBusy = false }
                do {
                  let data = try await model.library.exportJPEG(project)
                  try Task.checkCancellation()
                  exportDocument = JPEGDocument(data: data)
                  exporting = true
                } catch { if !Task.isCancelled { model.error = error.localizedDescription } }
              }
            }.disabled(exportBusy || model.preview == nil)
            if exportBusy { Button("Cancel export") { exportTask?.cancel() } }
          }
      } else {
        ContentUnavailableView(
          "Develop your originals", systemImage: "camera.aperture",
          description: Text(
            "Import a supported camera RAW or DNG. Adjustments are saved separately from the original."
          ))
      }
    }.task { await model.load() }
      .fileImporter(isPresented: $importing, allowedContentTypes: [.rawImage]) { result in
        switch result {
        case .success(let url): model.importFile(url)
        case .failure(let error): model.error = error.localizedDescription
        }
      }
      .fileExporter(
        isPresented: $exporting, document: exportDocument, contentType: .jpeg,
        defaultFilename: (model.selected?.name ?? "Developed") + "-edited"
      ) { result in
        if case .failure(let error) = result { model.error = error.localizedDescription }
        exportDocument = nil
      }
      .confirmationDialog("Discard unsaved adjustments?", isPresented: $confirmDiscard) {
        Button("Discard changes", role: .destructive) {
          if let pendingSelection { model.select(pendingSelection) }
        }
        Button("Keep editing", role: .cancel) {}
      }
      .alert(
        "Couldn't finish",
        isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
      ) {
        Button("OK") { model.error = nil }
      } message: {
        Text(model.error ?? "")
      }
      .onDisappear {
        model.cancel()
        exportTask?.cancel()
      }
  }
  private func control(
    _ title: String, key: WritableKeyPath<Adjustments, Float>, range: ClosedRange<Float>,
    format: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(title)
        Spacer()
        Text(String(format: format, model.selected?.adjustments[keyPath: key] ?? 0))
          .monospacedDigit().foregroundStyle(.secondary)
      }
      Slider(
        value: Binding(
          get: { model.selected?.adjustments[keyPath: key] ?? range.lowerBound },
          set: { value in
            guard var adjustments = model.selected?.adjustments else { return }
            adjustments[keyPath: key] = value
            model.change(adjustments)
          }), in: range
      ).accessibilityLabel(title)
    }
  }
}
