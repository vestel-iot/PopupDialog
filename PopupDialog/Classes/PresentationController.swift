//
//  PopupDialogPresentationController.swift
//
//  Copyright (c) 2016 Orderella Ltd. (http://orderella.co.uk)
//  Author - Martin Wildfeuer (http://www.mwfire.de)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import UIKit

final internal class PresentationController: UIPresentationController {

    private lazy var overlay: PopupDialogOverlayView = {
        return PopupDialogOverlayView(frame: .zero)
    }()
    
    private var blurredImageView: UIImageView?

    override var shouldRemovePresentersView: Bool {
        return false
    }
    
    private func createBlurredSnapshot(from view: UIView, blurRadius: CGFloat) -> UIImage? {
        // Render the view to an image
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        
        guard let ciImage = CIImage(image: image) else { return image }
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(blurRadius, forKey: kCIInputRadiusKey)
        
        guard let outputImage = filter?.outputImage else { return image }
        
        let context = CIContext(options: nil)
        // Crop to original bounds (blur extends beyond original bounds)
        let croppedImage = outputImage.cropped(to: ciImage.extent)
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else { return image }
        
        return UIImage(cgImage: cgImage)
    }

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        if let presentingView = presentingViewController.view {
            if let blurredImage = createBlurredSnapshot(from: presentingView, blurRadius: 1) {
                blurredImageView = UIImageView(image: blurredImage)
                blurredImageView?.frame = containerView.bounds
                blurredImageView?.contentMode = .scaleAspectFill
                containerView.addSubview(blurredImageView!)
            }
        }
        
        // Add dimming overlay on top
        overlay.frame = containerView.bounds
        containerView.addSubview(overlay)
        
        if let presentedView = presentedView {
            containerView.addSubview(presentedView)
        }
        
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.overlay.alpha = 1.0
        }, completion: nil)
    }

    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.overlay.alpha = 0.0
        }, completion: nil)
    }

    override func containerViewWillLayoutSubviews() {

        guard let presentedView = presentedView else { return }
        
        presentedView.frame = frameOfPresentedViewInContainerView
        overlay.frame = containerView?.bounds ?? .zero
        blurredImageView?.frame = containerView?.bounds ?? .zero
    }

}
