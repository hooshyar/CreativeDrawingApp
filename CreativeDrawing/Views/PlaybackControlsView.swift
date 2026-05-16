//
//  PlaybackControlsView.swift
//  CreativeDrawing
//
//  Playback controls for animation preview
//

import UIKit

protocol PlaybackControlsDelegate: AnyObject {
    func playbackControlsDidTapPlayPause(_ controls: PlaybackControlsView)
    func playbackControlsDidTapRestart(_ controls: PlaybackControlsView)
    func playbackControlsDidTapSkipForward(_ controls: PlaybackControlsView)
    func playbackControlsDidTapSkipBackward(_ controls: PlaybackControlsView)
    func playbackControls(_ controls: PlaybackControlsView, didSeekToProgress progress: CGFloat)
    func playbackControls(_ controls: PlaybackControlsView, didSelectSpeed speed: CGFloat)
    func playbackControls(_ controls: PlaybackControlsView, didSelectMode mode: AnimationMode)
}

/// Animation modes available for playback
enum AnimationMode: String, CaseIterable {
    case timelapse = "Timelapse"
    case trace = "Trace"

    var icon: String {
        switch self {
        case .timelapse: return "forward.fill"
        case .trace: return "pencil.line"
        }
    }
}

/// Controls for animation playback including play/pause, seek, speed, and mode selection
class PlaybackControlsView: UIView {

    // MARK: - Properties

    weak var delegate: PlaybackControlsDelegate?

    /// Current playback state
    var isPlaying: Bool = false {
        didSet {
            updatePlayPauseButton()
        }
    }

    /// Current progress (0.0 to 1.0)
    var progress: CGFloat = 0 {
        didSet {
            progressSlider.value = Float(progress)
            updateTimeLabels()
        }
    }

    /// Total duration in seconds
    var totalDuration: TimeInterval = 0 {
        didSet {
            updateTimeLabels()
        }
    }

    /// Current time in seconds
    var currentTime: TimeInterval = 0 {
        didSet {
            updateTimeLabels()
        }
    }

    /// Selected speed
    var selectedSpeed: CGFloat = 1.0 {
        didSet {
            updateSpeedButtons()
        }
    }

    /// Selected animation mode
    var selectedMode: AnimationMode = .timelapse {
        didSet {
            updateModeButtons()
        }
    }

    // MARK: - UI Elements

    private let progressSlider = UISlider()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()

    private let playPauseButton = UIButton(type: .system)
    private let restartButton = UIButton(type: .system)
    private let skipForwardButton = UIButton(type: .system)
    private let skipBackwardButton = UIButton(type: .system)

    private let speedStackView = UIStackView()
    private var speedButtons: [CGFloat: UIButton] = [:]
    private let speedOptions: [CGFloat] = [1.0, 2.0, 5.0, 10.0]

    private let modeStackView = UIStackView()
    private var modeButtons: [AnimationMode: UIButton] = [:]

    private let controlsStackView = UIStackView()
    private let progressStackView = UIStackView()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 8

        setupProgressControls()
        setupPlaybackButtons()
        setupModeSelector()
        setupSpeedSelector()
        setupLayout()
    }

    private func setupProgressControls() {
        // Progress slider
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.value = 0
        progressSlider.tintColor = .systemBlue
        progressSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])

        // Time labels
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        currentTimeLabel.textColor = .secondaryLabel
        currentTimeLabel.text = "0:00"

        totalTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        totalTimeLabel.textColor = .secondaryLabel
        totalTimeLabel.text = "0:00"
    }

    private func setupPlaybackButtons() {
        let buttonSize: CGFloat = 44
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let largeIconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)

        // Restart button
        restartButton.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: iconConfig), for: .normal)
        restartButton.tintColor = .label
        restartButton.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)

        // Skip backward button
        skipBackwardButton.setImage(UIImage(systemName: "gobackward.5", withConfiguration: iconConfig), for: .normal)
        skipBackwardButton.tintColor = .label
        skipBackwardButton.addTarget(self, action: #selector(skipBackwardTapped), for: .touchUpInside)

        // Play/Pause button (larger)
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: largeIconConfig), for: .normal)
        playPauseButton.tintColor = .systemBlue
        playPauseButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        playPauseButton.layer.cornerRadius = buttonSize / 2
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        // Skip forward button
        skipForwardButton.setImage(UIImage(systemName: "goforward.5", withConfiguration: iconConfig), for: .normal)
        skipForwardButton.tintColor = .label
        skipForwardButton.addTarget(self, action: #selector(skipForwardTapped), for: .touchUpInside)

        // Set fixed sizes
        for button in [restartButton, skipBackwardButton, playPauseButton, skipForwardButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: button == playPauseButton ? 56 : buttonSize),
                button.heightAnchor.constraint(equalToConstant: button == playPauseButton ? 56 : buttonSize)
            ])
        }
    }

    private func setupModeSelector() {
        modeStackView.axis = .horizontal
        modeStackView.spacing = 8
        modeStackView.distribution = .fillEqually

        for mode in AnimationMode.allCases {
            let button = createModeButton(mode: mode)
            modeButtons[mode] = button
            modeStackView.addArrangedSubview(button)
        }

        updateModeButtons()
    }

    private func createModeButton(mode: AnimationMode) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = mode.rawValue
        config.image = UIImage(systemName: mode.icon)
        config.imagePlacement = .leading
        config.imagePadding = 4
        config.cornerStyle = .capsule
        config.baseForegroundColor = .label
        config.baseBackgroundColor = .secondarySystemBackground

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(modeTapped(_:)), for: .touchUpInside)
        button.tag = AnimationMode.allCases.firstIndex(of: mode) ?? 0

        return button
    }

    private func setupSpeedSelector() {
        speedStackView.axis = .horizontal
        speedStackView.spacing = 8
        speedStackView.distribution = .fillEqually

        let speedLabel = UILabel()
        speedLabel.text = "Speed:"
        speedLabel.font = .systemFont(ofSize: 14, weight: .medium)
        speedLabel.textColor = .secondaryLabel
        speedStackView.addArrangedSubview(speedLabel)

        for speed in speedOptions {
            let button = createSpeedButton(speed: speed)
            speedButtons[speed] = button
            speedStackView.addArrangedSubview(button)
        }

        updateSpeedButtons()
    }

    private func createSpeedButton(speed: CGFloat) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = "\(Int(speed))x"
        config.cornerStyle = .capsule
        config.baseForegroundColor = .label
        config.baseBackgroundColor = .secondarySystemBackground
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(speedTapped(_:)), for: .touchUpInside)
        button.tag = Int(speed)

        return button
    }

    private func setupLayout() {
        // Progress stack (slider with time labels)
        progressStackView.axis = .horizontal
        progressStackView.spacing = 8
        progressStackView.alignment = .center
        progressStackView.addArrangedSubview(currentTimeLabel)
        progressStackView.addArrangedSubview(progressSlider)
        progressStackView.addArrangedSubview(totalTimeLabel)

        // Playback controls stack
        controlsStackView.axis = .horizontal
        controlsStackView.spacing = 16
        controlsStackView.alignment = .center
        controlsStackView.distribution = .equalCentering
        controlsStackView.addArrangedSubview(restartButton)
        controlsStackView.addArrangedSubview(skipBackwardButton)
        controlsStackView.addArrangedSubview(playPauseButton)
        controlsStackView.addArrangedSubview(skipForwardButton)

        // Spacer to center the controls
        let leftSpacer = UIView()
        let rightSpacer = UIView()
        controlsStackView.insertArrangedSubview(leftSpacer, at: 0)
        controlsStackView.addArrangedSubview(rightSpacer)

        // Main container stack
        let mainStack = UIStackView(arrangedSubviews: [
            progressStackView,
            controlsStackView,
            modeStackView,
            speedStackView
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])

        // Fix time label widths
        currentTimeLabel.setContentHuggingPriority(.required, for: .horizontal)
        totalTimeLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    // MARK: - Updates

    private func updatePlayPauseButton() {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let icon = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: icon, withConfiguration: iconConfig), for: .normal)
    }

    private func updateTimeLabels() {
        currentTimeLabel.text = formatTime(currentTime)
        totalTimeLabel.text = formatTime(totalDuration)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func updateSpeedButtons() {
        for (speed, button) in speedButtons {
            var config = button.configuration
            if speed == selectedSpeed {
                config?.baseForegroundColor = .white
                config?.baseBackgroundColor = .systemBlue
            } else {
                config?.baseForegroundColor = .label
                config?.baseBackgroundColor = .secondarySystemBackground
            }
            button.configuration = config
        }
    }

    private func updateModeButtons() {
        for (mode, button) in modeButtons {
            var config = button.configuration
            if mode == selectedMode {
                config?.baseForegroundColor = .white
                config?.baseBackgroundColor = .systemBlue
            } else {
                config?.baseForegroundColor = .label
                config?.baseBackgroundColor = .secondarySystemBackground
            }
            button.configuration = config
        }
    }

    // MARK: - Actions

    @objc private func playPauseTapped() {
        delegate?.playbackControlsDidTapPlayPause(self)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func restartTapped() {
        delegate?.playbackControlsDidTapRestart(self)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func skipForwardTapped() {
        delegate?.playbackControlsDidTapSkipForward(self)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func skipBackwardTapped() {
        delegate?.playbackControlsDidTapSkipBackward(self)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func sliderValueChanged(_ slider: UISlider) {
        let progress = CGFloat(slider.value)
        currentTime = TimeInterval(progress) * totalDuration
        updateTimeLabels()
    }

    @objc private func sliderTouchUp(_ slider: UISlider) {
        let progress = CGFloat(slider.value)
        delegate?.playbackControls(self, didSeekToProgress: progress)
    }

    @objc private func speedTapped(_ sender: UIButton) {
        let speed = CGFloat(sender.tag)
        selectedSpeed = speed
        delegate?.playbackControls(self, didSelectSpeed: speed)
        SoundManager.shared.playHaptic(.selection)
    }

    @objc private func modeTapped(_ sender: UIButton) {
        guard sender.tag < AnimationMode.allCases.count else { return }
        let mode = AnimationMode.allCases[sender.tag]
        selectedMode = mode
        delegate?.playbackControls(self, didSelectMode: mode)
        SoundManager.shared.playHaptic(.selection)
    }
}
