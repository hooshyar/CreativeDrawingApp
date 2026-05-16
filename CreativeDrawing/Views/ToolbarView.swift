//
//  ToolbarView.swift
//  CreativeDrawing
//
//  Kid-friendly adaptive toolbar for brush selection and actions
//

import UIKit

protocol ToolbarDelegate: AnyObject {
    func toolbar(_ toolbar: ToolbarView, didSelectBrush brush: BrushType)
    func toolbarDidTapUndo(_ toolbar: ToolbarView)
    func toolbarDidTapRedo(_ toolbar: ToolbarView)
    func toolbarDidTapClear(_ toolbar: ToolbarView)
    func toolbarDidTapSave(_ toolbar: ToolbarView)
    func toolbarDidTapStamps(_ toolbar: ToolbarView)
    func toolbarDidTapGallery(_ toolbar: ToolbarView)
    func toolbarDidTapBackground(_ toolbar: ToolbarView)
    func toolbarDidTapSymmetry(_ toolbar: ToolbarView)
    func toolbarDidTapAnimation(_ toolbar: ToolbarView)
    func toolbarDidTapDarkMode(_ toolbar: ToolbarView)
}

class ToolbarView: UIView {

    // MARK: - Properties

    weak var delegate: ToolbarDelegate?

    /// Currently selected brush
    var selectedBrush: BrushType = .marker {
        didSet {
            updateBrushSelection()
            delegate?.toolbar(self, didSelectBrush: selectedBrush)
        }
    }

    /// Undo/redo state
    var canUndo: Bool = false {
        didSet { undoButton.isEnabled = canUndo; undoButton.alpha = canUndo ? 1.0 : 0.4 }
    }

    var canRedo: Bool = false {
        didSet { redoButton.isEnabled = canRedo; redoButton.alpha = canRedo ? 1.0 : 0.4 }
    }

    // UI Elements
    private var brushButtons: [BrushType: ToolButton] = [:]
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    private let undoButton = ToolButton(icon: "arrow.uturn.backward", title: "Undo")
    private let redoButton = ToolButton(icon: "arrow.uturn.forward", title: "Redo")
    private let clearButton = ToolButton(icon: "trash", title: "Clear")
    private let saveButton = ToolButton(icon: "square.and.arrow.down", title: "Save")
    private let stampButton = ToolButton(icon: "star.fill", title: "Stickers")
    private let galleryButton = ToolButton(icon: "photo.on.rectangle", title: "Gallery")
    private let backgroundButton = ToolButton(icon: "paintpalette.fill", title: "Canvas")
    private let symmetryButton = ToolButton(icon: "rectangle", title: "Symmetry")
    private let animationButton = ToolButton(icon: "play.circle", title: "Animate")
    private let darkModeButton = ToolButton(icon: "moon", title: "Dark")

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
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 8

        setupScrollView()
        setupButtons()
        updateLayout()
    }

    private func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        contentStackView.axis = .horizontal
        contentStackView.spacing = 4
        contentStackView.alignment = .center
        contentStackView.distribution = .fill
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    private func setupButtons() {
        // Create brush buttons
        let brushes: [BrushType] = [.pencil, .marker, .crayon, .sparkle, .rainbow]

        for brush in brushes {
            let button = ToolButton(icon: brush.icon, title: brush.displayName)
            button.tag = brushes.firstIndex(of: brush) ?? 0
            button.addTarget(self, action: #selector(brushButtonTapped(_:)), for: .touchUpInside)
            brushButtons[brush] = button
        }

        // Eraser is a brush but shown with actions
        let eraserButton = ToolButton(icon: BrushType.eraser.icon, title: "Eraser")
        eraserButton.addTarget(self, action: #selector(eraserButtonTapped), for: .touchUpInside)
        brushButtons[.eraser] = eraserButton

        // Setup action buttons
        stampButton.addTarget(self, action: #selector(stampsTapped), for: .touchUpInside)
        stampButton.iconTint = .systemPurple

        galleryButton.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        galleryButton.iconTint = .systemIndigo

        backgroundButton.addTarget(self, action: #selector(backgroundTapped), for: .touchUpInside)
        backgroundButton.iconTint = .systemOrange

        symmetryButton.addTarget(self, action: #selector(symmetryTapped), for: .touchUpInside)
        symmetryButton.iconTint = .systemTeal

        animationButton.addTarget(self, action: #selector(animationTapped), for: .touchUpInside)
        animationButton.iconTint = .systemGreen

        darkModeButton.addTarget(self, action: #selector(darkModeTapped), for: .touchUpInside)
        darkModeButton.iconTint = .systemIndigo

        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        clearButton.iconTint = .systemRed

        updateBrushSelection()
    }

    private func updateLayout() {
        // Clear existing arranged subviews
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let showLabels = !isCompact
        let buttonSize: CGFloat = isCompact ? 44 : 56

        // Update all buttons for current mode
        for (_, button) in brushButtons {
            button.showLabel = showLabels
            button.buttonSize = buttonSize
        }

        [stampButton, galleryButton, backgroundButton, symmetryButton, animationButton, darkModeButton, undoButton, redoButton, clearButton, saveButton].forEach {
            $0.showLabel = showLabels
            $0.buttonSize = buttonSize
        }

        // Add brush buttons
        let brushes: [BrushType] = [.pencil, .marker, .crayon, .sparkle, .rainbow]
        for brush in brushes {
            if let button = brushButtons[brush] {
                contentStackView.addArrangedSubview(button)
            }
        }

        // Add separator
        let separator1 = createSeparator()
        contentStackView.addArrangedSubview(separator1)

        // Add eraser
        if let eraserButton = brushButtons[.eraser] {
            contentStackView.addArrangedSubview(eraserButton)
        }

        // Add separator
        let separator2 = createSeparator()
        contentStackView.addArrangedSubview(separator2)

        // Add action buttons
        contentStackView.addArrangedSubview(symmetryButton)
        contentStackView.addArrangedSubview(animationButton)
        contentStackView.addArrangedSubview(galleryButton)
        contentStackView.addArrangedSubview(backgroundButton)
        contentStackView.addArrangedSubview(darkModeButton)
        contentStackView.addArrangedSubview(stampButton)

        // Add separator
        let separator3 = createSeparator()
        contentStackView.addArrangedSubview(separator3)

        contentStackView.addArrangedSubview(undoButton)
        contentStackView.addArrangedSubview(redoButton)
        contentStackView.addArrangedSubview(clearButton)
        contentStackView.addArrangedSubview(saveButton)
    }

    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: isCompact ? 30 : 40)
        ])
        return separator
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updateLayout()
        }
    }

    private func updateBrushSelection() {
        for (brush, button) in brushButtons {
            button.isSelectedTool = (brush == selectedBrush)
        }
    }

    // MARK: - Actions

    @objc private func brushButtonTapped(_ sender: ToolButton) {
        let brushes: [BrushType] = [.pencil, .marker, .crayon, .sparkle, .rainbow]
        guard sender.tag < brushes.count else { return }
        selectedBrush = brushes[sender.tag]
        animateButtonTap(sender)
        SoundManager.shared.play(.brushSelect)
        SoundManager.shared.playHaptic(.selection)
    }

    @objc private func eraserButtonTapped() {
        selectedBrush = .eraser
        if let button = brushButtons[.eraser] {
            animateButtonTap(button)
        }
        SoundManager.shared.play(.brushSelect)
        SoundManager.shared.playHaptic(.selection)
    }

    @objc private func stampsTapped() {
        delegate?.toolbarDidTapStamps(self)
        animateButtonTap(stampButton)
        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func galleryTapped() {
        delegate?.toolbarDidTapGallery(self)
        animateButtonTap(galleryButton)
        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func backgroundTapped() {
        delegate?.toolbarDidTapBackground(self)
        animateButtonTap(backgroundButton)
        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func symmetryTapped() {
        delegate?.toolbarDidTapSymmetry(self)
        animateButtonTap(symmetryButton)
        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.selection)
    }

    @objc private func animationTapped() {
        delegate?.toolbarDidTapAnimation(self)
        animateButtonTap(animationButton)
        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func darkModeTapped() {
        delegate?.toolbarDidTapDarkMode(self)
        animateButtonTap(darkModeButton)
        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.selection)
    }

    /// Update dark mode button appearance based on state
    func updateDarkModeButton(isDarkMode: Bool) {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: darkModeButton.showLabel ? 22 : 24, weight: .medium)
        var config = darkModeButton.configuration ?? UIButton.Configuration.plain()
        config.image = UIImage(systemName: isDarkMode ? "moon.fill" : "moon", withConfiguration: iconConfig)

        if darkModeButton.showLabel {
            config.title = "Dark"
        }

        darkModeButton.configuration = config

        // Highlight when dark mode is active
        if isDarkMode {
            darkModeButton.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.15)
            darkModeButton.tintColor = .systemIndigo
        } else {
            darkModeButton.backgroundColor = .clear
            darkModeButton.tintColor = .systemIndigo
        }
    }

    /// Update symmetry button appearance based on mode
    func updateSymmetryButton(mode: SymmetryMode) {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: symmetryButton.showLabel ? 22 : 24, weight: .medium)
        var config = symmetryButton.configuration ?? UIButton.Configuration.plain()
        config.image = UIImage(systemName: mode.icon, withConfiguration: iconConfig)

        if symmetryButton.showLabel {
            config.title = mode.rawValue
        }

        symmetryButton.configuration = config

        // Highlight when symmetry is active
        if mode != .none {
            symmetryButton.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.15)
            symmetryButton.tintColor = .systemTeal
        } else {
            symmetryButton.backgroundColor = .clear
            symmetryButton.tintColor = .systemTeal
        }
    }

    @objc private func undoTapped() {
        delegate?.toolbarDidTapUndo(self)
        animateButtonTap(undoButton)
        SoundManager.shared.play(.undo)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func redoTapped() {
        delegate?.toolbarDidTapRedo(self)
        animateButtonTap(redoButton)
        SoundManager.shared.play(.redo)
        SoundManager.shared.playHaptic(.light)
    }

    @objc private func clearTapped() {
        delegate?.toolbarDidTapClear(self)
        animateButtonTap(clearButton)
        SoundManager.shared.play(.clear)
        SoundManager.shared.playHaptic(.medium)
    }

    @objc private func saveTapped() {
        delegate?.toolbarDidTapSave(self)
        animateButtonTap(saveButton)
        SoundManager.shared.play(.save)
        SoundManager.shared.playHaptic(.success)
    }

    private func animateButtonTap(_ button: UIView) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Tool Button

class ToolButton: UIButton {

    var isSelectedTool: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    var showLabel: Bool = true {
        didSet {
            updateButtonConfiguration()
        }
    }

    var buttonSize: CGFloat = 56 {
        didSet {
            updateConstraints()
        }
    }

    var iconTint: UIColor? {
        didSet {
            if !isSelectedTool {
                tintColor = iconTint ?? .label
            }
        }
    }

    private var iconName: String = ""
    private var titleText: String = ""
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    init(icon: String, title: String) {
        super.init(frame: .zero)
        self.iconName = icon
        self.titleText = title
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 10

        widthConstraint = widthAnchor.constraint(equalToConstant: buttonSize)
        heightConstraint = heightAnchor.constraint(equalToConstant: buttonSize)
        widthConstraint?.isActive = true
        heightConstraint?.isActive = true

        accessibilityLabel = titleText
        updateButtonConfiguration()
    }

    private func updateButtonConfiguration() {
        var config = UIButton.Configuration.plain()

        let iconSize: CGFloat = showLabel ? 22 : 24
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        config.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)

        if showLabel {
            config.imagePlacement = .top
            config.imagePadding = 2
            config.title = titleText
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var newAttrs = attrs
                newAttrs.font = UIFont.systemFont(ofSize: 9, weight: .medium)
                return newAttrs
            }
        } else {
            config.title = nil
        }

        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

        configuration = config
        tintColor = iconTint ?? .label
    }

    override func updateConstraints() {
        widthConstraint?.constant = buttonSize
        heightConstraint?.constant = buttonSize
        super.updateConstraints()
    }

    private func updateAppearance() {
        UIView.animate(withDuration: 0.2) {
            if self.isSelectedTool {
                self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
                self.tintColor = .systemBlue
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } else {
                self.backgroundColor = .clear
                self.tintColor = self.iconTint ?? .label
                self.transform = .identity
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.alpha = 0.7
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.alpha = 1.0
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.alpha = 1.0
        }
    }
}
