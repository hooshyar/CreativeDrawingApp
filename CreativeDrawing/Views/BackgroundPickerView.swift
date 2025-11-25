//
//  BackgroundPickerView.swift
//  CreativeDrawing
//
//  A simple picker for canvas background colors
//

import UIKit

protocol BackgroundPickerDelegate: AnyObject {
    func backgroundPicker(_ picker: BackgroundPickerView, didSelectColor color: UIColor)
    func backgroundPickerDidClose(_ picker: BackgroundPickerView)
}

class BackgroundPickerView: UIView {

    // MARK: - Properties

    weak var delegate: BackgroundPickerDelegate?

    /// Current selected background color
    var selectedColor: UIColor = .white {
        didSet {
            updateSelection()
        }
    }

    private var colorButtons: [UIButton] = []
    private let scrollView = UIScrollView()

    /// Background colors to choose from - Kid-friendly themes!
    private let backgroundColors: [(color: UIColor, name: String)] = [
        // Basic
        (.white, "Paper"),
        (UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0), "Cream"),

        // Sky & Weather
        (UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1.0), "Sky"),
        (UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0), "Ocean"),
        (UIColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 1.0), "Aqua"),

        // Nature
        (UIColor(red: 0.56, green: 0.93, blue: 0.56, alpha: 1.0), "Grass"),
        (UIColor(red: 0.6, green: 0.8, blue: 0.4, alpha: 1.0), "Meadow"),
        (UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1.0), "Sand"),

        // Sunset & Warm
        (UIColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0), "Sunset"),
        (UIColor(red: 1.0, green: 0.71, blue: 0.76, alpha: 1.0), "Coral"),
        (UIColor(red: 1.0, green: 0.85, blue: 0.73, alpha: 1.0), "Peach"),

        // Fun & Bright
        (UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1.0), "Sunny"),
        (UIColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0), "Bubblegum"),
        (UIColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 1.0), "Grape"),
        (UIColor(red: 0.68, green: 0.85, blue: 0.90, alpha: 1.0), "Cotton Candy"),

        // Night & Space
        (UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0), "Space"),
        (UIColor(red: 0.15, green: 0.15, blue: 0.4, alpha: 1.0), "Night"),
        (UIColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 1.0), "Galaxy"),

        // Chalk
        (.black, "Chalkboard")
    ]

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
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.98)
        layer.cornerRadius = 20
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -4)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 12

        setupHeader()
        setupColorGrid()
    }

    private func setupHeader() {
        // Handle bar
        let handleBar = UIView()
        handleBar.backgroundColor = .systemGray3
        handleBar.layer.cornerRadius = 2.5
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(handleBar)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Background Color"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Close button
        let closeButton = UIButton(type: .system)
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            handleBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 40),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    private func setupColorGrid() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        for (index, bg) in backgroundColors.enumerated() {
            let button = createColorButton(color: bg.color, name: bg.name, tag: index)
            stackView.addArrangedSubview(button)
            colorButtons.append(button)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 60),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 100),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        updateSelection()
    }

    private func createColorButton(color: UIColor, name: String, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false

        // Color swatch
        let swatchView = UIView()
        swatchView.backgroundColor = color
        swatchView.layer.cornerRadius = 25
        swatchView.layer.borderWidth = 2
        swatchView.layer.borderColor = UIColor.systemGray4.cgColor
        swatchView.isUserInteractionEnabled = false
        swatchView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(swatchView)

        // Name label
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = .secondaryLabel
        nameLabel.textAlignment = .center
        nameLabel.isUserInteractionEnabled = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 60),
            button.heightAnchor.constraint(equalToConstant: 80),

            swatchView.topAnchor.constraint(equalTo: button.topAnchor),
            swatchView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            swatchView.widthAnchor.constraint(equalToConstant: 50),
            swatchView.heightAnchor.constraint(equalToConstant: 50),

            nameLabel.topAnchor.constraint(equalTo: swatchView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])

        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)

        return button
    }

    private func updateSelection() {
        for (index, button) in colorButtons.enumerated() {
            let swatchView = button.subviews.first
            let isSelected = backgroundColors[index].color == selectedColor

            UIView.animate(withDuration: 0.2) {
                if isSelected {
                    swatchView?.layer.borderColor = UIColor.systemBlue.cgColor
                    swatchView?.layer.borderWidth = 3
                    swatchView?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                } else {
                    swatchView?.layer.borderColor = UIColor.systemGray4.cgColor
                    swatchView?.layer.borderWidth = 2
                    swatchView?.transform = .identity
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func colorButtonTapped(_ sender: UIButton) {
        let color = backgroundColors[sender.tag].color
        selectedColor = color
        delegate?.backgroundPicker(self, didSelectColor: color)

        SoundManager.shared.play(.pop)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func closeTapped() {
        delegate?.backgroundPickerDidClose(self)
    }
}
