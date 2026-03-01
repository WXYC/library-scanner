//
//  CameraPreviewView.swift
//  ScannerUI
//
//  UIViewRepresentable wrapping AVCaptureVideoPreviewLayer to display
//  a live camera feed in SwiftUI.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import AVFoundation

/// Displays a live camera preview by wrapping an `AVCaptureVideoPreviewLayer`.
///
/// Pass the `AVCaptureSession` from the camera service. The preview layer
/// fills the available space and uses aspect-fill scaling.
public struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

/// A UIView whose backing layer is an `AVCaptureVideoPreviewLayer`.
public final class PreviewUIView: UIView {
    override public class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
