//
//  BolusView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit
import LocalAuthentication

struct BolusView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var bolusAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
    private let pushNotificationManager = PushNotificationManager()
    @ObservedObject private var maxBolus = Storage.shared.maxBolus

    @FocusState private var bolusFieldIsFocused: Bool

    @State private var showAlert = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @StateObject private var statusManager = CommandStatusManager()

    enum AlertType {
        case confirmBolus
        case validation
    }

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section {
                        HKQuantityInputView(
                            label: "Bolus Amount",
                            quantity: $bolusAmount,
                            unit: .internationalUnit(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.05),
                            maxValue: maxBolus.value,
                            isFocused: $bolusFieldIsFocused,
                            onValidationError: { message in
                                handleValidationError(message)
                            }
                        )
                    }

                    EnhancedLoadingButtonView(
                        buttonText: "Send Bolus",
                        progressText: "Sending Bolus...",
                        statusManager: statusManager,
                        action: {
                            bolusFieldIsFocused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if bolusAmount.doubleValue(for: HKUnit.internationalUnit()) > 0.0 {
                                    alertType = .confirmBolus
                                    showAlert = true
                                }
                            }
                        },
                        isDisabled: false
                    )
                }
                .navigationTitle("Bolus")
                .navigationBarTitleDisplayMode(.inline)
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmBolus:
                    return Alert(
                        title: Text("Confirm Bolus"),
                        message: Text("Are you sure you want to send \(bolusAmount.doubleValue(for: HKUnit.internationalUnit()), specifier: "%.2f") U?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            authenticateUser { success in
                                if success {
                                    sendBolus()
                                }
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .validation:
                    return Alert(
                        title: Text("Validation Error"),
                        message: Text(alertMessage ?? "Invalid input."),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }

    private func sendBolus() {
        statusManager.updateStatus(.sending)

        pushNotificationManager.sendBolusPushNotification(bolusAmount: bolusAmount) { success, errorMessage, apnsError in
            DispatchQueue.main.async {
                if success {
                    LogManager.shared.log(category: .apns, message: "sendBolusPushNotification succeeded - Bolus: \(bolusAmount.doubleValue(for: .internationalUnit())) U")
                    bolusAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
                    statusManager.updateStatus(.success)
                } else if let apnsError = apnsError {
                    LogManager.shared.log(category: .apns, message: "sendBolusPushNotification failed with error: \(apnsError.technicalMessage)")
                    statusManager.updateStatus(.failed(error: apnsError))
                } else {
                    let fallbackError = APNSErrorInfo(
                        type: .unknownError("Unknown error"),
                        shouldRetry: false,
                        suggestedDelay: nil,
                        userMessage: errorMessage ?? "Failed to send bolus command.",
                        technicalMessage: "Unknown error in bolus command"
                    )
                    statusManager.updateStatus(.failed(error: fallbackError))
                }
            }
        }
    }

    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        let reason = "Confirm your identity to send bolus."

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validation
        showAlert = true
    }
}
