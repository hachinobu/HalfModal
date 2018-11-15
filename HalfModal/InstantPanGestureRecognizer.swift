import UIKit

class InstantPanGestureRecognizer: UIPanGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        switch state {
        case .began: return
        default:
            super.touchesBegan(touches, with: event)
            state = .began
        }
    }
}
