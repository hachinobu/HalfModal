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
        
//        func isMiddleArea(point: CGFloat, velocity: CGPoint) -> Bool {
//            switch self {
//            case .bottom:
//                return 0.2..<0.65 ~= point
//            case .top:
//                return 0.35..<0.8 ~= point
//            case .middle:
//                fatalError()
//            }
//        }
        
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
    private var modalBottomConstraint = NSLayoutConstraint()
    private var modalAnimator = UIViewPropertyAnimator()
    private var animationProgress: CGFloat = 0.0
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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        modalView.addGestureRecognizer(modalPanRecognizer)
    }
    
    private func setupLayout() {
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
        let animator = UIViewPropertyAnimator(duration: 10, dampingRatio: 0.9) { [weak self] in
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
    
    @objc private func modalViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if modalAnimator.isRunning {
                modalAnimator.pauseAnimation()
                if isCommingMiddle {
                    let currentDistance: CGFloat
                    switch currentState {
                    case .bottom:
                        currentDistance = maxDistance - (remainigMiddleDistance * (1 - modalAnimator.fractionComplete)) - middleModalPoint
                        modalBottomConstraint.constant = maxDistance
                    case .top:
                        currentDistance = (middleModalPoint - remainigMiddleDistance) + remainigMiddleDistance * modalAnimator.fractionComplete
                        modalBottomConstraint.constant = 0
                    case .middle: fatalError()
                    }
                    animationProgress = currentDistance / maxDistance
                    isCommingMiddle = false
                    modalAnimator.stopAnimation(false)
                    modalAnimator.finishAnimation(at: .current)
                    generateModalAnimator(duration: 1)
                } else {
                    animationProgress = modalAnimator.isReversed ? 1 - modalAnimator.fractionComplete : modalAnimator.fractionComplete
                    if modalAnimator.isReversed { modalAnimator.isReversed.toggle() }
                }
            } else if case .middle = currentState {
                currentState = .bottom
                modalBottomConstraint.constant = maxDistance
                view.layoutIfNeeded()
                animationProgress = (maxDistance - middleModalPoint) / maxDistance
                generateModalAnimator(duration: 1)
            } else {
                animationProgress = 0.0
                generateModalAnimator(duration: 1)
            }
            
            modalAnimator.startAnimation()
            modalAnimator.pauseAnimation()
            modalAnimator.fractionComplete = animationProgress
            
        case .changed:
            let translation = recognizer.translation(in: modalView)
            switch currentState {
            case .bottom:
                modalAnimator.fractionComplete = -translation.y / maxDistance + animationProgress
            case .top:
                modalAnimator.fractionComplete = translation.y / maxDistance + animationProgress
            case .middle: fatalError()
            }
            print(modalAnimator.fractionComplete)
        case .ended:
            let fractionComplete = modalAnimator.fractionComplete
            let velocity = recognizer.velocity(in: modalView)
//            print(fractionComplete)
            print(velocity)
            if currentState.isBeginningArea(point: fractionComplete, velocity: velocity, middleFractionPoint: middleFractionPoint) {
                modalAnimator.isReversed = true
                modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
            } else if currentState.isEndArea(point: fractionComplete, velocity: velocity, middleFractionPoint: middleFractionPoint) {
                let remainingDistance = maxDistance - (maxDistance * modalAnimator.fractionComplete)
                let velocityVector = (remainingDistance != 0) ? CGVector(dx: 0, dy: velocity.y/remainingDistance) : .zero
                let spring = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: velocityVector)
                modalAnimator.continueAnimation(withTimingParameters: spring, durationFactor: 0)
//                let velocityThreshold: CGFloat = 8.0
//                let dy = abs(velocityVector.dy)
//                let damping = dy > velocityThreshold ? 0.3 : 1.0
//                print(velocity.y)
//                let spring = UISpringTimingParameters(dampingRatio: CGFloat(damping), frequencyResponse: 0.3, initialVelocity: velocityVector)
//                let sp2 = UISpringTimingParameters(dampingRatio: 0.1, initialVelocity: velocityVector)
//                modalAnimator.continueAnimation(withTimingParameters: spring, durationFactor: 1)
            } else {
                modalAnimator.pauseAnimation()
                remainigMiddleDistance = maxDistance - (maxDistance * modalAnimator.fractionComplete) - middleModalPoint
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
                modalAnimator.startAnimation()
                modalAnimator.pauseAnimation()
                modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
            }
        default: ()
        }
    }

}

//extension UISpringTimingParameters {
//    public convenience init(dampingRatio: CGFloat, frequencyResponse: CGFloat, initialVelocity: CGVector = .zero) {
//        let mass = 1 as CGFloat
//        let stiffness = pow(2 * .pi / frequencyResponse, 2) * mass
//        let damp = 4 * .pi * dampingRatio * mass / frequencyResponse
//        self.init(mass: mass, stiffness: stiffness, damping: damp, initialVelocity: initialVelocity)
//    }
//}
