import AppKit

/// A lightweight, battery-efficient 3-bar audio waveform indicator.
/// Zero background CPU: Animations run on the GPU via CoreAnimation and are completely
/// removed when media is paused or stopped.
public final class MediaWaveformView: NSView {
    
    private let barCount = 3
    private var barLayers: [CALayer] = []
    public private(set) var isPlaying = false
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBars()
    }
    
    private func setupBars() {
        wantsLayer = true
        layer?.masksToBounds = false
        
        let barWidth: CGFloat = 2.0
        let spacing: CGFloat = 2.0
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let initialHeights: [CGFloat] = [6.0, 10.0, 7.0]
        
        for i in 0..<barCount {
            let bar = CALayer()
            let x = (bounds.width - totalWidth) / 2.0 + CGFloat(i) * (barWidth + spacing)
            let h = initialHeights[i]
            bar.frame = CGRect(x: x, y: (bounds.height - h) / 2.0, width: barWidth, height: h)
            bar.cornerRadius = 1.0
            bar.backgroundColor = NSColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 0.95).cgColor
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
    }
    
    public override func layout() {
        super.layout()
        let barWidth: CGFloat = 2.0
        let spacing: CGFloat = 2.0
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let initialHeights: [CGFloat] = [6.0, 10.0, 7.0]
        
        for (i, bar) in barLayers.enumerated() {
            let x = (bounds.width - totalWidth) / 2.0 + CGFloat(i) * (barWidth + spacing)
            let h = initialHeights[i]
            bar.frame = CGRect(x: x, y: (bounds.height - h) / 2.0, width: barWidth, height: h)
        }
    }
    
    public func setPlaying(_ playing: Bool) {
        guard playing != isPlaying else { return }
        self.isPlaying = playing
        
        if playing {
            startAnimation()
        } else {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        let durations: [CFTimeInterval] = [0.45, 0.65, 0.50]
        let scales: [CGFloat] = [1.8, 0.4, 1.5]
        
        for (i, bar) in barLayers.enumerated() {
            bar.removeAnimation(forKey: "waveformPulse")
            
            let anim = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue = 0.5
            anim.toValue = scales[i]
            anim.duration = durations[i]
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(anim, forKey: "waveformPulse")
        }
    }
    
    private func stopAnimation() {
        for bar in barLayers {
            bar.removeAnimation(forKey: "waveformPulse")
            bar.transform = CATransform3DIdentity
        }
    }
}
