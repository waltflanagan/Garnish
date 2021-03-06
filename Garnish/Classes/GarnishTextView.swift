//
//  GarnishTextView.swift
//
//  Copyright © 2016 Food52, Inc
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
//

import Foundation


extension CATextLayer {
    fileprivate convenience init(frame: CGRect, string: Any?) {
        self.init()
        contentsScale = UIScreen.main.scale
        self.frame = frame
        self.string = string
        
    }
}

extension CGPoint {
    fileprivate func translation() -> CGAffineTransform {
        return CGAffineTransform(translationX: x, y: y)
    }
}


extension CALayer {
    fileprivate static func animateWith(duration: CFTimeInterval, animations: ()->(), completion: (() -> Void)? = nil) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setCompletionBlock(completion)
        
        animations()
        
        CATransaction.commit()
    }
    
    fileprivate static func withoutAnimation(_ action: ()->()) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        action()
        
        CATransaction.commit()
    }
    
    func debug(_ color: UIColor = .red) {
        borderColor = color.cgColor
        borderWidth = 1.0
    }
}



public class GarnishTextView: UITextView {
    
    public var garnishTextStorage: GarnishTextStorage! {
        //swiftlint:disable force_cast
        return textStorage as? GarnishTextStorage
        //swiftlint:enable force_cast
    }
    
    fileprivate var layers = [Int: CATextLayer]()
    
    override public var textColor: UIColor? {
        didSet {
             garnishTextStorage?.textColor = textColor
        }
    }
 
    public init(frame: CGRect) {
        let layoutManager = NSLayoutManager()
        
        let textStorage =  GarnishTextStorage()
        
        textStorage.addLayoutManager(layoutManager)
        textStorage.textColor = .black
        
        let container = NSTextContainer(size: frame.size)
        
        layoutManager.addTextContainer(container)
        
        super.init(frame: frame, textContainer: container)
        
        layoutManager.delegate = self
        textStorage.delegate = self
    }
    
    fileprivate override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}


extension GarnishTextView: NSLayoutManagerDelegate /*instantiation*/ {
    
    func createOverlay(on layer: CATextLayer) -> CALayer {
        let colorLayer = CALayer()
        colorLayer.backgroundColor = textColor?.cgColor ?? UIColor.black.cgColor
        colorLayer.bounds.size = layer.bounds.size
        colorLayer.anchorPoint = layer.anchorPoint
        colorLayer.position = layer.convert(layer.position, from: layer.superlayer)
        layer.addSublayer(colorLayer)
        
        
        let letterMask = CATextLayer()
        letterMask.contentsScale = UIScreen.main.scale
        letterMask.string = layer.string
        letterMask.anchorPoint = colorLayer.anchorPoint
        letterMask.position = colorLayer.position
        letterMask.bounds.size = colorLayer.bounds.size
        
        colorLayer.mask = letterMask
        
        return colorLayer
    }
    
    func bounce(layers: [(Int,CATextLayer)]) {
        guard !layers.isEmpty else { return }
        
        let firstIndex = layers.min(by: { $0.0 < $1.0 })?.0 ?? 0
        
        for (index, layer) in layers {
            
            layer.zPosition = 1.0
            layer.opacity = 1.0
            
            let colorLayer = createOverlay(on: layer)
            
            let growAmount = 1.2
            let growDuration = 0.15
            
            let totalAnimationTime: CFTimeInterval = 0.05 * CFTimeInterval(layers.count)
            let timeBetweenAnimations = totalAnimationTime / CFTimeInterval(layers.count)
            let offsetIndex = index - firstIndex
            let orderOffset = timeBetweenAnimations * Double(offsetIndex)
            
            let springBeginTime = CACurrentMediaTime() + growDuration + orderOffset
            
            let growBeginTime = CACurrentMediaTime() + orderOffset
            
            
            let grow = CABasicAnimation()
            grow.keyPath = "transform.scale"
            grow.toValue = growAmount
            grow.duration = growDuration
            grow.beginTime = growBeginTime
            layer.add(grow, forKey: "grow")
            
            
            let spring = CASpringAnimation()
            spring.keyPath = "transform.scale"
            spring.fromValue = growAmount
            spring.toValue = 1.0
            spring.initialVelocity = 10
            spring.stiffness = 500
            spring.duration = 3.0
            spring.beginTime = springBeginTime
            
            layer.add(spring, forKey: "spring")
            
            let colorSpring = CASpringAnimation()
            colorSpring.keyPath = "backgroundColor"
            colorSpring.fromValue = textColor?.withAlphaComponent(1.0).cgColor ?? UIColor.black.cgColor
            colorSpring.toValue = layer.foregroundColor
            colorSpring.initialVelocity = 10
            colorSpring.stiffness = 500
            colorSpring.duration = 3.0
            colorSpring.beginTime = growBeginTime
            colorLayer.add(colorSpring, forKey: "colorSpring")
                        
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 ) {
                colorLayer.removeFromSuperlayer()
            }
        }
    }
    
    func fadeIn(layers: [(Int,CATextLayer)]) {
        
        for (_, layer) in layers {
            layer.opacity = 1.0
            
            let colorLayer = createOverlay(on: layer)
            
            let colorAnimation = CABasicAnimation()
            colorAnimation.keyPath = "backgroundColor"
            colorAnimation.fromValue = textColor?.withAlphaComponent(1.0).cgColor ?? UIColor.black.cgColor
            colorAnimation.toValue = layer.foregroundColor
            colorAnimation.duration = 0.25
            
            colorLayer.add(colorAnimation, forKey: "colorSpring")
            
            colorLayer.backgroundColor = layer.foregroundColor
            
            DispatchQueue.main.asyncAfter(deadline: .now() + colorAnimation.duration) {
                colorLayer.removeFromSuperlayer()
            }
            
        }
    }
    
    func update(layer: CATextLayer, for location: Int) {
        guard location < textStorage.length else { return }
        
        let singleCharacterRange = NSRange(location: location, length: 1)
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: singleCharacterRange, actualCharacterRange: nil)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: location, effectiveRange: nil)
        
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        let glyphLocation = layoutManager.location(forGlyphAt: characterRange.location)
        
        
        let text = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: characterRange))
        let textRange =  NSRange(location: 0, length: text.length)
        
        if let highlightColor =  garnishTextStorage.highlightColor(at: location) {
             text.addAttribute(NSAttributedStringKey.foregroundColor, value: highlightColor, range: textRange)
        }
        
        if let font =  garnishTextStorage.highlightFont(at: location) {
            text.addAttribute(NSAttributedStringKey.font, value: font, range: textRange)
            text.fixAttributes(in: textRange)
        }
        
        let textBoundingRect =  text.boundingRect(with: glyphRect.size, options: [.usesFontLeading], context: nil)
        
        let locationInContainerCoordinates = glyphLocation.applying(lineRect.origin.translation())
        let locationOfBoundingBox = locationInContainerCoordinates.applying(textBoundingRect.origin.translation().inverted())
        
        let layerLocationInTextContainer  = locationOfBoundingBox.applying(CGAffineTransform(translationX: 0, y: -textBoundingRect.size.height))
        
        let layerLocationInTextView = layerLocationInTextContainer.applying(CGAffineTransform(translationX: textContainerInset.left, y: textContainerInset.top))
        
        let layerRect = CGRect(origin: layerLocationInTextView, size: textBoundingRect.size)
        
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        layer.foregroundColor = garnishTextStorage.highlightColor(at: location)?.cgColor ?? textColor?.cgColor ?? UIColor.black.cgColor
        layer.string = text
        layer.frame = layerRect
        
        CATransaction.commit()
        
    }
    
    public func layout() {
        for (_, layer) in layers {
            layer.removeFromSuperlayer()
        }
        
        layers = [:]
        
        for index in garnishTextStorage.indexesNeedingLayers(in: NSRange(location: 0, length: garnishTextStorage.length)) {
            let layer = newLayer(at: index)
            update(layer: layer, for: index)
        }
    }
    
    private func newLayer(at index: Int) -> CATextLayer {
        let newLayer =  CATextLayer()
        newLayer.contentsScale = UIScreen.main.scale
        newLayer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        self.layer.addSublayer(newLayer)
        layers[index] = newLayer
        
        return newLayer
    }
    
    
    
    private func moveLayersToNewPosition() {
        var newLayers = [Int:CATextLayer]()
        
        for (location, layer) in layers {
            let newLocation = garnishTextStorage.adjust(location)
            
            newLayers[newLocation] = layer
        }
        
        layers = newLayers
    }
    
    
    private func deleteLayersOfDeletedCharacters() {
        let backspacing:Bool  = garnishTextStorage.changeInLength < 0
        
        guard backspacing else { return }
        
        let deletedRange =  garnishTextStorage.editedRange.location..<(garnishTextStorage.editedRange.location + abs(garnishTextStorage.changeInLength))
        
        for index in deletedRange {
            
            guard let layer = layers[index] else {continue}
            
            layer.removeFromSuperlayer()
            layers[index] = nil
        }
        
    }
    
    
    private func animateOutLayersNoLongerNeeded() {
        
        for (_, index) in garnishTextStorage.removedRanges.enumerated() {
            
            guard let layer = layers[index] else {
                continue
            }
            
            CALayer.animateWith(duration: 1.0, animations: {
                layer.opacity = 0.0
            }, completion: {
                layer.removeFromSuperlayer()
                
                if let foundIndex = self.layers.filter({ $0.value == layer}).first {
                    self.layers[foundIndex.key] = nil
                }
                
            })
        }
    }
    
    
    private func addNewLayers() {
        for (_, index) in garnishTextStorage.addedRanges.enumerated() {
            let _ = self.newLayer(at: index)
        }
    }
    
    
    private func updateLayers() {
        
        for (location, layer) in layers {
            update(layer: layer, for: location)
        }
    }
    
    private func animateNewLayers() {
        
        let indexes = NSIndexSet(indexSet: garnishTextStorage.addedRanges)
        
        indexes.enumerateRanges({ (addedRange, _) in
            
            for range in garnishTextStorage.animatableRanges(in: addedRange) {
                let layersToAnimate:[(Int,CATextLayer)] = layers.filter({ (key, _) -> Bool in
                    return NSLocationInRange(key, range)
                }).map { ($0.0, $0.1) }
                
                bounce(layers: layersToAnimate)
            }
            
            for range in garnishTextStorage.staticRanges(in: addedRange) {
                let layersToAnimate:[(Int,CATextLayer)] = layers.filter({ (key, _) -> Bool in
                    return NSLocationInRange(key, range)
                }).map { ($0.0, $0.1) }
                
                fadeIn(layers: layersToAnimate)
            }
            
        })
    }
    
    public func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        
        guard garnishTextStorage.editedMask.contains(.editedCharacters) else { return }
        
  
        deleteLayersOfDeletedCharacters()
        moveLayersToNewPosition()
        animateOutLayersNoLongerNeeded()
        addNewLayers()
        updateLayers()
        animateNewLayers()
        
    }

    
    public override func awakeAfter(using aDecoder: NSCoder) -> Any? {
        
        let layoutManager = NSLayoutManager()
        
        let textStorage =  GarnishTextStorage()
        
        textStorage.textColor = textColor ?? .black
        
        textStorage.addLayoutManager(layoutManager)
        
        let container = NSTextContainer(size: textContainer.size)
        
        layoutManager.addTextContainer(container)
        
        container.lineBreakMode = .byWordWrapping
        container.maximumNumberOfLines = 0
        container.widthTracksTextView = textContainer.widthTracksTextView
        container.heightTracksTextView = textContainer.heightTracksTextView
        
        let replacement = GarnishTextView(frame: frame, textContainer: container)
        
        let newConstraints = constraints.map { replacement.translateConstraint($0, originalItem: self) }
        
        removeConstraints(constraints)
        replacement.addConstraints(newConstraints)
        
        replacement.backgroundColor = self.backgroundColor
        
        replacement.font = self.font
        
        replacement.isSelectable = self.isSelectable
        replacement.isEditable = self.isEditable
        
        replacement.textAlignment = self.textAlignment
        replacement.textColor = self.textColor ?? .black
        replacement.autocapitalizationType = self.autocapitalizationType
        replacement.autocorrectionType = self.autocorrectionType
        replacement.spellCheckingType = self.spellCheckingType
        replacement.translatesAutoresizingMaskIntoConstraints = translatesAutoresizingMaskIntoConstraints
        replacement.returnKeyType = returnKeyType
        replacement.keyboardAppearance = keyboardAppearance
        replacement.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
        
        replacement.isScrollEnabled = isScrollEnabled
        replacement.bounces = bounces
        replacement.bouncesZoom = bouncesZoom
        replacement.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator
        replacement.showsVerticalScrollIndicator = showsVerticalScrollIndicator
        replacement.alwaysBounceHorizontal = alwaysBounceHorizontal
        replacement.alwaysBounceVertical =  alwaysBounceVertical
        replacement.keyboardDismissMode = keyboardDismissMode
        
        layoutManager.delegate = replacement
        textStorage.delegate = replacement
        
        return replacement
    }
    
    func translateConstraint(_ constraint: NSLayoutConstraint, originalItem: AnyObject) -> NSLayoutConstraint {
        
        
        if constraint.firstItem === originalItem {
            return NSLayoutConstraint(item: self,
                                      attribute: constraint.firstAttribute,
                                      relatedBy: constraint.relation,
                                      toItem: constraint.secondItem,
                                      attribute: constraint.secondAttribute,
                                      multiplier: constraint.multiplier,
                                      constant: constraint.constant)
            
        } else if constraint.secondItem === originalItem, let firstItem = constraint.firstItem {
            return NSLayoutConstraint(item: firstItem,
                                      attribute: constraint.firstAttribute,
                                      relatedBy: constraint.relation,
                                      toItem: self,
                                      attribute: constraint.secondAttribute,
                                      multiplier: constraint.multiplier,
                                      constant: constraint.constant)
        } else {
            return constraint
        }
        
    }
    
}

extension GarnishTextView: NSTextStorageDelegate {
    public func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {

        //NSLocationInRange returns false if the location is at the end of the range so we extend the range to include it
        let wholeStringRange = NSRange(location: 0, length: garnishTextStorage.length + 1)
        
        for (index, layer) in layers {
            if !NSLocationInRange(index, wholeStringRange) {
                layer.removeFromSuperlayer()
                layers[index] = nil
            }
        }
    }
}

