//
//  CarbEntryView.swift
//  LoopFollow
//
//  Created by Claude on 2025-06-21.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct CarbEntryView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var carbs = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var absorptionTime: Int = 180 // Default 3 hours in minutes
    @State private var notes: String = ""
    
    @ObservedObject private var maxCarbs = Storage.shared.maxCarbs
    
    @FocusState private var carbsFieldIsFocused: Bool
    @FocusState private var notesFieldIsFocused: Bool
    
    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil
    
    let absorptionTimeOptions = [60, 120, 180, 240, 300, 360] // 1-6 hours in minutes
    
    enum AlertType {
        case confirmCarbEntry
        case statusSuccess
        case statusFailure
        case validationError
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Carb Entry")) {
                        HKQuantityInputView(
                            label: "Carbs",
                            quantity: $carbs,
                            unit: .gram(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .gram(), doubleValue: 1),
                            maxValue: maxCarbs.value,
                            isFocused: $carbsFieldIsFocused,
                            onValidationError: { message in
                                handleValidationError(message)
                            }
                        )
                        
                        Picker("Absorption Time", selection: $absorptionTime) {
                            ForEach(absorptionTimeOptions, id: \.self) { time in
                                Text("\(time / 60) hours").tag(time)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        TextField("Notes (optional)", text: $notes)
                            .focused($notesFieldIsFocused)
                    }
                    
                    LoadingButtonView(
                        buttonText: "Add Carb Entry",
                        progressText: "Adding Carb Entry...",
                        isLoading: isLoading,
                        action: {
                            carbsFieldIsFocused = false
                            notesFieldIsFocused = false
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                guard carbs.doubleValue(for: .gram()) > 0 else {
                                    handleValidationError("Please enter a carb amount greater than 0")
                                    return
                                }
                                if !showAlert {
                                    alertType = .confirmCarbEntry
                                    showAlert = true
                                }
                            }
                        },
                        isDisabled: isButtonDisabled
                    )
                }
                .navigationTitle("Carb Entry")
                .navigationBarTitleDisplayMode(.inline)
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmCarbEntry:
                    let carbsAmount = carbs.doubleValue(for: HKUnit.gram())
                    let absorptionHours = absorptionTime / 60
                    
                    var message = "Are you sure you want to add this carb entry?\n\nCarbs: \(String(format: "%.0f", carbsAmount)) g\nAbsorption: \(absorptionHours) hours"
                    
                    if !notes.isEmpty {
                        message += "\nNotes: \(notes)"
                    }
                    
                    return Alert(
                        title: Text("Confirm Carb Entry"),
                        message: Text(message),
                        primaryButton: .default(Text("Confirm"), action: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                sendCarbEntry()
                            }
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
                case .validationError:
                    return Alert(
                        title: Text("Validation Error"),
                        message: Text(alertMessage ?? ""),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }
    
    private var isButtonDisabled: Bool {
        return isLoading || carbs.doubleValue(for: .gram()) <= 0
    }
    
    private func sendCarbEntry() {
        isLoading = true
        
        Task {
            do {
                let result = try await submitCarbEntryToNightscout()
                
                await MainActor.run {
                    isLoading = false
                    statusMessage = "Carb entry added successfully to Nightscout."
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "Carb entry posted successfully - Carbs: \(carbs.doubleValue(for: .gram())) g, Absorption: \(absorptionTime) min"
                    )
                    
                    // Reset values after success
                    carbs = HKQuantity(unit: .gram(), doubleValue: 0.0)
                    absorptionTime = 180
                    notes = ""
                    alertType = .statusSuccess
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorMessage = NightscoutUtils.extractErrorReason(from: error.localizedDescription)
                    statusMessage = "Failed to add carb entry: \(errorMessage)"
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "Carb entry failed with error: \(error.localizedDescription)"
                    )
                    alertType = .statusFailure
                    showAlert = true
                }
            }
        }
    }
    
    private func submitCarbEntryToNightscout() async throws -> String {
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let body: [String: Any] = [
            "eventType": "Carb Correction",
            "carbs": carbs.doubleValue(for: .gram()),
            "absorptionTime": absorptionTime,
            "created_at": dateFormatter.string(from: now),
            "enteredBy": "LoopFollow",
            "notes": notes.isEmpty ? "Added via LoopFollow" : notes
        ]
        
        return try await NightscoutUtils.executePostRequest(eventType: .treatments, body: body)
    }
    
    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validationError
        showAlert = true
    }
}