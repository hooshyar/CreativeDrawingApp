//
//  AnimationPreviewController.swift
//  CreativeDrawing
//
//  Full-screen preview for animation playback and export
//

import UIKit

/// Full-screen controller for previewing and exporting animations
class AnimationPreviewController: UIViewController {

    // MARK: - Properties

    private var document: DrawingDocument?
    private var canvasSize: CGSize = .zero

    private let playbackEngine = PlaybackEngine()
    private let playbackCanvas = PlaybackCanvas()
    private let playbackControls = PlaybackControlsView()

    private var exportProgressView: ExportProgressView?
    private var currentExporter: VideoExporter?
    private var currentGIFExporter: GIFExporter?

    /// Selected animation mode
    private var animationMode: AnimationMode = .timelapse {
        didSet {
            updatePlaybackMode()
        }
    }

    /// Target duration for timelapse
    private var timelapseDuration: TimeInterval = 10.0

    /// Duration per stroke for trace mode
    private var traceDurationPerStroke: TimeInterval = 1.0

    /// Speed multiplier
    private var speedMultiplier: CGFloat = 1.0 {
        didSet {
            updatePlaybackMode()
        }
    }

    // MARK: - UI Elements

    private let navigationBar = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let shareButton = UIButton(type: .system)

    private let canvasContainer = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlaybackEngine()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Auto-play on appear
        playbackEngine.play()
        playbackControls.isPlaying = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playbackEngine.stop()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - Configuration

    /// Configure the preview with a document
    func configure(with document: DrawingDocument, canvasSize: CGSize) {
        self.document = document
        self.canvasSize = canvasSize

        // Handle edge cases for stroke count
        let strokeCount = document.strokes.count

        // Empty document - will be handled by PlaybackEngine
        guard strokeCount > 0 else {
            timelapseDuration = 3.0
            return
        }

        // Single stroke gets minimum 3 seconds for better viewing
        if strokeCount == 1 {
            timelapseDuration = 3.0
        } else {
            // 0.5 seconds per stroke, capped between 5-30 seconds
            timelapseDuration = min(30.0, max(5.0, Double(strokeCount) * 0.5))
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupCanvasContainer()
        setupPlaybackCanvas()
        setupPlaybackControls()
        setupConstraints()
    }

    private func setupNavigationBar() {
        navigationBar.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)

        // Back button
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: iconConfig), for: .normal)
        backButton.setTitle(" Back", for: .normal)
        backButton.tintColor = .systemBlue
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.addSubview(backButton)

        // Title
        titleLabel.text = "Animation Preview"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.addSubview(titleLabel)

        // Share button
        var shareConfig = UIButton.Configuration.filled()
        shareConfig.title = "Share"
        shareConfig.image = UIImage(systemName: "square.and.arrow.up")
        shareConfig.imagePlacement = .leading
        shareConfig.imagePadding = 4
        shareConfig.cornerStyle = .capsule
        shareConfig.baseBackgroundColor = .systemBlue
        shareConfig.baseForegroundColor = .white
        shareButton.configuration = shareConfig
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.addSubview(shareButton)
    }

    private func setupCanvasContainer() {
        canvasContainer.backgroundColor = .systemGray6
        canvasContainer.layer.cornerRadius = 12
        canvasContainer.layer.masksToBounds = true
        canvasContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasContainer)
    }

    private func setupPlaybackCanvas() {
        playbackCanvas.translatesAutoresizingMaskIntoConstraints = false
        playbackCanvas.showPenTip = true
        canvasContainer.addSubview(playbackCanvas)
    }

    private func setupPlaybackControls() {
        playbackControls.delegate = self
        playbackControls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playbackControls)
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Navigation bar
            navigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: 60 + (view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 44)),

            backButton.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor, constant: 16),
            backButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -12),

            titleLabel.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -14),

            shareButton.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor, constant: -16),
            shareButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -10),

            // Canvas container
            canvasContainer.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 16),
            canvasContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            canvasContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Playback canvas fills container
            playbackCanvas.topAnchor.constraint(equalTo: canvasContainer.topAnchor),
            playbackCanvas.leadingAnchor.constraint(equalTo: canvasContainer.leadingAnchor),
            playbackCanvas.trailingAnchor.constraint(equalTo: canvasContainer.trailingAnchor),
            playbackCanvas.bottomAnchor.constraint(equalTo: canvasContainer.bottomAnchor),

            // Playback controls
            playbackControls.topAnchor.constraint(equalTo: canvasContainer.bottomAnchor, constant: 16),
            playbackControls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            playbackControls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            playbackControls.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16)
        ])
    }

    private func setupPlaybackEngine() {
        playbackEngine.delegate = self

        guard let document = document else { return }

        let mode = currentPlaybackMode()
        playbackEngine.configure(document: document, canvasSize: canvasSize, mode: mode)

        // Update controls
        playbackControls.totalDuration = calculateTotalDuration()
        playbackControls.selectedMode = animationMode
        playbackControls.selectedSpeed = speedMultiplier

        // Set canvas background
        playbackCanvas.backgroundColor = document.backgroundColor
    }

    // MARK: - Playback Mode

    private func currentPlaybackMode() -> PlaybackMode {
        switch animationMode {
        case .timelapse:
            return .timelapse(targetDuration: timelapseDuration / TimeInterval(speedMultiplier))
        case .trace:
            return .trace(durationPerStroke: traceDurationPerStroke / TimeInterval(speedMultiplier))
        }
    }

    private func calculateTotalDuration() -> TimeInterval {
        guard let document = document else { return 0 }

        switch animationMode {
        case .timelapse:
            return timelapseDuration / TimeInterval(speedMultiplier)
        case .trace:
            return TimeInterval(document.strokes.count) * (traceDurationPerStroke / TimeInterval(speedMultiplier))
        }
    }

    private func updatePlaybackMode() {
        let wasPlaying = playbackEngine.state == .playing
        playbackEngine.stop()

        guard let document = document else { return }

        let mode = currentPlaybackMode()
        playbackEngine.configure(document: document, canvasSize: canvasSize, mode: mode)
        playbackControls.totalDuration = calculateTotalDuration()

        if wasPlaying {
            playbackEngine.play()
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        playbackEngine.stop()
        dismiss(animated: true)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func shareTapped() {
        showShareOptions()
        SoundManager.shared.playHaptic(.light)
    }

    // MARK: - Share Options

    private func showShareOptions() {
        let alert = UIAlertController(
            title: "Share Animation",
            message: "Choose a format",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "MP4 Video", style: .default) { [weak self] _ in
            self?.exportVideo()
        })

        alert.addAction(UIAlertAction(title: "GIF (iMessage)", style: .default) { [weak self] _ in
            self?.exportGIF(preset: .iMessage())
        })

        alert.addAction(UIAlertAction(title: "Instagram Stories", style: .default) { [weak self] _ in
            self?.exportVideo(preset: .instagramStories())
        })

        alert.addAction(UIAlertAction(title: "TikTok", style: .default) { [weak self] _ in
            self?.exportVideo(preset: .tiktok())
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }

        present(alert, animated: true)
    }

    // MARK: - Export

    private func exportVideo(preset: ExportConfiguration? = nil) {
        guard let document = document else { return }

        playbackEngine.pause()
        playbackControls.isPlaying = false

        let config = preset ?? ExportConfiguration.matchCanvas(canvasSize, duration: calculateTotalDuration(), format: .mp4)

        // Show progress
        let progressView = ExportProgressView()
        progressView.delegate = self
        progressView.exportFormat = .mp4
        progressView.show(in: view)
        exportProgressView = progressView

        // Create exporter
        let exporter = VideoExporter()
        currentExporter = exporter

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: currentPlaybackMode(),
            progressHandler: { [weak progressView] progress in
                progressView?.update(with: progress)
            },
            completion: { [weak self] result in
                self?.handleExportResult(result)
            }
        )
    }

    private func exportGIF(preset: ExportConfiguration? = nil) {
        guard let document = document else { return }

        playbackEngine.pause()
        playbackControls.isPlaying = false

        let config = preset ?? ExportConfiguration.standardGIF(duration: calculateTotalDuration())

        // Show progress
        let progressView = ExportProgressView()
        progressView.delegate = self
        progressView.exportFormat = .gif
        progressView.show(in: view)
        exportProgressView = progressView

        // Create exporter
        let exporter = GIFExporter()
        currentGIFExporter = exporter

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: currentPlaybackMode(),
            progressHandler: { [weak progressView] progress in
                progressView?.update(with: progress)
            },
            completion: { [weak self] result in
                self?.handleExportResult(result)
            }
        )
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            exportProgressView?.showCompletion()

            // Wait a moment then show share sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.exportProgressView?.hide {
                    self?.presentShareSheet(for: url)
                }
            }

        case .failure(let error):
            if case ExportError.cancelled = error {
                exportProgressView?.hide()
            } else {
                exportProgressView?.showError(error)
            }
        }

        currentExporter = nil
        currentGIFExporter = nil
    }

    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }

        present(activityVC, animated: true)
    }
}

// MARK: - PlaybackEngineDelegate

extension AnimationPreviewController: PlaybackEngineDelegate {
    func playbackEngine(_ engine: PlaybackEngine, didChangeState state: PlaybackState) {
        playbackControls.isPlaying = (state == .playing)
    }

    func playbackEngine(_ engine: PlaybackEngine, didUpdateRenderState state: PlaybackRenderState) {
        playbackCanvas.updateRenderState(state)
        playbackControls.progress = state.progress
        playbackControls.currentTime = state.currentTime
    }

    func playbackEngineDidComplete(_ engine: PlaybackEngine) {
        playbackControls.isPlaying = false

        // Loop playback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.playbackEngine.reset()
            self?.playbackEngine.play()
            self?.playbackControls.isPlaying = true
        }
    }
}

// MARK: - PlaybackControlsDelegate

extension AnimationPreviewController: PlaybackControlsDelegate {
    func playbackControlsDidTapPlayPause(_ controls: PlaybackControlsView) {
        if playbackEngine.state == .playing {
            playbackEngine.pause()
        } else {
            playbackEngine.play()
        }
    }

    func playbackControlsDidTapRestart(_ controls: PlaybackControlsView) {
        playbackEngine.stop()
        playbackEngine.play()
    }

    func playbackControlsDidTapSkipForward(_ controls: PlaybackControlsView) {
        let newProgress = min(1.0, playbackControls.progress + 0.1)
        playbackEngine.seek(to: newProgress)
    }

    func playbackControlsDidTapSkipBackward(_ controls: PlaybackControlsView) {
        let newProgress = max(0.0, playbackControls.progress - 0.1)
        playbackEngine.seek(to: newProgress)
    }

    func playbackControls(_ controls: PlaybackControlsView, didSeekToProgress progress: CGFloat) {
        playbackEngine.seek(to: progress)
    }

    func playbackControls(_ controls: PlaybackControlsView, didSelectSpeed speed: CGFloat) {
        speedMultiplier = speed
    }

    func playbackControls(_ controls: PlaybackControlsView, didSelectMode mode: AnimationMode) {
        animationMode = mode
    }
}

// MARK: - ExportProgressViewDelegate

extension AnimationPreviewController: ExportProgressViewDelegate {
    func exportProgressViewDidTapCancel(_ view: ExportProgressView) {
        currentExporter?.cancel()
        currentGIFExporter?.cancel()
        view.hide()
    }
}
