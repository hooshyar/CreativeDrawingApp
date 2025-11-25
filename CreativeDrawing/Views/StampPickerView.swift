//
//  StampPickerView.swift
//  CreativeDrawing
//
//  A fun stamp picker for kids to select stickers
//

import UIKit

protocol StampPickerDelegate: AnyObject {
    func stampPicker(_ picker: StampPickerView, didSelectStamp stamp: StampType)
    func stampPicker(_ picker: StampPickerView, didSelectCustomSticker sticker: CustomSticker)
    func stampPickerDidClose(_ picker: StampPickerView)
    func stampPickerDidRequestNewSticker(_ picker: StampPickerView)
}

class StampPickerView: UIView {

    // MARK: - Properties

    weak var delegate: StampPickerDelegate?

    private var selectedCategory: StampCategory = .fun
    private var showingCustomStickers = false
    private let categoryScrollView = UIScrollView()
    private let stampCollectionView: UICollectionView
    private var categoryButtons: [StampCategory: UIButton] = [:]
    private var myStickersButton: UIButton?

    private let stampSize: CGFloat = 60
    private let spacing: CGFloat = 12

    // MARK: - Initialization

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 70, height: 70)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        stampCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 70, height: 70)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8

        stampCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.98)
        layer.cornerRadius = 24
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -4)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 12

        setupHeader()
        setupCategoryBar()
        setupCollectionView()
    }

    private func setupHeader() {
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "🎨 Stickers"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
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

        // Handle bar
        let handleBar = UIView()
        handleBar.backgroundColor = .systemGray3
        handleBar.layer.cornerRadius = 2.5
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(handleBar)

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

    private func setupCategoryBar() {
        categoryScrollView.showsHorizontalScrollIndicator = false
        categoryScrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(categoryScrollView)

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        categoryScrollView.addSubview(stackView)

        // Add "My Stickers" button first (special category for custom stickers)
        let myStickerButton = createMyStickersCategoryButton()
        stackView.addArrangedSubview(myStickerButton)
        myStickersButton = myStickerButton

        for category in StampCategory.allCases {
            let button = createCategoryButton(for: category)
            stackView.addArrangedSubview(button)
            categoryButtons[category] = button
        }

        NSLayoutConstraint.activate([
            categoryScrollView.topAnchor.constraint(equalTo: topAnchor, constant: 60),
            categoryScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            categoryScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            categoryScrollView.heightAnchor.constraint(equalToConstant: 50),

            stackView.topAnchor.constraint(equalTo: categoryScrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: categoryScrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: categoryScrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: categoryScrollView.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalTo: categoryScrollView.heightAnchor)
        ])

        // Listen for custom sticker updates
        CustomStickerManager.shared.onStickersUpdated = { [weak self] in
            if self?.showingCustomStickers == true {
                self?.stampCollectionView.reloadData()
            }
        }

        updateCategorySelection()
    }

    private func createMyStickersCategoryButton() -> UIButton {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        config.image = UIImage(systemName: "camera.fill", withConfiguration: symbolConfig)
        config.imagePadding = 6
        config.title = "My Stickers"
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var newAttrs = attrs
            newAttrs.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            return newAttrs
        }

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(myStickersTapped), for: .touchUpInside)
        button.tag = -1 // Special tag for custom stickers

        return button
    }

    private func createCategoryButton(for category: StampCategory) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        config.image = UIImage(systemName: category.icon, withConfiguration: symbolConfig)
        config.imagePadding = 6
        config.title = category.rawValue
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var newAttrs = attrs
            newAttrs.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            return newAttrs
        }

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
        button.tag = StampCategory.allCases.firstIndex(of: category) ?? 0

        return button
    }

    private func setupCollectionView() {
        stampCollectionView.backgroundColor = .clear
        stampCollectionView.delegate = self
        stampCollectionView.dataSource = self
        stampCollectionView.register(StampCell.self, forCellWithReuseIdentifier: "StampCell")
        stampCollectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stampCollectionView)

        NSLayoutConstraint.activate([
            stampCollectionView.topAnchor.constraint(equalTo: categoryScrollView.bottomAnchor, constant: 8),
            stampCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stampCollectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stampCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    private func updateCategorySelection() {
        // Update My Stickers button
        if showingCustomStickers {
            myStickersButton?.configuration?.baseBackgroundColor = .systemPurple
            myStickersButton?.configuration?.baseForegroundColor = .white
        } else {
            myStickersButton?.configuration?.baseBackgroundColor = .systemGray5
            myStickersButton?.configuration?.baseForegroundColor = .label
        }

        // Update category buttons
        for (category, button) in categoryButtons {
            if category == selectedCategory && !showingCustomStickers {
                button.configuration?.baseBackgroundColor = .systemBlue
                button.configuration?.baseForegroundColor = .white
            } else {
                button.configuration?.baseBackgroundColor = .systemGray5
                button.configuration?.baseForegroundColor = .label
            }
        }
    }

    // MARK: - Actions

    @objc private func myStickersTapped() {
        showingCustomStickers = true
        updateCategorySelection()
        stampCollectionView.reloadData()

        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.selection)
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        showingCustomStickers = false
        selectedCategory = StampCategory.allCases[sender.tag]
        updateCategorySelection()
        stampCollectionView.reloadData()

        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.selection)
    }

    @objc private func closeTapped() {
        delegate?.stampPickerDidClose(self)
    }
}

// MARK: - UICollectionViewDataSource

extension StampPickerView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if showingCustomStickers {
            // +1 for the "Add New" button
            return CustomStickerManager.shared.customStickers.count + 1
        }
        return selectedCategory.stamps.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StampCell", for: indexPath) as! StampCell

        if showingCustomStickers {
            if indexPath.item == 0 {
                // "Add New" cell
                cell.configureAsAddNew()
            } else {
                let sticker = CustomStickerManager.shared.customStickers[indexPath.item - 1]
                cell.configure(with: sticker)
            }
        } else {
            let stamp = selectedCategory.stamps[indexPath.item]
            cell.configure(with: stamp)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension StampPickerView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if showingCustomStickers {
            if indexPath.item == 0 {
                // "Add New" tapped - request new sticker
                delegate?.stampPickerDidRequestNewSticker(self)
                SoundManager.shared.play(.tap)
                SoundManager.shared.playHaptic(.light)
            } else {
                // Custom sticker selected
                let sticker = CustomStickerManager.shared.customStickers[indexPath.item - 1]
                delegate?.stampPicker(self, didSelectCustomSticker: sticker)

                // Animate selection
                if let cell = collectionView.cellForItem(at: indexPath) {
                    UIView.animate(withDuration: 0.1, animations: {
                        cell.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                    }) { _ in
                        UIView.animate(withDuration: 0.1) {
                            cell.transform = .identity
                        }
                    }
                }

                SoundManager.shared.play(.pop)
                SoundManager.shared.playHaptic(.medium)
            }
        } else {
            let stamp = selectedCategory.stamps[indexPath.item]
            delegate?.stampPicker(self, didSelectStamp: stamp)

            // Animate selection
            if let cell = collectionView.cellForItem(at: indexPath) {
                UIView.animate(withDuration: 0.1, animations: {
                    cell.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }) { _ in
                    UIView.animate(withDuration: 0.1) {
                        cell.transform = .identity
                    }
                }
            }

            SoundManager.shared.play(.pop)
            SoundManager.shared.playHaptic(.medium)
        }
    }

    /// Refresh the custom stickers display
    func refreshCustomStickers() {
        if showingCustomStickers {
            stampCollectionView.reloadData()
        }
    }
}

// MARK: - Stamp Cell

class StampCell: UICollectionViewCell {

    private let imageView = UIImageView()
    private let nameLabel = UILabel()
    private var imageViewWidthConstraint: NSLayoutConstraint?
    private var imageViewHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 12
        clipsToBounds = true

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        nameLabel.font = .systemFont(ofSize: 9, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        imageViewWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: 36)
        imageViewHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: 36)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageViewWidthConstraint!,
            imageViewHeightConstraint!,

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.tintColor = nil
        nameLabel.text = nil
        backgroundColor = .systemGray6
        imageViewWidthConstraint?.constant = 36
        imageViewHeightConstraint?.constant = 36
        imageView.layer.cornerRadius = 0
    }

    func configure(with stamp: StampType) {
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        imageView.image = UIImage(systemName: stamp.rawValue, withConfiguration: config)
        imageView.tintColor = stamp.defaultColor
        nameLabel.text = stamp.displayName
        imageView.layer.cornerRadius = 0
    }

    func configure(with sticker: CustomSticker) {
        if let image = sticker.loadImage() {
            imageView.image = image
            imageView.contentMode = .scaleAspectFill
            imageViewWidthConstraint?.constant = 50
            imageViewHeightConstraint?.constant = 50
            imageView.layer.cornerRadius = 8
            imageView.clipsToBounds = true
        }
        imageView.tintColor = nil
        nameLabel.text = "Custom"
    }

    func configureAsAddNew() {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        imageView.image = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
        imageView.tintColor = .systemPurple
        imageView.contentMode = .scaleAspectFit
        nameLabel.text = "Add New"
        backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        imageView.layer.cornerRadius = 0
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
                self.alpha = self.isHighlighted ? 0.7 : 1.0
            }
        }
    }
}
