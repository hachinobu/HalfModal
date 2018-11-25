import UIKit

class HalfModalViewController: UIViewController {
    
    private enum State {
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
    private var middleModalPoint: CGFloat {
        return maxDistance * 0.7
    }
    private var middleFractionPoint: CGFloat {
        return (maxDistance - middleModalPoint) / maxDistance
    }
    private var bottomToMiddleDistance: CGFloat {
        return maxDistance - middleModalPoint
    }
    private var middleToTopDistance: CGFloat {
        return maxDistance - bottomToMiddleDistance
    }
    private var modalBottomConstraint = NSLayoutConstraint()
    
    private var modalAnimator = UIViewPropertyAnimator()
    private var animationProgress: CGFloat = 0.0
    private var overlayAnimator = UIViewPropertyAnimator()
    
    private var remainigMiddleDistance: CGFloat = 0.0
    private var isCommingMiddle = false
    private var currentState: State = .bottom
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
        modalBottomConstraint = modalView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: maxDistance)
        view.addSubview(modalView)
        NSLayoutConstraint.activate(
            [
                modalView.leftAnchor.constraint(equalTo: view.leftAnchor),
                modalView.rightAnchor.constraint(equalTo: view.rightAnchor),
                modalBottomConstraint,
                modalView.heightAnchor.constraint(equalToConstant: modalViewHeight)
            ]
        )
    }
    
    private func generateModalAnimator(duration: TimeInterval) {
        let animator = UIViewPropertyAnimator(duration: 1, dampingRatio: 0.9) { [weak self] in
            guard let self = self else { return }
            switch self.currentState {
            case .bottom:
                self.modalBottomConstraint.constant = 0
            case .top:
                self.modalBottomConstraint.constant = self.maxDistance
            case .middle: fatalError()
            }
            self.view.layoutIfNeeded()
        }
        animator.addCompletion { [weak self] position in
            guard let self = self else { return }
            if case .bottom = self.currentState {
                switch position {
                case .start:
                    self.modalBottomConstraint.constant = self.maxDistance
                    self.currentState = .bottom
                case .end:
                    self.modalBottomConstraint.constant = 0
                    self.currentState = .top
                case .current: ()
                }
            } else if case .middle = self.currentState {
                switch position {
                case .start:
                    self.modalBottomConstraint.constant = self.maxDistance
                    self.currentState = .bottom
                case .end:
                    self.modalBottomConstraint.constant = 0
                    self.currentState = .top
                case .current: ()
                }
            } else if case .top = self.currentState {
                switch position {
                case .start:
                    self.modalBottomConstraint.constant = 0
                    self.currentState = .top
                case .end:
                    self.modalBottomConstraint.constant = self.maxDistance
                    self.currentState = .bottom
                case .current: ()
                }
            }
            self.view.layoutIfNeeded()
        }
        modalAnimator = animator
    }
    
    private func generateOverlayAnimator(duration: TimeInterval) {
        let animator = UIViewPropertyAnimator(duration: 1, curve: .easeOut) { [weak self] in
            guard let self = self else { return }
            switch self.currentState {
            case .bottom:
                self.overlayView.alpha = 0.2
            case .top:
                self.overlayView.alpha = 0.0
            case .middle: fatalError()
            }
        }
        overlayAnimator = animator
    }
    
    @objc private func modalViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if modalAnimator.isRunning {
                modalAnimator.pauseAnimation()
                if isCommingMiddle {
                    let currentDistance: CGFloat
                    switch currentState {
                    case .bottom:
                        currentDistance = bottomToMiddleDistance - (remainigMiddleDistance * (1 - modalAnimator.fractionComplete))
                        modalBottomConstraint.constant = maxDistance
                    case .top:
                        currentDistance = (middleToTopDistance - remainigMiddleDistance) + remainigMiddleDistance * modalAnimator.fractionComplete
                        modalBottomConstraint.constant = 0
                    case .middle: fatalError()
                    }
                    animationProgress = currentDistance / maxDistance
                    isCommingMiddle = false
                    modalAnimator.stopAnimation(false)
                    modalAnimator.finishAnimation(at: .current)
                    overlayAnimator.stopAnimation(true)
                    generateModalAnimator(duration: 1)
                    generateOverlayAnimator(duration: 1)
                } else {
                    animationProgress = modalAnimator.isReversed ? 1 - modalAnimator.fractionComplete : modalAnimator.fractionComplete
                    if modalAnimator.isReversed {
                        modalAnimator.isReversed.toggle()
                        overlayAnimator.isReversed.toggle()
                    }
                }
            } else if case .middle = currentState {
                currentState = .bottom
                modalBottomConstraint.constant = maxDistance
                view.layoutIfNeeded()
                animationProgress = bottomToMiddleDistance / maxDistance
                generateModalAnimator(duration: 1)
                generateOverlayAnimator(duration: 1)
            } else {
                animationProgress = 0.0
                generateModalAnimator(duration: 1)
                generateOverlayAnimator(duration: 1)
            }
            
            modalAnimator.startAnimation()
            modalAnimator.pauseAnimation()
            
            overlayAnimator.startAnimation()
            overlayAnimator.pauseAnimation()
            
        case .changed:
            let translation = recognizer.translation(in: modalView)
            switch currentState {
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
            if currentState.isBeginningArea(point: fractionComplete, velocity: velocity, middleFractionPoint: middleFractionPoint) {
                let remainingDistance = maxDistance * modalAnimator.fractionComplete
                let velocityVector = (remainingDistance != 0) ? CGVector(dx: 0, dy: velocity.y/remainingDistance) : .zero
                let spring = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: velocityVector)
                modalAnimator.isReversed = true
                modalAnimator.continueAnimation(withTimingParameters: spring, durationFactor: 0)
                
                overlayAnimator.isReversed = true
                overlayAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            } else if currentState.isEndArea(point: fractionComplete, velocity: velocity, middleFractionPoint: middleFractionPoint) {
                let remainingDistance = maxDistance - (maxDistance * modalAnimator.fractionComplete)
                let velocityVector = (remainingDistance != 0) ? CGVector(dx: 0, dy: velocity.y/remainingDistance) : .zero
                let spring = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: velocityVector)
                modalAnimator.continueAnimation(withTimingParameters: spring, durationFactor: 0)
                overlayAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            } else {
                //To Middle
                modalAnimator.pauseAnimation()
                let toMiddleDistance = currentState == .bottom ? bottomToMiddleDistance : middleToTopDistance
                remainigMiddleDistance = toMiddleDistance - (maxDistance * modalAnimator.fractionComplete)
                modalAnimator.stopAnimation(false)
                modalAnimator.finishAnimation(at: .current)
                modalAnimator.addAnimations {
                    self.modalBottomConstraint.constant = self.middleModalPoint
                    self.view.layoutIfNeeded()
                }
                modalAnimator.addCompletion { [weak self] position in
                    guard let self = self else { return }
                    self.isCommingMiddle = false
                    switch position {
                    case .end:
                        self.currentState = .middle
                        self.modalBottomConstraint.constant = self.middleModalPoint
                    case .start, .current: ()
                    }
                    self.view.layoutIfNeeded()
                }
                isCommingMiddle = true
                let velocityVector = (remainigMiddleDistance != 0) ? CGVector(dx: 0, dy: velocity.y/remainigMiddleDistance) : .zero
                let spring = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: velocityVector)
                modalAnimator.startAnimation()
                modalAnimator.continueAnimation(withTimingParameters: spring, durationFactor: 0)
                
                overlayAnimator.stopAnimation(false)
                overlayAnimator.finishAnimation(at: .current)
                overlayAnimator.addAnimations {
                    self.overlayView.alpha = 0.0
                }
                overlayAnimator.startAnimation()
                overlayAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            }
        default: ()
        }
    }

}
