//
//  CommandStatusView.swift
//  LoopFollow
//
//  Created by Claude on 2025-06-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct CommandStatusView: View {
    @ObservedObject var statusManager: CommandStatusManager
    let onRetry: () -> Void
    
    var body: some View {
        if !statusManager.statusMessage.isEmpty || statusManager.isLoading {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Status icon
                    if !statusManager.getStatusIcon().isEmpty {
                        Image(systemName: statusManager.getStatusIcon())
                            .foregroundColor(statusManager.getStatusColor())
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    // Loading spinner for sending states
                    if statusManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    
                    // Status message
                    Text(statusManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(statusManager.getStatusColor())
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                
                // Retry button for manual retry situations
                if statusManager.showRetryButton {
                    Button("Retry Command") {
                        onRetry()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(statusManager.getStatusColor().opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
        }
    }
}

// Helper view for integration into existing command views
struct EnhancedLoadingButtonView: View {
    let buttonText: String
    let progressText: String
    @ObservedObject var statusManager: CommandStatusManager
    let action: () -> Void
    let isDisabled: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                guard !statusManager.isLoading else { return }
                action()
            }) {
                HStack {
                    if statusManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(progressText)
                    } else {
                        Text(buttonText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDisabled || statusManager.isLoading ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isDisabled || statusManager.isLoading)
            
            // Status feedback
            CommandStatusView(statusManager: statusManager, onRetry: action)
        }
    }
}