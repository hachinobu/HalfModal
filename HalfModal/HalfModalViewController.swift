import UIKit

class HalfModalViewController: UIViewController {
    
    private enum State {
        enum Position {
            case top
            case middle
            case bottom
        }
        case closed(Position)
        case open(Position)
    }
    
    private let modalViewHeight: CGFloat = 500
    private lazy var maxDistance: CGFloat = self.modalViewHeight - 60
    private lazy var middleModalPoint: CGFloat = 200
    private var modalBottomConstraint = NSLayoutConstraint()
    private var modalAnimator = UIViewPropertyAnimator()
    private var animationProgress: CGFloat = 0.0
    private var remainigMiddleDistance: CGFloat = 0.0
    private var isCommingMiddle = false
    private var currentState: State = .closed(.bottom)
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
            case .open:
                self.modalBottomConstraint.constant = self.maxDistance
            case .closed:
                self.modalBottomConstraint.constant = 0
            }
            self.view.layoutIfNeeded()
        }
        animator.addCompletion { [weak self] position in
            guard let self = self else { return }
            if case .closed(.bottom) = self.currentState {
                switch position {
                case .start:
                    self.modalBottomConstraint.constant = self.maxDistance
                    self.currentState = .closed(.bottom)
                case .end:
                    self.modalBottomConstraint.constant = 0
                    self.currentState = .open(.top)
                case .current: ()
                }
            } else if case .closed(.middle) = self.currentState {
                switch position {
                case .start:
                    self.modalBottomConstraint.constant = self.maxDistance
                    self.currentState = .closed(.bottom)
                case .end:
                    self.modalBottomConstraint.constant = 0
                    self.currentState = .open(.top)
                case .current: ()
                }
            } else if case .open(.top) = self.currentState {
                switch position {
                case .start:
                    self.modalBottomConstraint.constant = 0
                    self.currentState = .open(.top)
                case .end:
                    self.modalBottomConstraint.constant = self.maxDistance
                    self.currentState = .closed(.bottom)
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
                    case .closed:
                        currentDistance = maxDistance - (remainigMiddleDistance * (1 - modalAnimator.fractionComplete)) - middleModalPoint
                        modalBottomConstraint.constant = maxDistance
                    case .open:
                        currentDistance = (middleModalPoint - remainigMiddleDistance) + remainigMiddleDistance * modalAnimator.fractionComplete
                        modalBottomConstraint.constant = 0
                    }
                    animationProgress = currentDistance / maxDistance
                    isCommingMiddle = false
                    modalAnimator.stopAnimation(false)
                    modalAnimator.finishAnimation(at: .current)
                    generateModalAnimator(duration: 1)
                } else {
                    animationProgress = modalAnimator.isReversed ? 1 - modalAnimator.fractionComplete : modalAnimator.fractionComplete
                }
            } else if case .closed(.middle) = currentState {
                currentState = .closed(.bottom)
                modalBottomConstraint.constant = maxDistance
                view.layoutIfNeeded()
                animationProgress = (maxDistance - middleModalPoint) / maxDistance
                generateModalAnimator(duration: 1)
            } else {
                animationProgress = 0.0
                generateModalAnimator(duration: 1)
            }
            
            modalAnimator.fractionComplete = animationProgress
            modalAnimator.startAnimation()
            modalAnimator.pauseAnimation()
            
        case .changed:
            let translation = recognizer.translation(in: modalView)
            if case .closed(.middle) = currentState {
                let fraction = -translation.y / maxDistance + animationProgress
                modalAnimator.fractionComplete = fraction
            } else {
                switch currentState {
                case .closed:
                    modalAnimator.fractionComplete = -translation.y / maxDistance + animationProgress
                case .open:
                    modalAnimator.fractionComplete = translation.y / maxDistance + animationProgress
                }
            }
        case .ended:
            if 0.2...0.6 ~= modalAnimator.fractionComplete {
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
                        self.currentState = .closed(.middle)
                        self.modalBottomConstraint.constant = self.middleModalPoint
                    case .start, .current: ()
                    }
                    self.view.layoutIfNeeded()
                }
                isCommingMiddle = true
                modalAnimator.startAnimation()
                modalAnimator.pauseAnimation()
                modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 3)
            } else {
                modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
            }
        default: ()
        }
    }

}
