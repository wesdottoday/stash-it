import AppKit
import SwiftUI

struct PreferencesView: View {
    @StateObject private var model = PreferencesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Destination") {
                    HStack {
                        Text(model.destinationPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Choose…") { model.chooseFolder() }
                    }
                }

                Section("Global Hotkey") {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        KeyCaptureFieldRepresentable(
                            keyCode: $model.hotkeyKeyCode,
                            modifiers: $model.hotkeyModifiers
                        )
                        .frame(width: 180, height: 26)
                    }
                }

                Section("Save Confirmation") {
                    Toggle("Show checkmark on save", isOn: $model.confirmationEnabled)
                    HStack {
                        Text("Duration")
                        Slider(
                            value: Binding(
                                get: { Double(model.confirmationDuration) },
                                set: { model.confirmationDuration = Int($0) }
                            ),
                            in: 50...2000,
                            step: 10
                        )
                        Text("\(model.confirmationDuration) ms")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 70, alignment: .trailing)
                    }
                    .disabled(!model.confirmationEnabled)
                }

                Section("Files") {
                    Toggle(
                        "Normalize filenames and convert non-PNG/JPEG images to PNG",
                        isOn: $model.imageNormalization
                    )
                }

                Section("General") {
                    Toggle("Start at login", isOn: $model.startAtLogin)
                }

                Section("Menu Bar") {
                    Toggle("Show menu bar icon", isOn: $model.menuBarEnabled)
                    if !model.menuBarEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Once dismissed, the menu bar icon is the only UI path to these preferences.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("To configure from the command line, see the README:")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Link(
                                "github.com/wesdottoday/stash-it",
                                destination: URL(string: "https://github.com/wesdottoday/stash-it")!
                            )
                            .font(.callout)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack(spacing: 6) {
                Text("We don't collect any data.")
                Link("source", destination: URL(string: "https://github.com/wesdottoday/stash-it")!)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(10)
        }
        .frame(minWidth: 500, minHeight: 500)
    }
}

final class PreferencesViewModel: ObservableObject {
    private let prefs = Preferences.shared

    @Published var destinationPath: String
    @Published var hotkeyKeyCode: UInt32 {
        didSet { prefs.hotkey = (hotkeyKeyCode, hotkeyModifiers) }
    }
    @Published var hotkeyModifiers: UInt32 {
        didSet { prefs.hotkey = (hotkeyKeyCode, hotkeyModifiers) }
    }
    @Published var confirmationEnabled: Bool {
        didSet { prefs.confirmationEnabled = confirmationEnabled }
    }
    @Published var confirmationDuration: Int {
        didSet { prefs.confirmationDuration = confirmationDuration }
    }
    @Published var imageNormalization: Bool {
        didSet { prefs.imageNormalization = imageNormalization }
    }
    @Published var menuBarEnabled: Bool {
        didSet { prefs.menuBarEnabled = menuBarEnabled }
    }
    @Published var startAtLogin: Bool {
        didSet { prefs.startAtLogin = startAtLogin }
    }

    init() {
        let p = Preferences.shared
        self.destinationPath = p.destinationFolder.path
        let h = p.hotkey
        self.hotkeyKeyCode = h.keyCode
        self.hotkeyModifiers = h.modifiers
        self.confirmationEnabled = p.confirmationEnabled
        self.confirmationDuration = p.confirmationDuration
        self.imageNormalization = p.imageNormalization
        self.menuBarEnabled = p.menuBarEnabled
        self.startAtLogin = p.startAtLogin
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.destinationFolder
        if panel.runModal() == .OK, let url = panel.url {
            prefs.destinationFolder = url
            destinationPath = url.path
        }
    }
}
