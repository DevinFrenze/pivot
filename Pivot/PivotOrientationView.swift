//
//  PivotOrientationView.swift
//  Pivot
//
//  Created by Devin Frenze on 5/26/17.
//  Copyright © 2017 Devin Frenze. All rights reserved.
//

import UIKit
@IBDesignable

class PivotOrientationView: UIView {
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath(ovalIn: rect)
        UIColor.init(red: 1, green: 0.11764705882353, blue: 0.3843137254902, alpha: 1).setFill()
        path.fill()
        
        let directionPath = UIBezierPath()
        let directionPathWidth = CGFloat(4.0)
        directionPath.lineWidth = directionPathWidth
        directionPath.move(to: CGPoint(
            x: bounds.width/2,
            y: bounds.height/2
        ))
        
        directionPath.addLine(to: CGPoint(
            x: bounds.width/2,
            y: 0
        ))
        
        UIColor.white.setStroke()
        directionPath.stroke()
    }
}
