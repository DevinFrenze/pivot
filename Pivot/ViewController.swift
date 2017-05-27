//
//  ViewController.swift
//  Pivot
//
//  Created by Devin Frenze on 5/26/17.
//  Copyright © 2017 Devin Frenze. All rights reserved.
//

import UIKit
import CoreMotion
import GLKit

class ViewController: UIViewController {

    //MARK: Properties
    @IBOutlet weak var rotationsTextView: UITextView!
    @IBOutlet weak var pivotOrientationView: PivotOrientationView!
    @IBAction func reset(_ sender: Any) {
        total = 0
    }
    
    let motionManager = CMMotionManager()       // access data from CoreMotion API
    var timer: Timer!                           // schedules updates at regular interval from motionManager
    var previousDeviceMotion: CMDeviceMotion?   // the device motion object from the last time the update method was called
    var total: Float = 0                        // total rotation around axis of gravity in radians

    //MARK: Overwritten Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        motionManager.startDeviceMotionUpdates()
        timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(ViewController.update), userInfo: nil, repeats: true)
    }
    
    func update() {
        if let deviceMotion = motionManager.deviceMotion {
            // if there is a previous device motion, calculate the change since the last calculation
            if let previous = previousDeviceMotion {
                let referenceVector = GLKVector3Make(0,1,0)
                var deltaTheta = getGravityAxisRotationDelta(deviceMotion, previous, referenceVector)
                if deltaTheta.isNaN { deltaTheta = 0 }
                total += deltaTheta
            }
            previousDeviceMotion = deviceMotion
            updateUI()
        }
    }

    //MARK: Private Methods
    
    private func getGravityAxisRotationDelta(_ current: CMDeviceMotion,_ previous: CMDeviceMotion,_ referenceVector: GLKVector3) -> Float {
        var currentRotationMatrix = castCMRotationMatrixToGLKMatrix3(current.attitude.rotationMatrix)
        var previousRotationMatrix = castCMRotationMatrixToGLKMatrix3(previous.attitude.rotationMatrix)
        
        let angleBetweenGravityAndZ = angleDifference(castCMAccelerationToGLKVector3(current.gravity), GLKVector3Make(0, 0, 1))
        let vertical = abs(angleBetweenGravityAndZ - Float(M_PI_2)) < Float(M_PI_4)
        
        // if the vertical angle between the attitude of gravity and the z-axis is < 45 degrees
        // rotate the attitudes we're comparing 90 degrees along the x-axis
        if vertical {
            let rotation = GLKMatrix3MakeXRotation(Float(M_PI_2))
            currentRotationMatrix = GLKMatrix3Multiply(currentRotationMatrix, rotation)
            previousRotationMatrix = GLKMatrix3Multiply(previousRotationMatrix, rotation)
        }
        
        let projection = projectAttitudeOntoGravityPlane( currentRotationMatrix, current.gravity, referenceVector)
        let previousProjection = projectAttitudeOntoGravityPlane( previousRotationMatrix, previous.gravity, referenceVector)
        return directionalAngleDifference(previousProjection, projection)
    }
    
    private func angleDifference(_ v1: GLKVector3,_ v2: GLKVector3) -> Float {
        let dotProduct = GLKVector3DotProduct(v1, v2)
        let jointMagnitudes = GLKVector3Length(v1) * GLKVector3Length(v2)
        return acos(dotProduct / jointMagnitudes)
    }
    
    private func directionalAngleDifference(_ v1: GLKVector3,_ v2: GLKVector3) -> Float {
        // compare both vectors to a vector -90 degrees around the z-axis from the first so we can tell
        // what direction the angle of difference is
        let angleDirectionReferenceVector = extractVectorFromMatrix(
            GLKMatrix3Multiply(GLKMatrix3MakeZRotation(-Float(M_PI_2)), embedVectorInMatrix(v2))
        )
        return angleDifference(v1, angleDirectionReferenceVector) - angleDifference(v2, angleDirectionReferenceVector)
    }
    
    private func projectAttitudeOntoGravityPlane(_ rotationMatrix: GLKMatrix3,_ gravity: CMAcceleration,_ referenceVector: GLKVector3) -> GLKVector3 {
        // understand the current attitude of the phone in terms of how it projects onto the plan defined by gravity as the normal to the plane (the x-y plane)
        var matrix = GLKMatrix3Multiply(rotationMatrix, getXRotation(gravity))
        matrix = GLKMatrix3Multiply(matrix, getYRotation(gravity))
        matrix = GLKMatrix3Multiply(matrix, embedVectorInMatrix(referenceVector))
        
        // throw away the z-coordinate, since we only care about the angle in the x-y plane
        return GLKVector3Multiply(extractVectorFromMatrix(matrix), GLKVector3Make(1, 1, 0))
    }
    
    private func embedVectorInMatrix(_ vector: GLKVector3) -> GLKMatrix3 {
        let zeroVector = GLKVector3Make(0, 0, 0)
        return GLKMatrix3MakeWithColumns( vector, zeroVector, zeroVector)
    }
    
    private func extractVectorFromMatrix(_ matrix: GLKMatrix3) -> GLKVector3 {
        return GLKMatrix3GetColumn(matrix, Int32(0))
    }
    
    private func castCMRotationMatrixToGLKMatrix3(_ rM: CMRotationMatrix) -> GLKMatrix3 {
        return GLKMatrix3Make(Float(rM.m11), Float(rM.m12), Float(rM.m13), Float(rM.m21), Float(rM.m22), Float(rM.m23), Float(rM.m31), Float(rM.m32), Float(rM.m33))
    }
    
    private func castCMAccelerationToGLKVector3(_ acceleration: CMAcceleration) -> GLKVector3 {
        return GLKVector3Make(Float(acceleration.x), Float(acceleration.y), Float(acceleration.z))
    }
    
    private func getYRotation(_ vector: CMAcceleration) -> GLKMatrix3 {
        let yRotation = GLKMatrix3MakeYRotation(Float(atan2(vector.x, vector.z)))
        return yRotation
    }
    
    private func getXRotation(_ vector: CMAcceleration) -> GLKMatrix3 {
        let xRotation = GLKMatrix3MakeYRotation(Float(atan2(vector.y, sqrt(pow(vector.x,2) + pow(vector.z,2)))))
        return xRotation
    }
    
    // current UI is likely to change, don't worry about this method too much for now
    private func updateUI() {
        UIView.animate(withDuration: 0.1) {
            self.pivotOrientationView.transform = CGAffineTransform(rotationAngle: CGFloat(self.total))
        }
        
        let rotations = floor(abs(total / (2 * Float(M_PI))))
        var direction = "left"
        if rotations == 0 {
            rotationsTextView.text = "Balanced"
        } else {
            if total > 0 {
                direction = "right"
            }
            let rotationsString = String(rotations)
            var rotationLabel = "rotation"
            if rotations > 1 { rotationLabel = "rotations" }
            let index = rotationsString.index(rotationsString.startIndex, offsetBy: 1)
            rotationsTextView.text = "\(rotationsString.substring(to: index)) \(rotationLabel) \(direction)"
        }
    }
}

