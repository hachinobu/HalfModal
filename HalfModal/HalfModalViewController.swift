import UIKit

class HalfModalViewController: UIViewController {
    
    private enum ModalPosition {
        case top
        case middle
        case bottom
        
        func isBeginningArea(fractionPoint: CGFloat, velocity: CGPoint, middleAreaBorderPoint: CGFloat) -> Bool {
            switch self {
            case .bottom:
                return velocity.y > 300 || ..<0.2 ~= fractionPoint && velocity.y >= 0.0 || middleAreaBorderPoint >= fractionPoint && velocity.y > 0
            case .top:
                return velocity.y < 0.0 || ..<0.35 ~= fractionPoint && velocity.y <= 0.0 || middleAreaBorderPoint >= fractionPoint && velocity.y < 0.0
            case .middle:
                fatalError()
            }
        }
                
        func isEndArea(fractionPoint: CGFloat, velocity: CGPoint, middleAreaBorderPoint: CGFloat) -> Bool {
            switch self {
            case .bottom:
                return velocity.y < -300 || 0.65... ~= fractionPoint && velocity.y <= 0 || middleAreaBorderPoint <= fractionPoint && velocity.y < 0
            case .top:
                return velocity.y > 300 || 0.8... ~= fractionPoint && velocity.y >= 0 || middleAreaBorderPoint <= fractionPoint && velocity.y > 0
            case .middle:
                fatalError()
            }
        }
        
    }
    
    private let modalViewHeight: CGFloat = UIScreen.main.bounds.height - 64
    private var maxDistance: CGFloat {
        return modalViewHeight - 60 - topPositionConstant
    }
    private let topPositionConstant: CGFloat = 0.0
    private var middlePositionConstant: CGFloat {
        return maxDistance * 0.7
    }
    private var bottomPositionConstant: CGFloat {
        return maxDistance
    }
    private var middlePositionFractionValue: CGFloat {
        return bottomToMiddleDistance / maxDistance
    }
    private var bottomToMiddleDistance: CGFloat {
        return maxDistance - middlePositionConstant
    }
    private var middleToTopDistance: CGFloat {
        return maxDistance - bottomToMiddleDistance
    }
    
    private var modalAnimator = UIViewPropertyAnimator()
    private var modalAnimatorProgress: CGFloat = 0.0
    private var overlayAnimator = UIViewPropertyAnimator()
    
    private var remainigToMiddleDistance: CGFloat = 0.0
    private var isRunningToMiddle = false
    private var currentModalPosition: ModalPosition = .bottom
    
    private lazy var modalPanRecognizer: InstantPanGestureRecognizer = {
        let panRecognizer = InstantPanGestureRecognizer()
        panRecognizer.addTarget(self, action: #selector(self.modalViewPanned(recognizer:)))
        return panRecognizer
    }()
    
    private lazy var modalView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 10
        return view
    }()
    
    private lazy var overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.0
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private var modalViewBottomConstraint = NSLayoutConstraint()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        modalView.addGestureRecognizer(modalPanRecognizer)
    }
    
    private func setupLayout() {
        view.backgroundColor = UIColor(red: 239/255, green: 239/255, blue: 244/255, alpha: 1.0)
        
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        NSLayoutConstraint.activate(
            [
                overlayView.topAnchor.constraint(equalTo: view.topAnchor),
                overlayView.leftAnchor.constraint(equalTo: view.leftAnchor),
                overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                overlayView.rightAnchor.constraint(equalTo: view.rightAnchor)
            ]
        )
        
        modalView.translatesAutoresizingMaskIntoConstraints = false
        modalViewBottomConstraint = modalView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: maxDistance)
        view.addSubview(modalView)
        NSLayoutConstraint.activate(
            [
                modalView.leftAnchor.constraint(equalTo: view.leftAnchor),
                modalView.rightAnchor.constraint(equalTo: view.rightAnchor),
                modalViewBottomConstraint,
                modalView.heightAnchor.constraint(equalToConstant: modalViewHeight)
            ]
        )
        
        let barView = UIView()
        barView.backgroundColor = .lightGray
        barView.translatesAutoresizingMaskIntoConstraints = false
        barView.layer.cornerRadius = 2.5
        modalView.addSubview(barView)
        NSLayoutConstraint.activate(
            [
                barView.topAnchor.constraint(equalTo: modalView.topAnchor, constant: 8.0),
                barView.widthAnchor.constraint(equalToConstant: 40.0),
                barView.heightAnchor.constraint(equalToConstant: 5.0),
                barView.centerXAnchor.constraint(equalTo: modalView.centerXAnchor)
            ]
        )
    }
    
    @objc private func modalViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            beganInteractionAnimator()
            activeAnimator()
            
        case .changed:
            let translation = recognizer.translation(in: modalView)
            switch currentModalPosition {
            case .bottom:
                modalAnimator.fractionComplete = -translation.y / maxDistance + modalAnimatorProgress
                overlayAnimator.fractionComplete = ((maxDistance * modalAnimator.fractionComplete) - bottomToMiddleDistance) / middleToTopDistance
            case .top:
                modalAnimator.fractionComplete = translation.y / maxDistance + modalAnimatorProgress
                overlayAnimator.fractionComplete = (maxDistance * modalAnimator.fractionComplete) / middleToTopDistance
            case .middle: fatalError()
            }
            
        case .ended:
            let v = recognizer.velocity(in: modalView)
            continueInteractionAnimator(velocity: v)
            
        default: ()
        }
    }
    
    private func beganInteractionAnimator() {
        if !modalAnimator.isRunning {
            if currentModalPosition == .middle {
                currentModalPosition = .bottom
                modalViewBottomConstraint.constant = bottomPositionConstant
                view.layoutIfNeeded()
                modalAnimatorProgress = middlePositionFractionValue
            } else {
                modalAnimatorProgress = 0.0
            }
            generateAnimator()
        } else if isRunningToMiddle {
            modalAnimator.pauseAnimation()
            isRunningToMiddle.toggle()
            let currentConstantPoint: CGFloat
            switch currentModalPosition {
            case .bottom:
                currentConstantPoint = bottomToMiddleDistance - remainigToMiddleDistance * (1 - modalAnimator.fractionComplete)
                modalViewBottomConstraint.constant = bottomPositionConstant
            case .top:
                currentConstantPoint = (middleToTopDistance - remainigToMiddleDistance) + remainigToMiddleDistance * modalAnimator.fractionComplete
                modalViewBottomConstraint.constant = topPositionConstant
            case .middle: fatalError()
            }
            modalAnimatorProgress = currentConstantPoint / maxDistance
            stopAnimator()
            
            generateAnimator()
        } else {
            modalAnimator.pauseAnimation()
            modalAnimatorProgress = modalAnimator.isReversed ? 1 - modalAnimator.fractionComplete : modalAnimator.fractionComplete
            if modalAnimator.isReversed {
                modalAnimator.isReversed.toggle()
                overlayAnimator.isReversed.toggle()
            }
        }
    }
    
    private func continueInteractionAnimator(velocity: CGPoint) {
        let fractionComplete = modalAnimator.fractionComplete
        if currentModalPosition.isBeginningArea(fractionPoint: fractionComplete, velocity: velocity, middleAreaBorderPoint: middlePositionFractionValue) {
            begginingAreaContinueInteractionAnimator(velocity: velocity)
        } else if currentModalPosition.isEndArea(fractionPoint: fractionComplete, velocity: velocity, middleAreaBorderPoint: middlePositionFractionValue) {
            endAreaContinueInteractionAnimator(velocity: velocity)
        } else {
            middleAreaContinueInteractionAnimator(velocity: velocity)
        }
    }
    
    private func calculateContinueAnimatorParams(remainingDistance: CGFloat, velocity: CGPoint) -> (timingParameters: UITimingCurveProvider?, durationFactor: CGFloat) {
        if remainingDistance == 0 {
            return (nil, 0)
        }
        let relativeVelocity = abs(velocity.y) / remainingDistance
        let timingParameters = UISpringTimingParameters(damping: 0.8, response: 0.3, initialVelocity: CGVector(dx: relativeVelocity, dy: relativeVelocity))
        let newDuration = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters).duration
        let durationFactor = CGFloat(newDuration/modalAnimator.duration)
        return (timingParameters, durationFactor)
    }
    
    private func begginingAreaContinueInteractionAnimator(velocity: CGPoint) {
        let remainingFraction = 1 - modalAnimator.fractionComplete
        let remainingDistance = maxDistance * remainingFraction
        reverseAnimator()
        let continueAnimatorParams = calculateContinueAnimatorParams(remainingDistance: remainingDistance, velocity: velocity)
        continueAnimator(parameters: continueAnimatorParams.timingParameters, durationFactor: continueAnimatorParams.durationFactor)
    }
    
    private func endAreaContinueInteractionAnimator(velocity: CGPoint) {
        let remainingFraction = 1 - modalAnimator.fractionComplete
        let remainingDistance = maxDistance * remainingFraction
        let continueAnimatorParams = calculateContinueAnimatorParams(remainingDistance: remainingDistance, velocity: velocity)
        continueAnimator(parameters: continueAnimatorParams.timingParameters, durationFactor: continueAnimatorParams.durationFactor)
    }
    
    private func middleAreaContinueInteractionAnimator(velocity: CGPoint) {
        modalAnimator.pauseAnimation()
        overlayAnimator.pauseAnimation()
        let toMiddleDistance = currentModalPosition == .bottom ? bottomToMiddleDistance : middleToTopDistance
        remainigToMiddleDistance = toMiddleDistance - (maxDistance * modalAnimator.fractionComplete)
        
        stopAnimator()
        modalAnimator.addAnimations {
            self.modalViewBottomConstraint.constant = self.middlePositionConstant
            self.view.layoutIfNeeded()
        }
        modalAnimator.addCompletion { position in
            self.isRunningToMiddle = false
            switch position {
            case .end:
                self.currentModalPosition = .middle
                self.modalViewBottomConstraint.constant = self.middlePositionConstant
            case .start, .current: ()
            }
            self.view.layoutIfNeeded()
        }
        isRunningToMiddle = true
        
        overlayAnimator.addAnimations {
            self.overlayView.alpha = 0.0
        }
        activeAnimator()
        let continueAnimatorParams = calculateContinueAnimatorParams(remainingDistance: remainigToMiddleDistance, velocity: velocity)
        continueAnimator(parameters: continueAnimatorParams.timingParameters, durationFactor: continueAnimatorParams.durationFactor)
    }

}

extension HalfModalViewController {
    
    private func generateAnimator(duration: TimeInterval = 1.0) {
        // Fix:  Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'It is an error to release a paused or stopped property animator. Property animators must either finish animating or be explicitly stopped and finished before they can be released.'
        do {
            if modalAnimator.state == .active {
                stopModalAnimator()
            }
            if overlayAnimator.state == .active {
                stopOverlayAnimator()
            }
        }
        
        modalAnimator = generateModalAnimator(duration: duration)
        overlayAnimator = generateOverlayAnimator(duration: duration)
    }
    
    private func generateModalAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0) {
            switch self.currentModalPosition {
            case .bottom:
                self.modalViewBottomConstraint.constant = self.topPositionConstant
            case .top:
                self.modalViewBottomConstraint.constant = self.bottomPositionConstant
            case .middle: fatalError()
            }
            self.view.layoutIfNeeded()
        }
        animator.addCompletion { position in
            switch self.currentModalPosition {
            case .bottom:
                if position == .start {
                    self.modalViewBottomConstraint.constant = self.bottomPositionConstant
                    self.currentModalPosition = .bottom
                } else if position == .end {
                    self.modalViewBottomConstraint.constant = self.topPositionConstant
                    self.currentModalPosition = .top
                }
            case .top:
                if position == .start {
                    self.modalViewBottomConstraint.constant = self.topPositionConstant
                    self.currentModalPosition = .top
                } else if position == .end {
                    self.modalViewBottomConstraint.constant = self.bottomPositionConstant
                    self.currentModalPosition = .bottom
                }
            case .middle: fatalError()
            }
            self.view.layoutIfNeeded()
        }
        return animator
    }
    
    private func generateOverlayAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut) {
            switch self.currentModalPosition {
            case .bottom:
                self.overlayView.alpha = 0.2
            case .top:
                self.overlayView.alpha = 0.0
            case .middle: fatalError()
            }
        }
        return animator
    }
    
    private func activeAnimator() {
        modalAnimator.startAnimation()
        modalAnimator.pauseAnimation()
        
        overlayAnimator.startAnimation()
        overlayAnimator.pauseAnimation()
    }
    
    private func stopAnimator() {
        stopModalAnimator()
        stopOverlayAnimator()
    }
    
    private func stopModalAnimator() {
        modalAnimator.stopAnimation(false)
        modalAnimator.finishAnimation(at: .current)
    }
    
    private func stopOverlayAnimator() {
        overlayAnimator.stopAnimation(true)
    }
    
    private func reverseAnimator() {
        modalAnimator.isReversed = true
        overlayAnimator.isReversed = true
    }
    
    private func continueAnimator(parameters: UITimingCurveProvider?, durationFactor: CGFloat) {
        modalAnimator.continueAnimation(withTimingParameters: parameters, durationFactor: durationFactor)
        overlayAnimator.continueAnimation(withTimingParameters: parameters, durationFactor: durationFactor)
    }
    
}
