//
//  APNSErrorHandler.swift
//  LoopFollow
//
//  Created by Claude on 2025-06-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

enum APNSErrorType {
    case success
    case clientError(String)
    case serverError(String)
    case rateLimited(String)
    case authenticationError(String)
    case deviceTokenError(String)
    case temporaryError(String)
    case unknownError(String)
}

struct APNSErrorInfo {
    let type: APNSErrorType
    let shouldRetry: Bool
    let suggestedDelay: TimeInterval?
    let userMessage: String
    let technicalMessage: String
}

class APNSErrorHandler {
    
    static func parseAPNSResponse(statusCode: Int, responseBody: String?, apnsId: String?) -> APNSErrorInfo {
        let reason = extractReason(from: responseBody)
        
        switch statusCode {
        case 200:
            return APNSErrorInfo(
                type: .success,
                shouldRetry: false,
                suggestedDelay: nil,
                userMessage: "Command sent successfully",
                technicalMessage: "Push notification delivered to APNS (Status: 200)"
            )
            
        case 400:
            return APNSErrorInfo(
                type: .clientError(reason ?? "Bad request"),
                shouldRetry: false,
                suggestedDelay: nil,
                userMessage: "Invalid command format. Please check your settings.",
                technicalMessage: "Bad request - malformed payload or headers (Status: 400) - \(reason ?? "Unknown")"
            )
            
        case 403:
            return APNSErrorInfo(
                type: .authenticationError(reason ?? "Authentication failed"),
                shouldRetry: false,
                suggestedDelay: nil,
                userMessage: "Authentication failed. Please check your APNS credentials in Remote Settings.",
                technicalMessage: "Authentication error - invalid certificate or token (Status: 403) - \(reason ?? "Unknown")"
            )
            
        case 404:
            return APNSErrorInfo(
                type: .clientError(reason ?? "Invalid path"),
                shouldRetry: false,
                suggestedDelay: nil,
                userMessage: "Configuration error. Please check your Bundle ID in settings.",
                technicalMessage: "Invalid request path (Status: 404) - \(reason ?? "Unknown")"
            )
            
        case 405:
            return APNSErrorInfo(
                type: .clientError(reason ?? "Method not allowed"),
                shouldRetry: false,
                suggestedDelay: nil,
                userMessage: "Internal error. Please contact support.",
                technicalMessage: "Method not allowed - only POST supported (Status: 405)"
            )
            
        case 410:
            return APNSErrorInfo(
                type: .deviceTokenError(reason ?? "Device token inactive"),
                shouldRetry: false,
                suggestedDelay: nil,
                userMessage: "Your device token is no longer valid. Please update Trio app and try again.",
                technicalMessage: "Device token inactive for topic (Status: 410) - \(reason ?? "Unknown")"
            )
            
        case 413:
            return APNSErrorInfo(
                type: .clientError(reason ?? "Payload too large"),
                shouldRetry: false,
                suggestedDelay: nil,
                userMessage: "Command data too large. Please reduce meal complexity and try again.",
                technicalMessage: "Payload exceeded size limit (Status: 413) - \(reason ?? "Unknown")"
            )
            
        case 429:
            return APNSErrorInfo(
                type: .rateLimited(reason ?? "Too many requests"),
                shouldRetry: true,
                suggestedDelay: 60.0, // Wait 1 minute before retry
                userMessage: "Too many commands sent. Please wait a moment and try again.",
                technicalMessage: "Rate limited by APNS (Status: 429) - \(reason ?? "Unknown")"
            )
            
        case 500:
            return APNSErrorInfo(
                type: .serverError(reason ?? "Internal server error"),
                shouldRetry: true,
                suggestedDelay: 5.0,
                userMessage: "Apple server error. Retrying automatically...",
                technicalMessage: "APNS internal server error (Status: 500) - \(reason ?? "Unknown")"
            )
            
        case 502:
            return APNSErrorInfo(
                type: .serverError(reason ?? "Bad gateway"),
                shouldRetry: true,
                suggestedDelay: 10.0,
                userMessage: "Connection issue with Apple servers. Retrying...",
                technicalMessage: "Bad gateway (Status: 502) - \(reason ?? "Unknown")"
            )
            
        case 503:
            return APNSErrorInfo(
                type: .temporaryError(reason ?? "Service unavailable"),
                shouldRetry: true,
                suggestedDelay: 30.0,
                userMessage: "Apple Push Service temporarily unavailable. Retrying...",
                technicalMessage: "Service unavailable (Status: 503) - \(reason ?? "Unknown")"
            )
            
        case 504:
            return APNSErrorInfo(
                type: .temporaryError(reason ?? "Gateway timeout"),
                shouldRetry: true,
                suggestedDelay: 15.0,
                userMessage: "Connection timeout. Retrying...",
                technicalMessage: "Gateway timeout (Status: 504) - \(reason ?? "Unknown")"
            )
            
        default:
            return APNSErrorInfo(
                type: .unknownError(reason ?? "Unknown error"),
                shouldRetry: statusCode >= 500, // Retry server errors
                suggestedDelay: statusCode >= 500 ? 10.0 : nil,
                userMessage: "Unexpected error occurred. Please try again.",
                technicalMessage: "Unexpected status code \(statusCode) - \(reason ?? "Unknown")"
            )
        }
    }
    
    private static func extractReason(from responseBody: String?) -> String? {
        guard let data = responseBody?.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let reason = json["reason"] as? String else {
            return nil
        }
        return reason
    }
    
    static func getDetailedErrorMessage(from apnsError: APNSErrorInfo) -> String {
        return apnsError.userMessage
    }
    
    static func getRetryRecommendation(from apnsError: APNSErrorInfo) -> String? {
        if apnsError.shouldRetry {
            if let delay = apnsError.suggestedDelay {
                return "Will automatically retry in \(Int(delay)) seconds"
            } else {
                return "Will automatically retry"
            }
        }
        return nil
    }
}