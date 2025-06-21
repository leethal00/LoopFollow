//
//  CommandStatus.swift
//  LoopFollow
//
//  Created by Claude on 2025-06-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import SwiftUI

enum CommandStatusType {
    case idle
    case sending
    case retrying(attempt: Int, maxAttempts: Int)
    case success
    case failed(error: APNSErrorInfo)
    case timeout
}

class CommandStatusManager: ObservableObject {
    @Published var currentStatus: CommandStatusType = .idle
    @Published var statusMessage: String = ""
    @Published var showRetryButton: Bool = false
    @Published var isLoading: Bool = false
    
    private var retryTimer: Timer?
    private var timeoutTimer: Timer?
    
    func updateStatus(_ status: CommandStatusType) {
        DispatchQueue.main.async {
            self.currentStatus = status
            self.updateUI(for: status)
        }
    }
    
    private func updateUI(for status: CommandStatusType) {
        switch status {
        case .idle:
            statusMessage = ""
            showRetryButton = false
            isLoading = false
            
        case .sending:
            statusMessage = "Sending command..."
            showRetryButton = false
            isLoading = true
            startTimeoutTimer()
            
        case .retrying(let attempt, let maxAttempts):
            statusMessage = "Retrying... (attempt \(attempt) of \(maxAttempts))"
            showRetryButton = false
            isLoading = true
            
        case .success:
            statusMessage = "Command sent successfully"
            showRetryButton = false
            isLoading = false
            clearTimers()
            
            // Auto-clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .success = self.currentStatus {
                    self.updateStatus(.idle)
                }
            }
            
        case .failed(let errorInfo):
            statusMessage = errorInfo.userMessage
            showRetryButton = !errorInfo.shouldRetry
            isLoading = false
            clearTimers()
            
            // If should retry automatically, show retry info
            if errorInfo.shouldRetry, let delay = errorInfo.suggestedDelay {
                showRetryCountdown(delay: delay)
            }
            
        case .timeout:
            statusMessage = "Command timed out. Please check your connection and try again."
            showRetryButton = true
            isLoading = false
            clearTimers()
        }
    }
    
    private func startTimeoutTimer() {
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.updateStatus(.timeout)
        }
    }
    
    private func showRetryCountdown(delay: TimeInterval) {
        var remainingTime = Int(delay)
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if remainingTime > 0 {
                self?.statusMessage = "Retrying in \(remainingTime) seconds..."
                remainingTime -= 1
            } else {
                timer.invalidate()
                self?.statusMessage = "Retrying now..."
            }
        }
    }
    
    private func clearTimers() {
        retryTimer?.invalidate()
        retryTimer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    func getStatusColor() -> Color {
        switch currentStatus {
        case .idle:
            return .primary
        case .sending, .retrying:
            return .blue
        case .success:
            return .green
        case .failed, .timeout:
            return .red
        }
    }
    
    func getStatusIcon() -> String {
        switch currentStatus {
        case .idle:
            return ""
        case .sending, .retrying:
            return "arrow.up.circle"
        case .success:
            return "checkmark.circle.fill"
        case .failed, .timeout:
            return "exclamationmark.triangle.fill"
        }
    }
    
    deinit {
        clearTimers()
    }
}