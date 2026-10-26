import Flutter
import UIKit

/// Files shared into Recettas from other apps, on their way to Arquivos.
///
/// There is no share extension here. An extension can only hand bytes to
/// the app through an App Group, and App Groups need a paid Apple
/// Developer account. Instead Recettas declares itself a handler for
/// `public.data` (CFBundleDocumentTypes in Info.plist), so it shows up in
/// the share sheet's app row: iOS copies the shared file into
/// `Documents/Inbox/` and launches us.
///
/// Dart pulls instead of being pushed to - on startup and on every resume
/// - so a file that lands before the engine is up is picked up on the
/// next pass rather than dropped.
final class IncomingFiles: NSObject {
  static let shared = IncomingFiles()

  private static let channelName = "recettas/incoming_files"

  /// Retained for the life of the app: the messenger only keeps a weak
  /// handle on the channel's connection.
  private var channel: FlutterMethodChannel?

  /// URLs handed over by the scene delegate and not yet drained. Touched
  /// from the scene callbacks and the channel handler, both on the main
  /// thread, but locked so a background drain stays safe.
  private var pending: [URL] = []
  private let lock = NSLock()

  private override init() {
    super.init()
  }

  // MARK: - Wiring

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "takePending":
        result(self?.drain() ?? [])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// Both entry points the scene delegate has: the URLs a cold launch
  /// carried, and a share into the already-running app.
  func absorb(_ contexts: Set<UIOpenURLContext>) {
    let urls = contexts.map(\.url).filter(\.isFileURL)
    guard !urls.isEmpty else { return }
    lock.lock()
    pending.append(contentsOf: urls)
    lock.unlock()
  }

  // MARK: - Draining

  /// Everything waiting, as `{name, bytes}` maps. The files are deleted
  /// as they're read: the bytes are handed to Dart in the same call, so
  /// an upload that then fails is reported there rather than retried
  /// from disk.
  private func drain() -> [[String: Any]] {
    lock.lock()
    var urls = pending
    pending = []
    lock.unlock()

    // Everything we're handed is copied to Inbox anyway, so sweeping it
    // as well means a missed open callback still gets the file through.
    var seen = Set(urls.map(\.standardizedFileURL.path))
    for url in inboxContents() where seen.insert(url.standardizedFileURL.path).inserted {
      urls.append(url)
    }

    return urls.compactMap(read)
  }

  private func inboxContents() -> [URL] {
    let fm = FileManager.default
    guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return [] }
    let inbox = documents.appendingPathComponent("Inbox", isDirectory: true)
    let found = try? fm.contentsOfDirectory(
      at: inbox, includingPropertiesForKeys: [.isRegularFileKey])
    return (found ?? []).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
  }

  private func read(_ url: URL) -> [String: Any]? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    guard let data = try? Data(contentsOf: url) else {
      NSLog("Recettas: could not read shared file at \(url.lastPathComponent)")
      return nil
    }
    try? FileManager.default.removeItem(at: url)
    return [
      "name": url.lastPathComponent,
      "bytes": FlutterStandardTypedData(bytes: data),
    ]
  }
}
