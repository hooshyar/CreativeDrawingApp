//
//  BrushSizeControl.swift
//  CreativeDrawing
//
//  A kid-friendly brush size control with visual feedback - Adaptive
//

import UIKit

protocol BrushSizeControlDelegate: AnyObject {
    func brushSizeControl(_ control: BrushSizeControl, didChangeSizeMultiplier multiplier: CGFloat)
}

class BrushSizeControl: UIView {

    // MARK: - Properties

    weak var delegate: BrushSizeControlDelegate?

    /// Current size multiplier (0.5 to 3.0)
    var sizeMultiplier: CGFloat = 1.0 {
        didSet {
            updatePreview()
            delegate?.brushSizeControl(self, didChangeSizeMultiplier: sizeMultiplier)
        }
    }

    /// Current preview color
    var previewColor: UIColor = .systemBlue {
        didSet {
            previewDot.backgroundColor = previewColor
        }
    }

    /// Size presets
    private let sizePresets: [(multiplier: CGFloat, name: String)] = [
        (0.5, "Tiny"),
        (1.0, "Small"),
        (1.5, "Medium"),
        (2.0, "Large"),
        (3.0, "Huge")
    ]

    private let previewDot = UIView()
    private let slider = UISlider()
    private let sizeLabel = UILabel()
    private var previewDotWidthConstraint: NSLayoutConstraint?
    private let previewContainer = UIView()

    /// Track if we're on a compact device
    private var isCompact: Bool {
        return traitCollection.horizontalSizeClass == .compact
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 6

        setupPreview()
        setupSlider()
        setupLabel()
    }

    private func setupPreview() {
        // Preview dot container
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(previewContainer)

        // The dot itself
        previewDot.backgroundColor = previewColor
        previewDot.layer.cornerRadius = 12
        previewDot.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewDot)

        previewDotWidthConstraint = previewDot.widthAnchor.constraint(equalToConstant: 24)

        NSLayoutConstraint.activate([
            previewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            previewContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewContainer.widthAnchor.constraint(equalToConstant: 40),
            previewContainer.heightAnchor.constraint(equalToConstant: 40),

            previewDot.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            previewDot.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            previewDotWidthConstraint!,
            previewDot.heightAnchor.constraint(equalTo: previewDot.widthAnchor)
        ])
    }

    private func setupSlider() {
        slider.minimumValue = 0.5
        slider.maximumValue = 3.0
        slider.value = 1.0
        slider.tintColor = .systemBlue
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)

        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: 4),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6)
        ])
    }

    private func setupLabel() {
        sizeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        sizeLabel.textColor = .secondaryLabel
        sizeLabel.textAlignment = .center
        sizeLabel.text = "Small"
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sizeLabel)

        NSLayoutConstraint.activate([
            sizeLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            sizeLabel.centerXAnchor.constraint(equalTo: slider.centerXAnchor)
        ])
    }

    private func updatePreview() {
        let baseSize: CGFloat = 24
        let newSize = baseSize * sizeMultiplier
        let clampedSize = min(max(newSize, 12), 72)

        previewDotWidthConstraint?.constant = clampedSize
        previewDot.layer.cornerRadius = clampedSize / 2

        // Update label
        let sizeName: String
        switch sizeMultiplier {
        case 0..<0.75:
            sizeName = "Tiny"
        case 0.75..<1.25:
            sizeName = "Small"
        case 1.25..<1.75:
            sizeName = "Medium"
        case 1.75..<2.5:
            sizeName = "Large"
        default:
            sizeName = "Huge"
        }
        sizeLabel.text = sizeName

        UIView.animate(withDuration: 0.1) {
            self.layoutIfNeeded()
        }
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ sender: UISlider) {
        sizeMultiplier = CGFloat(sender.value)
    }

    @objc private func sliderTouchUp(_ sender: UISlider) {
        // Snap to nearest preset if close
        let value = CGFloat(sender.value)
        for preset in sizePresets {
            if abs(value - preset.multiplier) < 0.15 {
                sender.value = Float(preset.multiplier)
                sizeMultiplier = preset.multiplier
                break
            }
        }

        SoundManager.shared.playHaptic(.light)
    }
}
