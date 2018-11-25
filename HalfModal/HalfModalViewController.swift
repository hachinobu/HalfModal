import UIKit

class HalfModalViewController: UIViewController {
    
    private enum Area {
        case top
        case middle
        case bottom
        
        func isBeginningArea(point: CGFloat, velocity: CGPoint, middleFractionPoint: CGFloat) -> Bool {
            switch self {
            case .bottom:
                return velocity.y > 300 || 0.0..<0.2 ~= point && velocity.y >= 0.0 || middleFractionPoint >= point && velocity.y > 0
            case .top:
                return velocity.y < 0.0 || 0.0..<0.35 ~= point && velocity.y <= 0.0 || middleFractionPoint >= point && velocity.y < 0.0
            case .middle:
                fatalError()
            }
        }
                
        func isEndArea(point: CGFloat, velocity: CGPoint, middleFractionPoint: CGFloat) -> Bool {
            switch self {
            case .bottom:
                return velocity.y < -300 || 0.65... ~= point && velocity.y <= 0 || middleFractionPoint <= point && velocity.y < 0
            case .top:
                return velocity.y > 300 || 0.8... ~= point && velocity.y >= 0 || middleFractionPoint <= point && velocity.y > 0
            case .middle:
                fatalError()
            }
        }
        
    }
    
    private let modalViewHeight: CGFloat = UIScreen.main.bounds.height - 64
    private var maxDistance: CGFloat {
        return modalViewHeight - 60
    }
    private var middleConstantPoint: CGFloat {
        return maxDistance * 0.7
    }
    private var middleFractionPoint: CGFloat {
        return (maxDistance - middleConstantPoint) / maxDistance
    }
    private var bottomToMiddleDistance: CGFloat {
        return maxDistance - middleConstantPoint
    }
    private var middleToTopDistance: CGFloat {
        return maxDistance - bottomToMiddleDistance
    }
    
    private var modalAnimator = UIViewPropertyAnimator()
    private var animationProgress: CGFloat = 0.0
    private var overlayAnimator = UIViewPropertyAnimator()
    
    private var remainigMiddleDistance: CGFloat = 0.0
    private var isRunningToMiddle = false
    private var currentArea: Area = .bottom
    
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
    }
    
    @objc private func modalViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if modalAnimator.isRunning {
                modalAnimator.pauseAnimation()
                if isRunningToMiddle {
                    let currentDistance: CGFloat
                    switch currentArea {
                    case .bottom:
                        currentDistance = bottomToMiddleDistance - (remainigMiddleDistance * (1 - modalAnimator.fractionComplete))
                        modalViewBottomConstraint.constant = maxDistance
                    case .top:
                        currentDistance = (middleToTopDistance - remainigMiddleDistance) + remainigMiddleDistance * modalAnimator.fractionComplete
                        modalViewBottomConstraint.constant = 0
                    case .middle: fatalError()
                    }
                    animationProgress = currentDistance / maxDistance
                    isRunningToMiddle = false
                    modalAnimator.stopAnimation(false)
                    modalAnimator.finishAnimation(at: .current)
                    overlayAnimator.stopAnimation(true)
                    generateAnimator()
                } else {
                    animationProgress = modalAnimator.isReversed ? 1 - modalAnimator.fractionComplete : modalAnimator.fractionComplete
                    if modalAnimator.isReversed {
                        modalAnimator.isReversed.toggle()
                        overlayAnimator.isReversed.toggle()
                    }
                }
            } else if case .middle = currentArea {
                currentArea = .bottom
                modalViewBottomConstraint.constant = maxDistance
                view.layoutIfNeeded()
                animationProgress = bottomToMiddleDistance / maxDistance
                generateAnimator()
            } else {
                animationProgress = 0.0
                generateAnimator()
            }
            
            modalAnimator.startAnimation()
            modalAnimator.pauseAnimation()
            
            overlayAnimator.startAnimation()
            overlayAnimator.pauseAnimation()
            
        case .changed:
            let translation = recognizer.translation(in: modalView)
            switch currentArea {
            case .bottom:
                modalAnimator.fractionComplete = -translation.y / maxDistance + animationProgress
                overlayAnimator.fractionComplete = ((maxDistance * modalAnimator.fractionComplete) - bottomToMiddleDistance) / middleToTopDistance
            case .top:
                modalAnimator.fractionComplete = translation.y / maxDistance + animationProgress
                overlayAnimator.fractionComplete = (maxDistance * modalAnimator.fractionComplete) / middleToTopDistance
            case .middle: fatalError()
            }
        case .ended:
            let fractionComplete = modalAnimator.fractionComplete
            let velocity = recognizer.velocity(in: modalView)
            if currentArea.isBeginningArea(point: fractionComplete, velocity: velocity, middleFractionPoint: middleFractionPoint) {
                let remainingFraction = 1 - modalAnimator.fractionComplete
                let remainingDistance = maxDistance * remainingFraction
                modalAnimator.isReversed = true
                overlayAnimator.isReversed = true
                if remainingDistance == 0 {
                    modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                    overlayAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                } else {
                    let relativeVelocity = abs(velocity.y) / remainingDistance
                    let timigParameters = UISpringTimingParameters(damping: 0.8, response: 0.3, initialVelocity: CGVector(dx: relativeVelocity, dy: relativeVelocity))
                    let newDuration = UIViewPropertyAnimator(duration: 0, timingParameters: timigParameters).duration
                    let durationFactor = CGFloat(newDuration/modalAnimator.duration)
                    modalAnimator.continueAnimation(withTimingParameters: timigParameters, durationFactor: durationFactor)
                    overlayAnimator.continueAnimation(withTimingParameters: timigParameters, durationFactor: durationFactor)
                }
            } else if currentArea.isEndArea(point: fractionComplete, velocity: velocity, middleFractionPoint: middleFractionPoint) {
                let remainingFraction = 1 - modalAnimator.fractionComplete
                let remainingDistance = maxDistance * remainingFraction
                if remainingDistance == 0 {
                    modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                    overlayAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                } else {
                    let relativeVelocity = abs(velocity.y) / remainingDistance
                    let timigParameters = UISpringTimingParameters(damping: 0.8, response: 0.3, initialVelocity: CGVector(dx: relativeVelocity, dy: relativeVelocity))
                    let newDuration = UIViewPropertyAnimator(duration: 0, timingParameters: timigParameters).duration
                    let durationFactor = CGFloat(newDuration/modalAnimator.duration)
                    modalAnimator.continueAnimation(withTimingParameters: timigParameters, durationFactor: durationFactor)
                    overlayAnimator.continueAnimation(withTimingParameters: timigParameters, durationFactor: durationFactor)
                }
            } else {
                //To Middle
                modalAnimator.pauseAnimation()
                let toMiddleDistance = currentArea == .bottom ? bottomToMiddleDistance : middleToTopDistance
                remainigMiddleDistance = toMiddleDistance - (maxDistance * modalAnimator.fractionComplete)
                modalAnimator.stopAnimation(false)
                modalAnimator.finishAnimation(at: .current)
                modalAnimator.addAnimations {
                    self.modalViewBottomConstraint.constant = self.middleConstantPoint
                    self.view.layoutIfNeeded()
                }
                modalAnimator.addCompletion { [weak self] position in
                    guard let self = self else { return }
                    self.isRunningToMiddle = false
                    switch position {
                    case .end:
                        self.currentArea = .middle
                        self.modalViewBottomConstraint.constant = self.middleConstantPoint
                    case .start, .current: ()
                    }
                    self.view.layoutIfNeeded()
                }
                
                isRunningToMiddle = true
                modalAnimator.startAnimation()
                
                overlayAnimator.stopAnimation(false)
                overlayAnimator.finishAnimation(at: .current)
                overlayAnimator.addAnimations {
                    self.overlayView.alpha = 0.0
                }
                overlayAnimator.startAnimation()
                
                if remainigMiddleDistance == 0 {
                    modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                    overlayAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                } else {
                    let relativeVelocity = abs(velocity.y) / remainigMiddleDistance
                    let timigParameters = UISpringTimingParameters(damping: 0.8, response: 0.3, initialVelocity: CGVector(dx: relativeVelocity, dy: relativeVelocity))
                    let newDuration = UIViewPropertyAnimator(duration: 0, timingParameters: timigParameters).duration
                    let durationFactor = CGFloat(newDuration/modalAnimator.duration)
                    modalAnimator.continueAnimation(withTimingParameters: timigParameters, durationFactor: durationFactor)
                    overlayAnimator.continueAnimation(withTimingParameters: timigParameters, durationFactor: durationFactor)
                }
            }
        default: ()
        }
    }

}

extension HalfModalViewController {
    
    private func generateAnimator(duration: TimeInterval = 1.0) {
        modalAnimator = generateModalAnimator(duration: duration)
        overlayAnimator = generateOverlayAnimator(duration: duration)
    }
    
    private func generateModalAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9) { [weak self] in
            guard let self = self else { return }
            switch self.currentArea {
            case .bottom:
                self.modalViewBottomConstraint.constant = 0
            case .top:
                self.modalViewBottomConstraint.constant = self.maxDistance
            case .middle: fatalError()
            }
            self.view.layoutIfNeeded()
        }
        animator.addCompletion { position in
            switch self.currentArea {
            case .bottom:
                if position == .start {
                    self.modalViewBottomConstraint.constant = self.maxDistance
                    self.currentArea = .bottom
                } else if position == .end {
                    self.modalViewBottomConstraint.constant = 0
                    self.currentArea = .top
                }
            case .top:
                if position == .start {
                    self.modalViewBottomConstraint.constant = 0
                    self.currentArea = .top
                } else if position == .end {
                    self.modalViewBottomConstraint.constant = self.maxDistance
                    self.currentArea = .bottom
                }
            case .middle: fatalError()
            }
            self.view.layoutIfNeeded()
        }
        return animator
    }
    
    private func generateOverlayAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut) { [weak self] in
            guard let self = self else { return }
            switch self.currentArea {
            case .bottom:
                self.overlayView.alpha = 0.2
            case .top:
                self.overlayView.alpha = 0.0
            case .middle: fatalError()
            }
        }
        return animator
    }
    
}
