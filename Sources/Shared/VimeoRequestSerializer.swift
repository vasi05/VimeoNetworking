//
//  VimeoRequestSerializer.swift
//  VimeoUpload
//
//  Created by Hanssen, Alfie on 10/16/15.
//  Copyright © 2015 Vimeo. All rights reserved.
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

import Foundation

/// `VimeoRequestSerializer` handles request serialization as well as adding Vimeo-specific authorization
/// headers to outbound requests.
/// It can be initialized with either a dynamic `AccessTokenProvider` or a static `AppConfiguration`.
final public class VimeoRequestSerializer {
    
    public typealias AccessTokenProvider = () -> String?
    
    // MARK:
    
    // for authenticated requests (Applicable to logged in/out VIMAccount)
    var accessTokenProvider: AccessTokenProvider?
    
    // for unauthenticated requests
    private let appConfiguration: AppConfiguration?

    // Internal JSON serializer
    private let jsonSerializer: AFJSONRequestSerializer = AFJSONRequestSerializer()

    // MARK: - Initialization
    
    /**
     Create a request serializer with an access token provider
     
     - parameter accessTokenProvider: when called, returns an authenticated access token
     - parameter apiVersion:          version of the API this application's requests should use
     
     - returns: an initialized `VimeoRequestSerializer`
     */
    init(
        accessTokenProvider: @escaping AccessTokenProvider,
        apiVersion: String
    ) {
        self.accessTokenProvider = accessTokenProvider
        self.appConfiguration = nil
        self.configureDefaultHeaders(withAPIVersion: apiVersion)
    }
    
    /**
     Create a request serializer with an application configuration
     
     - parameter appConfiguration: your application's configuration
     
     - returns: an initialized `VimeoRequestSerializer`
     */
    init(appConfiguration: AppConfiguration) {
        self.accessTokenProvider = nil
        self.appConfiguration = appConfiguration
        
        self.configureDefaultHeaders(withAPIVersion: appConfiguration.apiVersion)
    }
    
    // MARK: - Public
    
    public func request(
        withMethod method: HTTPMethod,
        urlString URLString: String,
        parameters: Any?,
        error: NSErrorPointer
    ) -> NSMutableURLRequest {
        var request = jsonSerializer.request(
            withMethod: method.rawValue,
            urlString: URLString,
            parameters: parameters,
            error: error
        ) as URLRequest
        request = self.requestConfiguringHeaders(fromRequest: request)
        
        return (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
    }
    
    public func request(
        bySerializingRequest request: URLRequest,
        withParameters parameters: Any?,
        error: NSErrorPointer
    ) -> URLRequest? {
        guard let request = jsonSerializer.request(
            bySerializingRequest: request,
            withParameters: parameters,
            error: error
        ) else {
            return nil
        }
        return self.requestConfiguringHeaders(fromRequest: request)
    }
    
    // MARK: Header Helpers
    
    private func configureDefaultHeaders(withAPIVersion apiVersion: String) {
        self.jsonSerializer.setValue(
            "application/vnd.vimeo.*+json; version=\(apiVersion)",
            forHTTPHeaderField: .acceptHeaderKey
        )
    }

    private func requestConfiguringHeaders(fromRequest request: URLRequest) -> URLRequest {
        var request = request
        
        request = self.requestAddingAuthorizationHeader(fromRequest: request)
        request = self.requestModifyingUserAgentHeader(fromRequest: request)
        
        return request
    }
    
    private func requestAddingAuthorizationHeader(fromRequest request: URLRequest) -> URLRequest {
        var request = request
        
        if let token = self.accessTokenProvider?() {
            let value = "Bearer \(token)"
            request.setValue(value, forHTTPHeaderField: .authorizationHeaderKey)
        }
        else if let appConfiguration = self.appConfiguration {
            let clientID = appConfiguration.clientIdentifier
            let clientSecret = appConfiguration.clientSecret
            
            let authString = "\(clientID):\(clientSecret)"
            let authData = authString.data(using: String.Encoding.utf8)
            let base64String = authData?.base64EncodedString(options: [])
            
            if let base64String = base64String {
                let headerValue = "Basic \(base64String)"
                request.setValue(headerValue, forHTTPHeaderField: .authorizationHeaderKey)
            }
        }
        
        return request
    }
    
    private func requestModifyingUserAgentHeader(fromRequest request: URLRequest) -> URLRequest {
        guard let frameworkVersion = Bundle(for: type(of: self)).shortVersionString else {
            assertionFailure("Unable to get the framework version")
            return request
        }
        
        var request = request
        
        let frameworkString = "VimeoNetworking/\(frameworkVersion)"
        
        guard let existingUserAgent = request.value(forHTTPHeaderField: .userAgentKey) else {
            // DISCUSSION: AFNetworking doesn't set a User Agent for tvOS (look at the init method in AFHTTPRequestSerializer.m).
            // So, on tvOS the User Agent will only specify the framework. System information might be something we want to add
            // in the future if AFNetworking isn't providing it. [ghking] 6/19/17
            
            #if !os(tvOS)
                assertionFailure("An existing user agent was not found")
            #endif
            
            request.setValue(frameworkString, forHTTPHeaderField: .userAgentKey)

            return request
        }
        
        let modifiedUserAgent = "\(existingUserAgent) \(frameworkString)"
        
        request.setValue(modifiedUserAgent, forHTTPHeaderField: .userAgentKey)
        
        return request
    }
}


private extension Bundle {
    var shortVersionString: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - Private header keys
private extension String {
    static let acceptHeaderKey = "Accept"
    static let authorizationHeaderKey = "Authorization"
    static let userAgentKey = "User-Agent"
}
