//
//  ColorPaletteView.swift
//  CreativeDrawing
//
//  A beautiful, kid-friendly color picker - Adaptive
//

import UIKit

protocol ColorPaletteDelegate: AnyObject {
    func colorPalette(_ palette: ColorPaletteView, didSelectColor color: UIColor)
}

class ColorPaletteView: UIView {

    // MARK: - Properties

    weak var delegate: ColorPaletteDelegate?

    /// Currently selected color
    var selectedColor: UIColor = ColorPalette.rainbow[0] {
        didSet {
            updateSelection()
            delegate?.colorPalette(self, didSelectColor: selectedColor)
        }
    }

    /// Current palette type
    var paletteType: ColorPalette.PaletteType = .rainbow {
        didSet {
            setupColorButtons()
        }
    }

    /// Color buttons
    private var colorButtons: [ColorButton] = []

    /// Container for color buttons
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    /// Button size - adaptive
    private var buttonSize: CGFloat {
        return traitCollection.horizontalSizeClass == .compact ? 36 : 50
    }

    private let buttonSpacing: CGFloat = 6

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

        // Setup scroll view
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        // Setup stack view
        stackView.axis = .horizontal
        stackView.spacing = buttonSpacing
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        setupColorButtons()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            setupColorButtons()
        }
    }

    private func setupColorButtons() {
        // Remove existing buttons
        colorButtons.forEach { $0.removeFromSuperview() }
        colorButtons.removeAll()

        let size = buttonSize

        // Create buttons for each color
        for color in paletteType.colors {
            let button = ColorButton(color: color, size: size)
            button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            colorButtons.append(button)
        }

        updateSelection()
    }

    private func updateSelection() {
        for button in colorButtons {
            button.isSelectedColor = button.color.isEqual(to: selectedColor)
        }
    }

    @objc private func colorButtonTapped(_ sender: ColorButton) {
        selectedColor = sender.color

        // Animate selection
        UIView.animate(withDuration: 0.15, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = sender.isSelectedColor ?
                    CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
            }
        }

        // Sound and haptic feedback
        SoundManager.shared.play(.colorSelect)
        SoundManager.shared.playHaptic(.light)
    }
}

// MARK: - Color Button

class ColorButton: UIButton {

    let color: UIColor
    private let checkmarkView = UIImageView()
    private let buttonSize: CGFloat

    var isSelectedColor: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    init(color: UIColor, size: CGFloat) {
        self.color = color
        self.buttonSize = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        setupButton(size: size)
    }

    required init?(coder: NSCoder) {
        self.color = .black
        self.buttonSize = 36
        super.init(coder: coder)
        setupButton(size: 36)
    }

    private func setupButton(size: CGFloat) {
        backgroundColor = color
        layer.cornerRadius = size / 2
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor

        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 3

        // Add checkmark for selection
        let checkSize = max(size * 0.4, 12)
        let checkConfig = UIImage.SymbolConfiguration(pointSize: checkSize, weight: .bold)
        checkmarkView.image = UIImage(systemName: "checkmark", withConfiguration: checkConfig)
        checkmarkView.tintColor = color.contrastingTextColor
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.isHidden = true
        addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            checkmarkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Accessibility
        accessibilityLabel = ColorPalette.colorName(for: color)
        accessibilityTraits = .button
    }

    private func updateAppearance() {
        checkmarkView.isHidden = !isSelectedColor

        UIView.animate(withDuration: 0.2) {
            self.layer.borderWidth = self.isSelectedColor ? 3 : 2
            self.layer.borderColor = self.isSelectedColor ?
                UIColor.label.cgColor : UIColor.white.cgColor
            self.transform = self.isSelectedColor ?
                CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.transform = self.isSelectedColor ?
                CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.transform = self.isSelectedColor ?
                CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }
}

// MARK: - UIColor Extension

extension UIColor {
    func isEqual(to color: UIColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let tolerance: CGFloat = 0.01
        return abs(r1 - r2) < tolerance &&
               abs(g1 - g2) < tolerance &&
               abs(b1 - b2) < tolerance &&
               abs(a1 - a2) < tolerance
    }
}
