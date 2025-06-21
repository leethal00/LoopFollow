//
//  CancelTempTargetView.swift
//  LoopFollow
//
//  Created by Claude on 2025-06-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct CancelTempTargetView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var tempTarget = Observable.shared.tempTarget
    
    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil
    
    enum AlertType {
        case confirmCancellation
        case statusSuccess
        case statusFailure
        case noActiveTempTarget
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Current Temp Target")) {
                        if let tempTargetValue = tempTarget.value {
                            HStack {
                                Text("Active Target")
                                Spacer()
                                Text(Localizer.formatQuantity(tempTargetValue))
                                Text(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Canceling will end the current temporary target and return to your standard basal rates and targets.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        } else {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("No active temp target")
                                Spacer()
                            }
                            
                            Text("There is currently no active temporary target to cancel.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    
                    LoadingButtonView(
                        buttonText: "Cancel Temp Target",
                        progressText: "Canceling Temp Target...",
                        isLoading: isLoading,
                        action: {
                            if tempTarget.value != nil {
                                alertType = .confirmCancellation
                                showAlert = true
                            } else {
                                alertType = .noActiveTempTarget
                                showAlert = true
                            }
                        },
                        isDisabled: isLoading
                    )
                    .foregroundColor(.red)
                }
                .navigationTitle("Cancel Temp Target")
                .navigationBarTitleDisplayMode(.inline)
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmCancellation:
                    return Alert(
                        title: Text("Confirm Cancellation"),
                        message: Text("Are you sure you want to cancel the active temporary target?"),
                        primaryButton: .destructive(Text("Cancel Target"), action: {
                            cancelTempTarget()
                        }),
                        secondaryButton: .cancel()
                    )
                    
                case .statusSuccess:
                    return Alert(
                        title: Text("Success"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    )
                case .statusFailure:
                    return Alert(
                        title: Text("Error"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"))
                    )
                case .noActiveTempTarget:
                    return Alert(
                        title: Text("No Active Target"),
                        message: Text("There is no active temporary target to cancel."),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }
    
    private func cancelTempTarget() {
        isLoading = true
        
        Task {
            do {
                let result = try await submitTempTargetCancellationToNightscout()
                
                await MainActor.run {
                    isLoading = false
                    statusMessage = "Temporary target cancelled successfully."
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "Temp target cancellation posted successfully to Nightscout"
                    )
                    alertType = .statusSuccess
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorMessage = NightscoutUtils.extractErrorReason(from: error.localizedDescription)
                    statusMessage = "Failed to cancel temporary target: \(errorMessage)"
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "Temp target cancellation failed with error: \(error.localizedDescription)"
                    )
                    alertType = .statusFailure
                    showAlert = true
                }
            }
        }
    }
    
    private func submitTempTargetCancellationToNightscout() async throws -> String {
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // To cancel a temp target in Nightscout, post a temp target with duration: 0
        let body: [String: Any] = [
            "eventType": "Temporary Target",
            "duration": 0,
            "reason": "Canceled via LoopFollow",
            "created_at": dateFormatter.string(from: now),
            "enteredBy": "LoopFollow"
        ]
        
        return try await NightscoutUtils.executePostRequest(eventType: .treatments, body: body)
    }
}