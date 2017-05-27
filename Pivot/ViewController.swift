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
                var deltaTheta = getGravityAxisRotationDelta(deviceMotion, previous)
                if deltaTheta.isNaN { deltaTheta = 0 }
                total += deltaTheta
            }
            previousDeviceMotion = deviceMotion
            updateUI()
        }
    }

    //MARK: Private Methods
    
    private func getGravityAxisRotationDelta(_ current: CMDeviceMotion,_ previous: CMDeviceMotion) -> Float {
        let referenceVector = GLKVector3Make(0,1,0)
    
        var currentRotationMatrix = castCMRotationMatrixToGLKMatrix3(current.attitude.rotationMatrix)
        var previousRotationMatrix = castCMRotationMatrixToGLKMatrix3(previous.attitude.rotationMatrix)
        
        // if the vertical angle between the attitude of gravity and the z-axis is < 45 degrees
        // rotate the attitudes we're comparing 90 degrees along the x-axis
        let angleBetweenGravityAndZ = angleDifference(castCMAccelerationToGLKVector3(current.gravity), GLKVector3Make(0, 0, 1))
        let vertical = abs(angleBetweenGravityAndZ - Float(M_PI_2)) < Float(M_PI_4)
        if vertical {
            let rotation = GLKMatrix3MakeXRotation(Float(M_PI_2))
            currentRotationMatrix = GLKMatrix3Multiply(currentRotationMatrix, rotation)
            previousRotationMatrix = GLKMatrix3Multiply(previousRotationMatrix, rotation)
        }
        
        // get the directional angle difference between the gravity vector of the current and previous frame
        let projection = projectAttitudeOntoGravityPlane( currentRotationMatrix, current.gravity, referenceVector)
        let previousProjection = projectAttitudeOntoGravityPlane( previousRotationMatrix, previous.gravity, referenceVector)
        return directionalAngleDifference(previousProjection, projection)
    }
    
    private func angleDifference(_ v1: GLKVector3,_ v2: GLKVector3) -> Float {
        // the difference between two vectors is the inverse cosine of their dot product divided by the product of their lengths
        let dotProduct = GLKVector3DotProduct(v1, v2)
        let lengthProduct = GLKVector3Length(v1) * GLKVector3Length(v2)
        return acos(dotProduct / lengthProduct)
    }
    
    private func directionalAngleDifference(_ v1: GLKVector3,_ v2: GLKVector3) -> Float {
        // the directional angle difference between two angles is the difference of their differences with a third angle
        let angleDirectionReferenceVector = extractVectorFromMatrix(
            GLKMatrix3Multiply(GLKMatrix3MakeZRotation(-Float(M_PI_2)), embedVectorInMatrix(v2))
        )
        return angleDifference(v1, angleDirectionReferenceVector) - angleDifference(v2, angleDirectionReferenceVector)
    }
    
    private func projectAttitudeOntoGravityPlane(_ rotationMatrix: GLKMatrix3,_ gravity: CMAcceleration,_ referenceVector: GLKVector3) -> GLKVector3 {
        // understand the current attitude of the phone in terms of how it projects onto the plan defined by gravity as the normal to the plane (the x-y plane)
        
        // double check that gravityXRotation shouldn't use GLKMatrix3MakeXRotation
        let gravityXRotation = GLKMatrix3MakeYRotation(Float(atan2(gravity.y, sqrt(pow(gravity.x,2) + pow(gravity.z,2)))))
        let gravityYRotation = GLKMatrix3MakeYRotation(Float(atan2(gravity.x, gravity.z)))

        // rotate the reference vector around the x and y axes to be parallel with gravity
        var matrix = GLKMatrix3Multiply(rotationMatrix, gravityXRotation)
        matrix = GLKMatrix3Multiply(matrix, gravityYRotation)
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

