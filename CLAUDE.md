# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CreativeDrawing is a kid-friendly iOS drawing app built with UIKit. The app targets iOS 15+ and is designed for both phones and tablets with adaptive layouts. It features multiple brush types, stamps/stickers, symmetry drawing, flood fill, and drawing persistence.

## Build Commands

```bash
# Build the project
xcodebuild -project CreativeDrawing.xcodeproj -scheme CreativeDrawing -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for a specific configuration
xcodebuild -project CreativeDrawing.xcodeproj -scheme CreativeDrawing -configuration Debug build

# Clean build
xcodebuild -project CreativeDrawing.xcodeproj -scheme CreativeDrawing clean build
```

## Architecture

### Core Components

**DrawingViewController** (`DrawingViewController.swift`)
- Main view controller orchestrating all UI components
- Manages canvas, toolbar, color palette, and brush size control
- Handles drawing persistence with auto-save every 30 seconds
- Implements adaptive layout for compact (phones) vs regular (tablets) size classes

**DrawingCanvas** (`Views/DrawingCanvas.swift`)
- UIView subclass handling touch input and stroke rendering
- Uses Catmull-Rom spline interpolation for smooth curves
- Implements custom rendering for each brush type (pencil, marker, crayon, sparkle, rainbow, eraser)
- Supports symmetry modes: horizontal mirror, vertical flip, and quad/kaleidoscope
- Caches completed strokes as UIImage for performance

**DrawingDocument** (`Models/DrawingDocument.swift`)
- Document model managing strokes, stamps, and fills
- Full undo/redo system with 50 levels max
- JSON serialization for persistence
- Exports drawings as UIImage

### Data Flow

```
Touch Input → DrawingCanvas → Stroke/Stamp/Fill → DrawingDocument → DrawingStorage
                                                          ↓
                                                   Undo/Redo Stack
```

### Key Delegate Patterns

- `DrawingCanvasDelegate`: Canvas → ViewController (drawing state changes)
- `ToolbarDelegate`: Toolbar → ViewController (brush/tool selection, undo/redo)
- `ColorPaletteDelegate`: ColorPalette → ViewController (color selection)
- `StampPickerDelegate`: StampPicker → ViewController (stamp/sticker selection)
- `BrushSizeControlDelegate`: BrushSize → ViewController (size changes)

### Managers (Singletons)

- **DrawingStorage**: Thread-safe file persistence for drawings, thumbnails, and metadata
- **CustomStickerManager**: Vision AI integration (iOS 17+ VNGenerateForegroundInstanceMaskRequest or saliency fallback) for creating stickers from photos
- **SoundManager**: Haptic feedback and sound effects

### Models

- **Stroke**: Collection of StrokePoints with brush type, color, and line width
- **Stamp**: Positioned SF Symbol or custom image with scale/rotation
- **FillRegion**: Flood-filled area stored as UIImage
- **BrushType**: Enum defining pencil, marker, crayon, sparkle, rainbow, eraser with associated rendering properties

## Key Patterns

### Adaptive Layout
The app uses trait collection changes to switch between compact and regular constraints. Check `traitCollectionDidChange` and `isCompact` property usage.

### Deterministic Noise
Brush textures use `deterministicNoise(_:_:seed:)` for consistent rendering across redraws. This is critical for pencil/crayon texture stability.

### Stroke Smoothing
All strokes use Catmull-Rom spline via `Stroke.smoothedPoints(granularity:)` for smooth curves.

### Thread Safety
DrawingStorage uses a serial DispatchQueue for all file operations. Always access through the shared instance.
