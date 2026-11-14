import AppKit
import AVKit
import AVFoundation
import UniformTypeIdentifiers

private enum Palette {
    static let background = NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.082, alpha: 1)
    static let sidebar = NSColor(calibratedRed: 0.075, green: 0.086, blue: 0.11, alpha: 1)
    static let surface = NSColor(calibratedRed: 0.105, green: 0.12, blue: 0.15, alpha: 1)
    static let accent = NSColor(calibratedRed: 0.38, green: 0.47, blue: 1, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.56, green: 0.60, blue: 0.68, alpha: 1)
    static let text = NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.97, alpha: 1)
}

private struct DiscVolume {
    let url: URL
    let name: String
    let kind: String
}

@main
private enum PlayerEntry {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.regular)
        application.delegate = delegate
        application.run()
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Northstar Video Player"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 940, height: 600)
        window.center()
        window.contentViewController = PlayerViewController()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private final class PlayerViewController: NSViewController {
    private let player = AVPlayer()
    private let playerView = AVPlayerView()
    private let titleLabel = NSTextField(labelWithString: "Your films, in one place")
    private let detailLabel = NSTextField(labelWithString: "Open a video or browse an inserted disc")
    private let welcomeView = NSView()
    private let discStack = NSStackView()
    private var discButtons: [NSButton: DiscVolume] = [:]
    private var mainOpenButton: NSButton?
    private var itemObservation: NSKeyValueObservation?
    private var selectedURL: URL?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Palette.background.cgColor
        buildInterface()
        refreshDiscs()
    }

    private func buildInterface() {
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = Palette.sidebar.cgColor
        view.addSubview(sidebar)
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let main = NSView()
        main.wantsLayer = true
        main.layer?.backgroundColor = Palette.background.cgColor
        view.addSubview(main)
        main.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 245),
            main.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            main.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            main.topAnchor.constraint(equalTo: view.topAnchor),
            main.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        buildSidebar(sidebar)
        buildMain(main)
    }

    private func buildSidebar(_ sidebar: NSView) {
        let brandIcon = NSImageView(image: NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: nil)!)
        brandIcon.contentTintColor = Palette.accent
        brandIcon.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(brandIcon)

        let brand = NSTextField(labelWithString: "NORTHSTAR")
        styleLabel(brand, size: 12, weight: .bold, color: Palette.text)
        brand.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(brand)

        let subBrand = NSTextField(labelWithString: "VIDEO PLAYER")
        styleLabel(subBrand, size: 9, weight: .medium, color: Palette.muted)
        subBrand.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(subBrand)

        let open = makeButton("Open Video", icon: "plus", primary: true, action: #selector(openVideo))
        sidebar.addSubview(open)

        let libraryLabel = sectionLabel("LIBRARY")
        sidebar.addSubview(libraryLabel)
        let nowPlaying = makeButton("Now Playing", icon: "play.fill", action: #selector(showNowPlaying))
        sidebar.addSubview(nowPlaying)
        let openFile = makeButton("Open File…", icon: "folder", action: #selector(openVideo))
        sidebar.addSubview(openFile)

        let opticalLabel = sectionLabel("OPTICAL DISCS")
        sidebar.addSubview(opticalLabel)
        let refresh = makeButton("Refresh", icon: "arrow.clockwise", action: #selector(refreshDiscs))
        refresh.font = .systemFont(ofSize: 10, weight: .medium)
        refresh.contentTintColor = Palette.muted
        sidebar.addSubview(refresh)

        discStack.orientation = .vertical
        discStack.alignment = .leading
        discStack.spacing = 5
        discStack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(discStack)

        let footer = NSView()
        footer.wantsLayer = true
        footer.layer?.backgroundColor = Palette.surface.cgColor
        footer.layer?.cornerRadius = 10
        footer.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(footer)

        let footerTitle = NSTextField(labelWithString: "4K / UHD READY")
        styleLabel(footerTitle, size: 9, weight: .bold, color: Palette.text)
        footerTitle.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(footerTitle)
        let footerNote = NSTextField(wrappingLabelWithString: "Playback depends on your Mac's supported video codecs.")
        styleLabel(footerNote, size: 10, weight: .regular, color: Palette.muted)
        footerNote.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(footerNote)

        for item in [open, libraryLabel, nowPlaying, openFile, opticalLabel, discStack] {
            item.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            brandIcon.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            brandIcon.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 25),
            brandIcon.widthAnchor.constraint(equalToConstant: 25),
            brandIcon.heightAnchor.constraint(equalToConstant: 25),
            brand.leadingAnchor.constraint(equalTo: brandIcon.trailingAnchor, constant: 10),
            brand.topAnchor.constraint(equalTo: brandIcon.topAnchor, constant: 1),
            subBrand.leadingAnchor.constraint(equalTo: brand.leadingAnchor),
            subBrand.topAnchor.constraint(equalTo: brand.bottomAnchor, constant: 2),
            open.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            open.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16),
            open.topAnchor.constraint(equalTo: brandIcon.bottomAnchor, constant: 23),
            open.heightAnchor.constraint(equalToConstant: 39),
            libraryLabel.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            libraryLabel.topAnchor.constraint(equalTo: open.bottomAnchor, constant: 26),
            nowPlaying.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            nowPlaying.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            nowPlaying.topAnchor.constraint(equalTo: libraryLabel.bottomAnchor, constant: 8),
            nowPlaying.heightAnchor.constraint(equalToConstant: 32),
            openFile.leadingAnchor.constraint(equalTo: nowPlaying.leadingAnchor),
            openFile.trailingAnchor.constraint(equalTo: nowPlaying.trailingAnchor),
            openFile.topAnchor.constraint(equalTo: nowPlaying.bottomAnchor, constant: 2),
            openFile.heightAnchor.constraint(equalToConstant: 32),
            opticalLabel.leadingAnchor.constraint(equalTo: libraryLabel.leadingAnchor),
            opticalLabel.topAnchor.constraint(equalTo: openFile.bottomAnchor, constant: 26),
            refresh.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -14),
            refresh.centerYAnchor.constraint(equalTo: opticalLabel.centerYAnchor),
            discStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            discStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            discStack.topAnchor.constraint(equalTo: opticalLabel.bottomAnchor, constant: 9),
            footer.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 14),
            footer.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -14),
            footer.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -16),
            footerTitle.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 12),
            footerTitle.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -10),
            footerTitle.topAnchor.constraint(equalTo: footer.topAnchor, constant: 11),
            footerNote.leadingAnchor.constraint(equalTo: footerTitle.leadingAnchor),
            footerNote.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -10),
            footerNote.topAnchor.constraint(equalTo: footerTitle.bottomAnchor, constant: 6),
            footerNote.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -10)
        ])
    }

    private func buildMain(_ main: NSView) {
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = Palette.text
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = Palette.muted
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        let openButton = makeButton("Open", icon: "folder", action: #selector(openVideo))
        openButton.isHidden = true
        openButton.setAccessibilityIdentifier("main-open-button")
        mainOpenButton = openButton
        openButton.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(titleLabel)
        main.addSubview(detailLabel)
        main.addSubview(openButton)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(separator)

        let playerArea = NSView()
        playerArea.wantsLayer = true
        playerArea.layer?.backgroundColor = Palette.background.cgColor
        playerArea.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(playerArea)

        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        playerView.showsFrameSteppingButtons = true
        playerView.isHidden = true
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerArea.addSubview(playerView)

        buildWelcome(in: playerArea)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: main.topAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: openButton.leadingAnchor, constant: -12),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            openButton.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -22),
            openButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: main.trailingAnchor),
            separator.topAnchor.constraint(equalTo: main.topAnchor, constant: 70),
            separator.heightAnchor.constraint(equalToConstant: 1),
            playerArea.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            playerArea.trailingAnchor.constraint(equalTo: main.trailingAnchor),
            playerArea.topAnchor.constraint(equalTo: separator.bottomAnchor),
            playerArea.bottomAnchor.constraint(equalTo: main.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: playerArea.leadingAnchor, constant: 18),
            playerView.trailingAnchor.constraint(equalTo: playerArea.trailingAnchor, constant: -18),
            playerView.topAnchor.constraint(equalTo: playerArea.topAnchor, constant: 18),
            playerView.bottomAnchor.constraint(equalTo: playerArea.bottomAnchor, constant: -18)
        ])

    }

    private func buildWelcome(in container: NSView) {
        let icon = NSImageView(image: NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: nil)!)
        icon.contentTintColor = Palette.accent
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        let heading = NSTextField(labelWithString: "Make movie night yours.")
        styleLabel(heading, size: 25, weight: .semibold, color: Palette.text)
        let subtitle = NSTextField(labelWithString: "Play your video library or browse media on a mounted disc.")
        styleLabel(subtitle, size: 13, weight: .regular, color: Palette.muted)
        let choose = makeButton("Choose a video", icon: "folder", primary: true, action: #selector(openVideo))
        let note = NSTextField(labelWithString: "4K and UHD playback where supported by macOS and your hardware")
        styleLabel(note, size: 10, weight: .regular, color: Palette.muted)

        let group = NSStackView(views: [icon, heading, subtitle, choose, note])
        group.orientation = .vertical
        group.alignment = .centerX
        group.spacing = 13
        group.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(welcomeView)
        welcomeView.addSubview(group)
        NSLayoutConstraint.activate([
            welcomeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            welcomeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            welcomeView.topAnchor.constraint(equalTo: container.topAnchor),
            welcomeView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 120),
            icon.heightAnchor.constraint(equalToConstant: 100),
            choose.widthAnchor.constraint(equalToConstant: 170),
            choose.heightAnchor.constraint(equalToConstant: 39),
            group.centerXAnchor.constraint(equalTo: welcomeView.centerXAnchor),
            group.centerYAnchor.constraint(equalTo: welcomeView.centerYAnchor),
            group.leadingAnchor.constraint(greaterThanOrEqualTo: welcomeView.leadingAnchor, constant: 24),
            group.trailingAnchor.constraint(lessThanOrEqualTo: welcomeView.trailingAnchor, constant: -24)
        ])
    }

    private func styleLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        styleLabel(label, size: 9, weight: .bold, color: Palette.muted)
        return label
    }

    private func makeButton(_ title: String, icon: String, primary: Bool = false,
                            action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.alignment = .center
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor = (primary ? Palette.accent : Palette.surface).cgColor
        button.contentTintColor = Palette.text
        button.setAccessibilityLabel(title)
        return button
    }

    @objc private func openVideo() {
        let panel = NSOpenPanel()
        panel.title = "Open a video"
        panel.message = "Choose a video file to play."
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startPlayback(url)
    }

    @objc private func showNowPlaying() {
        guard selectedURL != nil else {
            openVideo()
            return
        }
        player.play()
    }

    @objc private func refreshDiscs() {
        let root = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        let volumes = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let discs = volumes.compactMap { url -> DiscVolume? in
            let children = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            let names = Set(children.map { $0.lastPathComponent.uppercased() })
            if names.contains("BDMV") {
                return DiscVolume(url: url, name: url.lastPathComponent, kind: "Blu-ray")
            }
            if names.contains("VIDEO_TS") {
                return DiscVolume(url: url, name: url.lastPathComponent, kind: "DVD")
            }
            return nil
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        discStack.arrangedSubviews.forEach {
            discStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        discButtons.removeAll()
        if discs.isEmpty {
            let empty = NSTextField(wrappingLabelWithString: "Insert a DVD or data disc to browse its video files.")
            styleLabel(empty, size: 11, weight: .regular, color: Palette.muted)
            discStack.addArrangedSubview(empty)
        } else {
            for disc in discs {
                let button = makeButton(disc.name, icon: "opticaldisc", action: #selector(openDisc(_:)))
                button.font = .systemFont(ofSize: 11, weight: .medium)
                button.alignment = .left
                button.toolTip = "Browse video files on \(disc.name)"
                discButtons[button] = disc
                discStack.addArrangedSubview(button)
                button.widthAnchor.constraint(equalTo: discStack.widthAnchor).isActive = true
                button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            }
        }
    }

    @objc private func openDisc(_ sender: NSButton) {
        guard let disc = discButtons[sender] else { return }
        let panel = NSOpenPanel()
        panel.title = "Browse \(disc.name)"
        panel.message = "Choose a video file from the mounted disc."
        panel.directoryURL = disc.url
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startPlayback(url)
    }

    private func startPlayback(_ url: URL) {
        selectedURL = url
        let item = AVPlayerItem(url: url)
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                self?.showPlaybackError(item.error)
            }
        }
        player.replaceCurrentItem(with: item)
        playerView.isHidden = false
        welcomeView.isHidden = true
        titleLabel.stringValue = url.deletingPathExtension().lastPathComponent
        detailLabel.stringValue = url.deletingLastPathComponent().path
        mainOpenButton?.isHidden = false
        player.play()
    }

    private func showPlaybackError(_ error: Error?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This video couldn't be played"
        alert.informativeText = error?.localizedDescription
            ?? "The file may use a video codec that isn't supported by macOS."
        alert.addButton(withTitle: "OK")
        if let window = view.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
