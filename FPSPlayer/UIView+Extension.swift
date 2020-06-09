//
//  UIView+Extension.swift
//  FPSPlayer
//
//  Created by Amardeep Bikkad on 11/03/20.
//  Copyright © 2020 Amardeep Bikkad. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    func addAsSubViewWithConstraints(_ superview: UIView) {
        self.frame = superview.bounds
        superview.addSubview(self)
        self.addFourConstraints(superview)
    }
    
    func addFourConstraints(_ superview: UIView, top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: superview.topAnchor, constant: top).isActive = true
        self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: bottom).isActive = true
        self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: leading).isActive = true
        self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: trailing).isActive = true
    }
}
