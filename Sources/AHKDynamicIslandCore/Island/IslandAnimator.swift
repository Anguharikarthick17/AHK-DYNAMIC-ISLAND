import AppKit
import Foundation
import QuartzCore

/// Coordinates smooth, interruptible, spring-like animations for island transitions.
@MainActor
public final class IslandAnimator {
    
    public struct AnimationParameters: @unchecked Sendable {
        public let duration: TimeInterval
        public let timingFunction: CAMediaTimingFunction
        
        public static var defaultSpring: AnimationParameters {
            AnimationParameters(
                duration: 0.32,
                timingFunction: CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            )
        }
        
        public static var quickCollapse: AnimationParameters {
            AnimationParameters(
                duration: 0.26,
                timingFunction: CAMediaTimingFunction(controlPoints: 0.25, 1.0, 0.5, 1.0)
            )
        }
    }
    
    private var currentAnimationId: UUID?
    public private(set) var isAnimating: Bool = false
    
    public init() {}
    
    /// Animates from current state to target frame and view configurations.
    ///
    /// - Parameters:
    ///   - window: The target island NSWindow/NSPanel.
    ///   - targetFrame: Target window frame in screen coordinates.
    ///   - parameters: Duration and timing curve.
    ///   - viewAnimations: Additional view-level animations (e.g. alphas, corner radii).
    ///   - completion: Called when the animation completes or is interrupted.
    public func animate(
        window: NSWindow,
        targetFrame: NSRect,
        parameters: AnimationParameters = .defaultSpring,
        viewAnimations: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        let animationId = UUID()
        currentAnimationId = animationId
        isAnimating = true
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = parameters.duration
            context.timingFunction = parameters.timingFunction
            context.allowsImplicitAnimation = true
            
            // Animate window frame
            window.animator().setFrame(targetFrame, display: true)
            
            // Execute view-level property changes
            viewAnimations()
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                
                // Verify this is still the active animation (not superseded by an interrupt)
                let isCurrent = (self.currentAnimationId == animationId)
                if isCurrent {
                    self.isAnimating = false
                    self.currentAnimationId = nil
                }
                completion(isCurrent)
            }
        })
    }
    
    /// Immediately sets the target frame and executes view changes without animation.
    public func setImmediately(
        window: NSWindow,
        targetFrame: NSRect,
        viewUpdates: () -> Void
    ) {
        currentAnimationId = nil
        isAnimating = false
        window.setFrame(targetFrame, display: true)
        viewUpdates()
    }
    
    /// Cancels or marks current animation as superseded.
    public func cancel() {
        currentAnimationId = nil
        isAnimating = false
    }
}
