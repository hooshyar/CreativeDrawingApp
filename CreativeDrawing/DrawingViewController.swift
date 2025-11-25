//
//  DrawingViewController.swift
//  CreativeDrawing
//
//  Main view controller for the drawing experience - Adaptive for phones and tablets
//

import UIKit
import AVFoundation
import PhotosUI

class DrawingViewController: UIViewController {

    // MARK: - UI Components

    private let canvas = DrawingCanvas()
    private let colorPalette = ColorPaletteView()
    private let brushSizeControl = BrushSizeControl()
    private let toolbar = ToolbarView()
    private var stampPicker: StampPickerView?

    /// Optional audio player for sound effects
    private var soundPlayer: AVAudioPlayer?

    /// Animation view for celebrations
    private var celebrationView: UIView?

    /// Is stamp picker visible
    private var isStampPickerVisible = false

    /// Background picker view
    private var backgroundPicker: BackgroundPickerView?
    private var isBackgroundPickerVisible = false

    /// Current drawing ID for persistence
    private var currentDrawingId: UUID?

    /// Auto-save timer
    private var autoSaveTimer: Timer?

    /// Has welcome animation been shown
    private var hasShownWelcome = false

    /// Track if document has unsaved changes
    private var hasUnsavedChanges = false

    /// Constraints that change based on size class
    private var compactConstraints: [NSLayoutConstraint] = []
    private var regularConstraints: [NSLayoutConstraint] = []

    /// Track if we're in compact mode
    private var isCompact: Bool {
        return traitCollection.horizontalSizeClass == .compact
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupDelegates()
        setupGestures()
        setupAutoSave()
        startNewDrawing()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasShownWelcome {
            showWelcomeAnimation()
            hasShownWelcome = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveCurrentDrawingIfNeeded()
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updateLayoutForCurrentSizeClass()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor.systemGray6

        // Canvas - the main drawing area
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.layer.cornerRadius = 12
        canvas.layer.masksToBounds = true
        // No visible border - clean look
        view.addSubview(canvas)

        // Brush size control
        brushSizeControl.translatesAutoresizingMaskIntoConstraints = false
        brushSizeControl.delegate = self
        view.addSubview(brushSizeControl)

        // Color palette at the bottom
        colorPalette.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(colorPalette)

        // Toolbar at the top
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide

        // Shared constraints (always active)
        NSLayoutConstraint.activate([
            // Toolbar at top - full width with small margin
            toolbar.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 4),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            // Canvas fills the middle - adapts to other elements
            canvas.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])

        // Compact layout (phones)
        compactConstraints = [
            // Smaller toolbar height for phones
            toolbar.heightAnchor.constraint(equalToConstant: 56),

            // Brush size control - compact on phones
            brushSizeControl.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -4),
            brushSizeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            brushSizeControl.widthAnchor.constraint(equalToConstant: 140),
            brushSizeControl.heightAnchor.constraint(equalToConstant: 50),

            // Color palette - fills remaining space
            colorPalette.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -4),
            colorPalette.leadingAnchor.constraint(equalTo: brushSizeControl.trailingAnchor, constant: 8),
            colorPalette.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            colorPalette.heightAnchor.constraint(equalToConstant: 50),

            // Canvas goes down to bottom controls
            canvas.bottomAnchor.constraint(equalTo: brushSizeControl.topAnchor, constant: -8)
        ]

        // Regular layout (tablets)
        regularConstraints = [
            // Larger toolbar for tablets
            toolbar.heightAnchor.constraint(equalToConstant: 72),

            // Brush size control - larger on tablets
            brushSizeControl.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -8),
            brushSizeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            brushSizeControl.widthAnchor.constraint(equalToConstant: 200),
            brushSizeControl.heightAnchor.constraint(equalToConstant: 60),

            // Color palette - larger on tablets
            colorPalette.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -8),
            colorPalette.leadingAnchor.constraint(equalTo: brushSizeControl.trailingAnchor, constant: 12),
            colorPalette.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            colorPalette.heightAnchor.constraint(equalToConstant: 60),

            // Canvas goes down to bottom controls
            canvas.bottomAnchor.constraint(equalTo: brushSizeControl.topAnchor, constant: -12)
        ]

        // Activate appropriate constraints based on current size class
        updateLayoutForCurrentSizeClass()
    }

    private func updateLayoutForCurrentSizeClass() {
        if isCompact {
            NSLayoutConstraint.deactivate(regularConstraints)
            NSLayoutConstraint.activate(compactConstraints)
        } else {
            NSLayoutConstraint.deactivate(compactConstraints)
            NSLayoutConstraint.activate(regularConstraints)
        }
        view.layoutIfNeeded()
    }

    private func setupDelegates() {
        canvas.delegate = self
        colorPalette.delegate = self
        toolbar.delegate = self

        // Initial state
        canvas.selectedColor = colorPalette.selectedColor
        canvas.selectedBrush = toolbar.selectedBrush
        brushSizeControl.previewColor = colorPalette.selectedColor
        updateUndoRedoState()
    }

    private func setupGestures() {
        // Shake to clear (fun for kids!)
        becomeFirstResponder()
    }

    private func setupAutoSave() {
        // Auto-save every 30 seconds if there are changes
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.saveCurrentDrawingIfNeeded()
        }
    }

    // MARK: - Drawing Persistence

    /// Start a new blank drawing
    func startNewDrawing() {
        saveCurrentDrawingIfNeeded()

        canvas.document.reset()
        currentDrawingId = DrawingStorage.shared.startNewDrawing()
        hasUnsavedChanges = false
    }

    /// Load an existing drawing
    func loadDrawing(id: UUID) {
        saveCurrentDrawingIfNeeded()

        guard let document = DrawingStorage.shared.loadDrawing(id: id) else {
            showToast(message: "Couldn't load drawing")
            return
        }

        // Reset and copy document state to canvas (without creating undo history)
        canvas.document.reset()
        canvas.document.loadStrokes(document.strokes)
        canvas.document.loadStamps(document.stamps)
        canvas.document.backgroundColor = document.backgroundColor
        canvas.setBackgroundColor(document.backgroundColor)

        currentDrawingId = id
        hasUnsavedChanges = false
        canvas.setNeedsDisplay()

        // Show drawing name
        if let metadata = DrawingStorage.shared.getMetadata(id: id) {
            showToast(message: "Loaded: \(metadata.name)")
        }
    }

    /// Save current drawing if it has changes
    private func saveCurrentDrawingIfNeeded() {
        guard hasUnsavedChanges else { return }
        guard canvas.document.strokes.count > 0 || canvas.document.stamps.count > 0 || canvas.document.fills.count > 0 else { return }

        let _ = DrawingStorage.shared.saveDrawing(
            canvas.document,
            canvasSize: canvas.bounds.size,
            existingId: currentDrawingId
        )

        hasUnsavedChanges = false
    }

    /// Show the gallery
    private func showGallery() {
        saveCurrentDrawingIfNeeded()

        let gallery = GalleryViewController()
        gallery.delegate = self
        gallery.modalPresentationStyle = .pageSheet

        if let sheet = gallery.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        present(gallery, animated: true)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            showClearConfirmation()
        }
    }

    // MARK: - Actions

    private func updateUndoRedoState() {
        toolbar.canUndo = canvas.document.canUndo
        toolbar.canRedo = canvas.document.canRedo
    }

    private func showClearConfirmation() {
        let alert = UIAlertController(
            title: "Clear Drawing?",
            message: "This will erase everything!",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.canvas.clearCanvas()
            self?.playSound(named: "clear")
        })

        present(alert, animated: true)
    }

    private func saveDrawing() {
        // Save to app storage
        if let metadata = DrawingStorage.shared.saveDrawing(
            canvas.document,
            canvasSize: canvas.bounds.size,
            existingId: currentDrawingId
        ) {
            currentDrawingId = metadata.id
            hasUnsavedChanges = false
        }

        // Also save to Photos
        guard let image = canvas.exportImage() else {
            showToast(message: "Couldn't save")
            return
        }

        UIImageWriteToSavedPhotosAlbum(image, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showToast(message: "Error: \(error.localizedDescription)")
        } else {
            showCelebration()
            showToast(message: "Saved!")
            playSound(named: "success")
        }
    }

    // MARK: - Animations & Feedback

    private func showWelcomeAnimation() {
        // Animate UI elements in
        toolbar.transform = CGAffineTransform(translationX: 0, y: -100)
        colorPalette.transform = CGAffineTransform(translationX: 0, y: 100)
        brushSizeControl.transform = CGAffineTransform(translationX: 0, y: 100)
        canvas.alpha = 0

        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.toolbar.transform = .identity
            self.colorPalette.transform = .identity
            self.brushSizeControl.transform = .identity
            self.canvas.alpha = 1
        }
    }

    private func showCelebration() {
        // Create celebration particles
        let celebrationView = UIView(frame: view.bounds)
        celebrationView.isUserInteractionEnabled = false
        view.addSubview(celebrationView)

        // Create confetti-like particles
        for _ in 0..<30 {
            let particle = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            particle.backgroundColor = ColorPalette.rainbow.randomElement()
            particle.layer.cornerRadius = 5
            particle.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            celebrationView.addSubview(particle)

            let randomX = CGFloat.random(in: -200...200)
            let randomY = CGFloat.random(in: -300 ... -100)
            let randomRotation = CGFloat.random(in: -.pi ... .pi)

            UIView.animate(withDuration: 0.8, delay: 0, options: .curveEaseOut) {
                particle.center = CGPoint(
                    x: particle.center.x + randomX,
                    y: particle.center.y + randomY
                )
                particle.transform = CGAffineTransform(rotationAngle: randomRotation)
                particle.alpha = 0
            } completion: { _ in
                particle.removeFromSuperview()
            }
        }

        // Remove celebration view after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            celebrationView.removeFromSuperview()
        }
    }

    private func showToast(message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textAlignment = .center
        toast.font = .systemFont(ofSize: 16, weight: .semibold)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            toast.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Add padding
        toast.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        toast.alpha = 0
        toast.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.3) {
            toast.alpha = 1
            toast.transform = .identity
        }

        UIView.animate(withDuration: 0.3, delay: 1.5, options: []) {
            toast.alpha = 0
            toast.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }

    private func playSound(named name: String) {
        // Sound effects would be loaded from bundle
        // For now, use system haptics as feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - DrawingCanvasDelegate

extension DrawingViewController: DrawingCanvasDelegate {
    func canvasDidBeginDrawing(_ canvas: DrawingCanvas) {
        // Could hide UI elements for immersive drawing
    }

    func canvasDidEndDrawing(_ canvas: DrawingCanvas) {
        updateUndoRedoState()
    }

    func canvasDidChange(_ canvas: DrawingCanvas) {
        updateUndoRedoState()
        hasUnsavedChanges = true
    }
}

// MARK: - GalleryDelegate

extension DrawingViewController: GalleryDelegate {
    func gallery(_ gallery: GalleryViewController, didSelectDrawing id: UUID) {
        loadDrawing(id: id)
    }

    func galleryDidTapNewDrawing(_ gallery: GalleryViewController) {
        startNewDrawing()
    }

    func galleryDidClose(_ gallery: GalleryViewController) {
        // Nothing special needed
    }
}

// MARK: - ColorPaletteDelegate

extension DrawingViewController: ColorPaletteDelegate {
    func colorPalette(_ palette: ColorPaletteView, didSelectColor color: UIColor) {
        canvas.selectedColor = color
        brushSizeControl.previewColor = color
    }
}

// MARK: - ToolbarDelegate

extension DrawingViewController: ToolbarDelegate {
    func toolbar(_ toolbar: ToolbarView, didSelectBrush brush: BrushType) {
        canvas.selectedBrush = brush
        canvas.setDrawMode()
        hideStampPicker()
    }

    func toolbarDidTapUndo(_ toolbar: ToolbarView) {
        canvas.undo()
        playSound(named: "undo")
    }

    func toolbarDidTapRedo(_ toolbar: ToolbarView) {
        canvas.redo()
        playSound(named: "redo")
    }

    func toolbarDidTapClear(_ toolbar: ToolbarView) {
        showClearConfirmation()
    }

    func toolbarDidTapSave(_ toolbar: ToolbarView) {
        saveDrawing()
    }

    func toolbarDidTapStamps(_ toolbar: ToolbarView) {
        if isStampPickerVisible {
            hideStampPicker()
        } else {
            showStampPicker()
        }
    }

    func toolbarDidTapGallery(_ toolbar: ToolbarView) {
        showGallery()
    }

    func toolbarDidTapBackground(_ toolbar: ToolbarView) {
        if isBackgroundPickerVisible {
            hideBackgroundPicker()
        } else {
            showBackgroundPicker()
        }
    }

    func toolbarDidTapFill(_ toolbar: ToolbarView) {
        canvas.setFillMode()
        hideStampPicker()
        hideBackgroundPicker()
        showToast(message: "Tap to fill!")
    }

    func toolbarDidTapSymmetry(_ toolbar: ToolbarView) {
        canvas.cycleSymmetryMode()
        toolbar.updateSymmetryButton(mode: canvas.symmetryMode)

        // Show feedback about the mode
        let modeDescription: String
        switch canvas.symmetryMode {
        case .none:
            modeDescription = "Symmetry off"
        case .horizontal:
            modeDescription = "Mirror mode - draw on both sides!"
        case .vertical:
            modeDescription = "Flip mode - draw top and bottom!"
        case .quad:
            modeDescription = "Kaleidoscope - 4-way magic!"
        }
        showToast(message: modeDescription)
    }
}

// MARK: - Stamp Picker

extension DrawingViewController: StampPickerDelegate {

    private func showStampPicker() {
        guard stampPicker == nil else { return }
        hideBackgroundPicker() // Hide background picker if visible

        let picker = StampPickerView()
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)

        let pickerHeight: CGFloat = isCompact ? 280 : 320

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            picker.heightAnchor.constraint(equalToConstant: pickerHeight)
        ])

        // Animate in
        picker.transform = CGAffineTransform(translationX: 0, y: pickerHeight)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5) {
            picker.transform = .identity
            self.colorPalette.alpha = 0
            self.brushSizeControl.alpha = 0
        }

        stampPicker = picker
        isStampPickerVisible = true

        SoundManager.shared.playHaptic(.medium)
    }

    private func hideStampPicker(keepStampMode: Bool = false) {
        guard let picker = stampPicker else { return }

        let pickerHeight: CGFloat = isCompact ? 280 : 320

        UIView.animate(withDuration: 0.25, animations: {
            picker.transform = CGAffineTransform(translationX: 0, y: pickerHeight)
            self.colorPalette.alpha = 1
            self.brushSizeControl.alpha = 1
        }) { _ in
            picker.removeFromSuperview()
            self.stampPicker = nil
        }

        isStampPickerVisible = false
        // Only reset to draw mode if not keeping stamp mode (e.g., when user selected a stamp)
        if !keepStampMode {
            canvas.setDrawMode()
        }
    }

    func stampPicker(_ picker: StampPickerView, didSelectStamp stamp: StampType) {
        canvas.setStampMode(stamp)
        hideStampPicker(keepStampMode: true)  // Keep stamp mode so user can place the stamp!

        // Show hint toast
        showToast(message: "Tap to place \(stamp.displayName)!")
    }

    func stampPicker(_ picker: StampPickerView, didSelectCustomSticker sticker: CustomSticker) {
        canvas.setCustomStickerMode(sticker)
        hideStampPicker(keepStampMode: true)

        // Show hint toast
        showToast(message: "Tap to place your sticker!")
    }

    func stampPickerDidClose(_ picker: StampPickerView) {
        hideStampPicker()
    }

    func stampPickerDidRequestNewSticker(_ picker: StampPickerView) {
        presentStickerCreationOptions()
    }

    private func presentStickerCreationOptions() {
        let alert = UIAlertController(
            title: "Create Sticker",
            message: "Turn a photo into a sticker!",
            preferredStyle: .actionSheet
        )

        // Camera option
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }

        // Photo library option
        alert.addAction(UIAlertAction(title: "Choose Photo", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func processImageForSticker(_ image: UIImage) {
        // Show loading indicator
        let loadingView = createLoadingView()
        view.addSubview(loadingView)

        // Process the image
        CustomStickerManager.shared.createSticker(from: image) { [weak self] result in
            DispatchQueue.main.async {
                loadingView.removeFromSuperview()

                switch result {
                case .success(let sticker):
                    SoundManager.shared.play(.pop)
                    SoundManager.shared.playHaptic(.success)
                    self?.showToast(message: "Sticker created!")

                    // Refresh the stamp picker to show new sticker
                    self?.stampPicker?.refreshCustomStickers()

                    // Automatically select the new sticker
                    self?.canvas.setCustomStickerMode(sticker)
                    self?.hideStampPicker(keepStampMode: true)
                    self?.showToast(message: "Tap to place your sticker!")

                case .failure(let error):
                    SoundManager.shared.playHaptic(.error)
                    self?.showToast(message: error.localizedDescription)
                }
            }
        }
    }

    private func createLoadingView() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        container.frame = view.bounds

        let loadingStack = UIStackView()
        loadingStack.axis = .vertical
        loadingStack.alignment = .center
        loadingStack.spacing = 16
        loadingStack.translatesAutoresizingMaskIntoConstraints = false

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.startAnimating()

        let label = UILabel()
        label.text = "Creating sticker..."
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)

        loadingStack.addArrangedSubview(activityIndicator)
        loadingStack.addArrangedSubview(label)
        container.addSubview(loadingStack)

        NSLayoutConstraint.activate([
            loadingStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loadingStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }
}

// MARK: - Background Picker

extension DrawingViewController: BackgroundPickerDelegate {

    private func showBackgroundPicker() {
        guard backgroundPicker == nil else { return }
        hideStampPicker() // Hide stamp picker if visible

        let picker = BackgroundPickerView()
        picker.delegate = self
        picker.selectedColor = canvas.document.backgroundColor
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)

        let pickerHeight: CGFloat = isCompact ? 160 : 180

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            picker.heightAnchor.constraint(equalToConstant: pickerHeight)
        ])

        // Animate in
        picker.transform = CGAffineTransform(translationX: 0, y: pickerHeight)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5) {
            picker.transform = .identity
            self.colorPalette.alpha = 0
            self.brushSizeControl.alpha = 0
        }

        backgroundPicker = picker
        isBackgroundPickerVisible = true

        SoundManager.shared.playHaptic(.medium)
    }

    private func hideBackgroundPicker() {
        guard let picker = backgroundPicker else { return }

        let pickerHeight: CGFloat = isCompact ? 160 : 180

        UIView.animate(withDuration: 0.25, animations: {
            picker.transform = CGAffineTransform(translationX: 0, y: pickerHeight)
            self.colorPalette.alpha = 1
            self.brushSizeControl.alpha = 1
        }) { _ in
            picker.removeFromSuperview()
            self.backgroundPicker = nil
        }

        isBackgroundPickerVisible = false
    }

    func backgroundPicker(_ picker: BackgroundPickerView, didSelectColor color: UIColor) {
        canvas.setBackgroundColor(color)
        hasUnsavedChanges = true
    }

    func backgroundPickerDidClose(_ picker: BackgroundPickerView) {
        hideBackgroundPicker()
    }
}

// MARK: - BrushSizeControlDelegate

extension DrawingViewController: BrushSizeControlDelegate {
    func brushSizeControl(_ control: BrushSizeControl, didChangeSizeMultiplier multiplier: CGFloat) {
        canvas.lineWidthMultiplier = multiplier
    }
}

// MARK: - Image Picker Delegates

extension DrawingViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { [weak self] in
            if let image = info[.originalImage] as? UIImage {
                self?.processImageForSticker(image)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension DrawingViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.processImageForSticker(image)
                } else if error != nil {
                    self?.showToast(message: "Couldn't load photo")
                }
            }
        }
    }
}
