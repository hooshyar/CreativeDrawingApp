//
//  ExportProgressView.swift
//  CreativeDrawing
//
//  Progress view for video/GIF export
//

import UIKit

protocol ExportProgressViewDelegate: AnyObject {
    func exportProgressViewDidTapCancel(_ view: ExportProgressView)
}

/// Shows progress during video/GIF export
class ExportProgressView: UIView {

    // MARK: - Properties

    weak var delegate: ExportProgressViewDelegate?

    /// Current progress (0.0 to 1.0)
    var progress: Float = 0 {
        didSet {
            progressView.setProgress(progress, animated: true)
            progressPercentLabel.text = "\(Int(progress * 100))%"
        }
    }

    /// Current export phase
    var phase: ExportPhase = .preparing {
        didSet {
            updatePhaseUI()
        }
    }

    /// Estimated time remaining
    var estimatedTimeRemaining: TimeInterval? {
        didSet {
            updateTimeRemainingLabel()
        }
    }

    /// Export format for display
    var exportFormat: ExportFormat = .mp4 {
        didSet {
            updateFormatLabel()
        }
    }

    // MARK: - UI Elements

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let formatLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressPercentLabel = UILabel()
    private let phaseLabel = UILabel()
    private let timeRemainingLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

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
        backgroundColor = UIColor.black.withAlphaComponent(0.6)

        setupContainer()
        setupLabels()
        setupProgressView()
        setupButtons()
        setupLayout()
    }

    private func setupContainer() {
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowOpacity = 0.2
        containerView.layer.shadowRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
    }

    private func setupLabels() {
        // Title
        titleLabel.text = "Exporting Animation"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        // Format
        formatLabel.text = "MP4 Video"
        formatLabel.font = .systemFont(ofSize: 14, weight: .medium)
        formatLabel.textColor = .secondaryLabel
        formatLabel.textAlignment = .center

        // Progress percent
        progressPercentLabel.text = "0%"
        progressPercentLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        progressPercentLabel.textColor = .systemBlue
        progressPercentLabel.textAlignment = .center

        // Phase
        phaseLabel.text = "Preparing..."
        phaseLabel.font = .systemFont(ofSize: 14, weight: .medium)
        phaseLabel.textColor = .secondaryLabel
        phaseLabel.textAlignment = .center

        // Time remaining
        timeRemainingLabel.text = ""
        timeRemainingLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timeRemainingLabel.textColor = .tertiaryLabel
        timeRemainingLabel.textAlignment = .center
    }

    private func setupProgressView() {
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray5
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        progressView.transform = CGAffineTransform(scaleX: 1, y: 2)

        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .systemBlue
        activityIndicator.startAnimating()
    }

    private func setupButtons() {
        var config = UIButton.Configuration.plain()
        config.title = "Cancel"
        config.baseForegroundColor = .systemRed
        cancelButton.configuration = config
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            formatLabel,
            progressPercentLabel,
            progressView,
            createPhaseStack(),
            timeRemainingLabel,
            cancelButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280),

            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

    private func createPhaseStack() -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [activityIndicator, phaseLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fill

        // Add spacers to center
        let leftSpacer = UIView()
        let rightSpacer = UIView()
        stack.insertArrangedSubview(leftSpacer, at: 0)
        stack.addArrangedSubview(rightSpacer)
        leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor).isActive = true

        return stack
    }

    // MARK: - Updates

    private func updatePhaseUI() {
        phaseLabel.text = phase.description

        switch phase {
        case .preparing:
            progressView.isHidden = true
            activityIndicator.startAnimating()
        case .renderingFrames, .encoding:
            progressView.isHidden = false
            activityIndicator.startAnimating()
        case .finalizing:
            progressView.isHidden = false
            activityIndicator.startAnimating()
        case .completed:
            progressView.isHidden = false
            activityIndicator.stopAnimating()
            phaseLabel.textColor = .systemGreen
        case .failed:
            progressView.isHidden = true
            activityIndicator.stopAnimating()
            phaseLabel.textColor = .systemRed
        }
    }

    private func updateTimeRemainingLabel() {
        if let remaining = estimatedTimeRemaining, remaining > 0 {
            if remaining < 60 {
                timeRemainingLabel.text = "About \(Int(remaining)) seconds remaining"
            } else {
                let minutes = Int(remaining / 60)
                timeRemainingLabel.text = "About \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
            }
            timeRemainingLabel.isHidden = false
        } else {
            timeRemainingLabel.isHidden = true
        }
    }

    private func updateFormatLabel() {
        switch exportFormat {
        case .mp4:
            formatLabel.text = "MP4 Video"
        case .gif:
            formatLabel.text = "Animated GIF"
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        delegate?.exportProgressViewDidTapCancel(self)
        SoundManager.shared.playHaptic(.light)
    }

    // MARK: - Public Methods

    /// Show the progress view with animation
    func show(in parentView: UIView) {
        alpha = 0
        frame = parentView.bounds
        parentView.addSubview(self)

        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }

    /// Hide the progress view with animation
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    /// Update from ExportProgress
    func update(with exportProgress: ExportProgress) {
        progress = exportProgress.progress
        phase = exportProgress.phase
        estimatedTimeRemaining = exportProgress.estimatedTimeRemaining
    }

    /// Show completion state
    func showCompletion() {
        progress = 1.0
        phase = .completed
        phaseLabel.text = "Export Complete!"
        cancelButton.setTitle("Done", for: .normal)
        cancelButton.configuration?.baseForegroundColor = .systemBlue

        // Celebration haptic
        SoundManager.shared.playHaptic(.success)
    }

    /// Show error state
    func showError(_ error: Error) {
        phase = .failed(error)
        phaseLabel.text = error.localizedDescription
        cancelButton.setTitle("Close", for: .normal)

        // Error haptic
        SoundManager.shared.playHaptic(.error)
    }
}
