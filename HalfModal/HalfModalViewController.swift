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
    
    private var test = false
    private let modalViewHeight: CGFloat = 500
    private lazy var maxDistance: CGFloat = self.modalViewHeight - 60
    private lazy var middleModalPoint: CGFloat = 200
    private var modalBottomConstraint = NSLayoutConstraint()
    private var modalAnimator = UIViewPropertyAnimator()
    private var animationProgress: CGFloat = 0.0
    private var remainigMiddleDistance: CGFloat = 0.0
    private var isMiddlePosition = false
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
        if test {
            return
        }
        test = true
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.5) { [weak self] in
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
        animator.pausesOnCompletion = true
        modalAnimator = animator
    }
    
    @objc private func modalViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if modalAnimator.isRunning {
                if isMiddlePosition {
                    let currentDistance: CGFloat
                    switch currentState {
                    case .closed(_):
                        currentDistance = maxDistance - (remainigMiddleDistance * (1 - modalAnimator.fractionComplete)) - middleModalPoint
                    case .open(_):
                        currentDistance = (middleModalPoint - remainigMiddleDistance) + remainigMiddleDistance * modalAnimator.fractionComplete
                    }
                    animationProgress = currentDistance / maxDistance
                    isMiddlePosition = false
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
            modalAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
        default: ()
        }
    }

}
