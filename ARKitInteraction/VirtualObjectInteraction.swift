/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Coordinates movement and gesture interactions with virtual objects.
*/

import UIKit
import ARKit

/// - Tag: VirtualObjectInteraction
class VirtualObjectInteraction: NSObject, UIGestureRecognizerDelegate {
    
    /// Developer setting to translate assuming the detected plane extends infinitely.
    let translateAssumingInfinitePlane = true
    
    /// The scene view to hit test against when moving virtual content.
    let sceneView: VirtualObjectARView
    
    /**
     The object that has been most recently intereacted with.
     The `selectedObject` can be moved at any time with the tap gesture.
     */
    var selectedObject: VirtualObject?
    
    /// The object that is tracked for use by the pan and rotation gestures.
    private var trackedObject: VirtualObject? {
        didSet {
            guard trackedObject != nil else { return }
            selectedObject = trackedObject
        }
    }
    
    /// The tracked screen position used to update the `trackedObject`'s position in `updateObjectToCurrentTrackingPosition()`.
    private var currentTrackingPosition: CGPoint?

    init(sceneView: VirtualObjectARView) {
        self.sceneView = sceneView
        super.init()
        
        let panGesture = ThresholdPanGesture(target: self, action: #selector(didPan(_:)))
        panGesture.delegate = self
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
        rotationGesture.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        
        // Add gestures to the `sceneView`.
        sceneView.addGestureRecognizer(panGesture)
        sceneView.addGestureRecognizer(rotationGesture)
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Gesture Actions
    
    @objc
    func didPan(_ gesture: ThresholdPanGesture) {
        switch gesture.state {
        case .began:
            // Check for interaction with a new object.
            if let object = objectInteracting(with: gesture, in: sceneView) {
                trackedObject = object
            }
            
        case .changed where gesture.isThresholdExceeded:
            guard let object = trackedObject else { return }
            let translation = gesture.translation(in: sceneView)
            
            let currentPosition = currentTrackingPosition ?? CGPoint(sceneView.projectPoint(object.position))
            
            // The `currentTrackingPosition` is used to update the `selectedObject` in `updateObjectToCurrentTrackingPosition()`.
            currentTrackingPosition = CGPoint(x: currentPosition.x + translation.x, y: currentPosition.y + translation.y)

            gesture.setTranslation(.zero, in: sceneView)
            
        case .changed:
            // Ignore changes to the pan gesture until the threshold for displacment has been exceeded.
            break
            
        default:
            // Clear the current position tracking.
            currentTrackingPosition = nil
            trackedObject = nil
        }
    }

    /**
     If a drag gesture is in progress, update the tracked object's position by
     converting the 2D touch location on screen (`currentTrackingPosition`) to
     3D world space.
     This method is called per frame (via `SCNSceneRendererDelegate` callbacks),
     allowing drag gestures to move virtual objects regardless of whether one
     drags a finger across the screen or moves the device through space.
     - Tag: updateObjectToCurrentTrackingPosition
     */
    //通过在拖拽手势正在进行时持续调用updateObjectToCurrentTrackingPosition()方法来支持这种手势，即时手势的触摸位置没有改变。如果设备在拖拽期间移动，则该方法会计算与触摸位置相对应的新世界位置，并相应地移动虚拟对象。
    @objc
    func updateObjectToCurrentTrackingPosition() {
        guard let object = trackedObject, let position = currentTrackingPosition else { return }
        translate(object, basedOn: position, infinitePlane: translateAssumingInfinitePlane)
    }

    /// - Tag: didRotate
    @objc
    func didRotate(_ gesture: UIRotationGestureRecognizer) {
        guard gesture.state == .changed else { return }
        
        /*
         - Note:
          For looking down on the object (99% of all use cases), we need to subtract the angle.
          To make rotation also work correctly when looking from below the object one would have to
          flip the sign of the angle depending on whether the object is above or below the camera...
         */
        trackedObject?.eulerAngles.y -= Float(gesture.rotation)
        
        gesture.rotation = 0
    }
    
    @objc
    func didTap(_ gesture: UITapGestureRecognizer) {
        let touchLocation = gesture.location(in: sceneView)
        
        if let tappedObject = sceneView.virtualObject(at: touchLocation) {
            // Select a new object.
            selectedObject = tappedObject
        } else if let object = selectedObject {
            // Teleport the object to whereever the user touched the screen.
            translate(object, basedOn: touchLocation, infinitePlane: false)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow objects to be translated and rotated at the same time.
        return true
    }

    /*
     用户与虚拟对象的交互
     允许人们使用标准熟悉的手势直接与虚拟对象进行交互。示例应用程序使用单指点击、单指和双指拖拽以及双指旋转手势识别器来让用户定位和定向虚拟对象。示例代码的VirtualObjectInteraction类管理这些手势。
     一般来说，保持交互的简单性。当拖拽虚拟对象时，示例应用程序将对象的移动限制为放置在其上的二维平面，类似地，由于虚拟对象依赖于水平平面，旋转手势仅绕其垂直轴旋转对象，以使对象保留在平面上。
     在交互式虚拟物体的合理接近范围内回应手势。示例代码的objectInteracting(with:in:)方法实用手势识别器提供的接触位置来执行碰撞测试。该方式通过虚拟对象的边界框进行碰撞测试，使得用户接触更可能影响物体，即使接触位置不在对象具有可见内容的点上。该方法通过多点触控手势执行多次碰撞测试，使得用户接触更可能应用预估对象：
     考虑用户启动的对象缩放是否必要。这个放置逼真的虚拟物体的AR体验可能会自然地出现在用户环境中，因此对象的内在大小有助于实现现实。因此，示例应用程序不会添加手势或其他UI来启用对象缩放。另外，通过不启用缩放手势，可防止用户对于手势是调整对象大小还是改变对象距相机的距离而困惑。(如果选择在应用程序中启用对象缩放，请使用捏合手势识别器。)
     警惕潜在的手势冲突。示例代码的ThresholdPanGesture类是一个UIPanGestureRecognizer子类，它提供一种延迟手势识别器效果的方法，直到正在进行的手势通过指定的移动阀值。示例代码的touchesMoved(with:)方法使用此类让用户在拖拽对象之间平滑过渡并在单个双指手势中旋转对象：
     确保虚拟对象的顺利移动。示例代码的setPosition(_:relativeTo:smoothMovement)方法在导致拖拽对象触摸手势位置和该对象的最近位置的历史记录之间插值。该方法通过根据距离摄像机的距离平均最近的位置，可以产生平滑的拖拽运动，而不会使拖拽的对象滞后于用户的手势：
     探索更有吸引力的交互方式。在AR体验中，拖拽手势--即将手指移动到设备屏幕上--并不是将虚拟内容拖到新位置的唯一自然方式。用户还可以直观地尝试在移动设备的同时将手指保持在屏幕上，在AR场景中有效地拖拽触摸点。
     */
    ///辅助方法返回在提供的“手势”触摸位置下找到的第一个对象。
    /// - Tag: TouchTesting
    private func objectInteracting(with gesture: UIGestureRecognizer, in view: ARSCNView) -> VirtualObject? {
        for index in 0..<gesture.numberOfTouches {
            let touchLocation = gesture.location(ofTouch: index, in: view)
            
            // //直接在`touchLocation`下查找一个对象。
            if let object = sceneView.virtualObject(at: touchLocation) {
                return object
            }
        }
        
        //作为寻找一个对象下的触摸中心的最后的手段。 As a last resort look for an object under the center of the touches.
        return sceneView.virtualObject(at: gesture.center(in: view))
    }
    
    // MARK: - Update object position

    /// - Tag: DragVirtualObject
    private func translate(_ object: VirtualObject, basedOn screenPos: CGPoint, infinitePlane: Bool) {
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform,
            let (position, _, isOnPlane) = sceneView.worldPosition(fromScreenPosition: screenPos,
                                                                   objectPosition: object.simdPosition,
                                                                   infinitePlane: infinitePlane) else { return }
        
        /*
         Plane hit test results are generally smooth. If we did *not* hit a plane,
         smooth the movement to prevent large jumps.
         */
        object.setPosition(position, relativeTo: cameraTransform, smoothMovement: !isOnPlane)
    }
}

/// Extends `UIGestureRecognizer` to provide the center point resulting from multiple touches.
extension UIGestureRecognizer {
    func center(in view: UIView) -> CGPoint {
        let first = CGRect(origin: location(ofTouch: 0, in: view), size: .zero)

        let touchBounds = (1..<numberOfTouches).reduce(first) { touchBounds, index in
            return touchBounds.union(CGRect(origin: location(ofTouch: index, in: view), size: .zero))
        }

        return CGPoint(x: touchBounds.midX, y: touchBounds.midY)
    }
}
