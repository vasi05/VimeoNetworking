//
//  ExceptionCatcher+Swift.swift
//  VimeoNetworking
//
//  Created by Huebner, Rob on 4/26/16.
//  Copyright © 2016 Vimeo. All rights reserved.
//

import Foundation

class ExceptionCatcherSwift: ExceptionCatcher
{
    @nonobjc public static func doUnsafe(unsafeBlock: (Void -> Void)) throws
    {
        if let error = self._doUnsafe(unsafeBlock)
        {
            throw error
        }
    }
}