//
//  GalleryView.swift
//  CreativeDrawing
//
//  A fun gallery for kids to browse their saved drawings
//

import UIKit

protocol GalleryDelegate: AnyObject {
    func gallery(_ gallery: GalleryViewController, didSelectDrawing id: UUID)
    func galleryDidTapNewDrawing(_ gallery: GalleryViewController)
    func galleryDidClose(_ gallery: GalleryViewController)
}

class GalleryViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: GalleryDelegate?

    private var drawings: [DrawingMetadata] = []
    private var collectionView: UICollectionView!

    private let cellSpacing: CGFloat = 16
    private let sectionInset: CGFloat = 20

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDrawings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDrawings()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        setupHeader()
        setupCollectionView()
        setupEmptyState()
    }

    private func setupHeader() {
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "My Drawings"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Close button
        let closeButton = UIButton(type: .system)
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        // New Drawing button
        let newButton = UIButton(type: .system)
        var newConfig = UIButton.Configuration.filled()
        newConfig.cornerStyle = .capsule
        newConfig.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        newConfig.title = "New"
        newConfig.imagePadding = 6
        newConfig.baseBackgroundColor = .systemBlue
        newButton.configuration = newConfig
        newButton.addTarget(self, action: #selector(newDrawingTapped), for: .touchUpInside)
        newButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            newButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            newButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12)
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = cellSpacing
        layout.minimumLineSpacing = cellSpacing
        layout.sectionInset = UIEdgeInsets(top: sectionInset, left: sectionInset, bottom: sectionInset, right: sectionInset)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(DrawingCell.self, forCellWithReuseIdentifier: "DrawingCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private var emptyStateView: UIView?

    private func setupEmptyState() {
        let container = UIView()
        container.isHidden = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        imageView.image = UIImage(systemName: "paintpalette", withConfiguration: config)
        imageView.tintColor = .systemGray3
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        let titleLabel = UILabel()
        titleLabel.text = "No Drawings Yet!"
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Tap 'New' to start creating"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        emptyStateView = container
    }

    // MARK: - Data

    private func loadDrawings() {
        drawings = DrawingStorage.shared.getRecentDrawings()
        collectionView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        emptyStateView?.isHidden = !drawings.isEmpty
        collectionView.isHidden = drawings.isEmpty
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        delegate?.galleryDidClose(self)
        dismiss(animated: true)
    }

    @objc private func newDrawingTapped() {
        delegate?.galleryDidTapNewDrawing(self)
        dismiss(animated: true)
    }

    private func deleteDrawing(at indexPath: IndexPath) {
        let drawing = drawings[indexPath.item]

        let alert = UIAlertController(
            title: "Delete Drawing?",
            message: "Are you sure you want to delete '\(drawing.name)'? This cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }

            _ = DrawingStorage.shared.deleteDrawing(id: drawing.id)
            self.drawings.remove(at: indexPath.item)

            self.collectionView.performBatchUpdates {
                self.collectionView.deleteItems(at: [indexPath])
            } completion: { _ in
                self.updateEmptyState()
            }

            SoundManager.shared.playHaptic(.warning)
        })

        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension GalleryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return drawings.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DrawingCell", for: indexPath) as! DrawingCell
        let drawing = drawings[indexPath.item]
        cell.configure(with: drawing)
        cell.onDelete = { [weak self] in
            self?.deleteDrawing(at: indexPath)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension GalleryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let drawing = drawings[indexPath.item]
        delegate?.gallery(self, didSelectDrawing: drawing.id)
        dismiss(animated: true)

        SoundManager.shared.play(.pop)
        SoundManager.shared.playHaptic(.light)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension GalleryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = collectionView.bounds.width - (sectionInset * 2) - cellSpacing
        let cellWidth = availableWidth / 2
        let cellHeight = cellWidth * 1.2 // Aspect ratio for thumbnail + info
        return CGSize(width: cellWidth, height: cellHeight)
    }
}

// MARK: - Drawing Cell

class DrawingCell: UICollectionViewCell {

    var onDelete: (() -> Void)?

    private let thumbnailImageView = UIImageView()
    private let nameLabel = UILabel()
    private let dateLabel = UILabel()
    private let deleteButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = .systemGray6
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true

        // Thumbnail
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.backgroundColor = .white
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailImageView)

        // Info container
        let infoContainer = UIView()
        infoContainer.backgroundColor = .systemBackground
        infoContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(infoContainer)

        // Name label
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainer.addSubview(nameLabel)

        // Date label
        dateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainer.addSubview(dateLabel)

        // Delete button
        let deleteConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        deleteButton.setImage(UIImage(systemName: "trash.circle.fill", withConfiguration: deleteConfig), for: .normal)
        deleteButton.tintColor = .systemRed.withAlphaComponent(0.8)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        infoContainer.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.7),

            infoContainer.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor),
            infoContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            infoContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            infoContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: infoContainer.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),

            dateLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),

            deleteButton.centerYAnchor.constraint(equalTo: infoContainer.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -10),
            deleteButton.widthAnchor.constraint(equalToConstant: 30),
            deleteButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Selection animation
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 8
    }

    func configure(with drawing: DrawingMetadata) {
        nameLabel.text = drawing.name
        dateLabel.text = drawing.shortDate

        if let thumbnail = drawing.thumbnail {
            thumbnailImageView.image = thumbnail
        } else {
            // Placeholder
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
            thumbnailImageView.image = UIImage(systemName: "photo", withConfiguration: config)
            thumbnailImageView.tintColor = .systemGray4
            thumbnailImageView.contentMode = .center
        }
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
                self.alpha = self.isHighlighted ? 0.8 : 1.0
            }
        }
    }
}
