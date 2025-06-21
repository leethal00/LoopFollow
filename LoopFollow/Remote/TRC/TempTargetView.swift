//
//  TempTargetView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct TempTargetView: View {
    @Environment(\.presentationMode) private var presentationMode
    private let pushNotificationManager = PushNotificationManager()

    @ObservedObject var device = ObservableUserDefaults.shared.device
    @ObservedObject var tempTarget = Observable.shared.tempTarget

    @State private var newHKTarget = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 0.0)
    @State private var duration = HKQuantity(unit: .minute(), doubleValue: 0.0)
    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @StateObject private var statusManager = CommandStatusManager()

    @State private var showPresetSheet: Bool = false
    @State private var presetName = ""
    @ObservedObject var presetManager = TempTargetPresetManager.shared

    @FocusState private var targetFieldIsFocused: Bool
    @FocusState private var durationFieldIsFocused: Bool

    enum AlertType {
        case confirmCommand
        case validation
        case confirmCancellation
    }

    var body: some View {
        NavigationView {
            VStack {
                if device.value != "Trio" {
                    ErrorMessageView(
                        message: "Remote commands are currently only available for Trio."
                    )
                } else {
                    Form {
                        if let tempTargetValue = tempTarget.value {
                            Section(header: Text("Existing Temp Target")) {
                                HStack {
                                    Text("Current Target")
                                    Spacer()
                                    Text(Localizer.formatQuantity(tempTargetValue))
                                    Text(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString).foregroundColor(.secondary)
                                }
                                Button {
                                    if !statusManager.isLoading {
                                        alertType = .confirmCancellation
                                        showAlert = true
                                    }
                                } label: {
                                    HStack {
                                        Text("Cancel Temp Target")
                                        Spacer()
                                        Image(systemName: "xmark.app")
                                            .font(.title)
                                    }
                                }
                                .tint(.red)
                            }
                        }
                        Section(header: Text("Temporary Target")) {
                            HStack {
                                Text("Target")
                                Spacer()
                                TextFieldWithToolBar(
                                    quantity: $newHKTarget,
                                    maxLength: 4,
                                    unit: UserDefaultsRepository.getPreferredUnit(),
                                    minValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80),
                                    maxValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200),
                                    onValidationError: { message in
                                        handleValidationError(message)
                                    }
                                )
                                .focused($targetFieldIsFocused)
                                Text(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString).foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Duration")
                                Spacer()
                                TextFieldWithToolBar(
                                    quantity: $duration,
                                    maxLength: 4,
                                    unit: HKUnit.minute(),
                                    minValue: HKQuantity(unit: .minute(), doubleValue: 5),
                                    onValidationError: { message in
                                        handleValidationError(message)
                                    }
                                )
                                .focused($durationFieldIsFocused)
                                Text("minutes").foregroundColor(.secondary)
                            }
                            HStack {
                                Button {
                                    if !statusManager.isLoading {
                                        alertType = .confirmCommand
                                        showAlert = true
                                        targetFieldIsFocused = false
                                        durationFieldIsFocused = false
                                    }
                                } label: {
                                    Text("Enact")
                                }
                                .disabled(isButtonDisabled)
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.callout)
                                .controlSize(.mini)

                                Spacer()

                                Button {
                                    if !statusManager.isLoading {
                                        showPresetSheet = true
                                        targetFieldIsFocused = false
                                        durationFieldIsFocused = false
                                    }
                                } label: {
                                    Text("Save as Preset")
                                }
                                .disabled(isButtonDisabled)
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.callout)
                                .controlSize(.mini)
                            }
                        }

                        if !presetManager.presets.isEmpty {
                            Section(header: Text("Presets")) {
                                ForEach(presetManager.presets) { preset in
                                    HStack {
                                        Text(preset.name)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if !statusManager.isLoading {
                                            alertType = .confirmCommand
                                            newHKTarget = preset.target
                                            duration = preset.duration
                                            showAlert = true
                                            targetFieldIsFocused = false
                                            durationFieldIsFocused = false
                                        }
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            if let index = presetManager.presets.firstIndex(where: { $0.id == preset.id }) {
                                                presetManager.deletePreset(at: index)
                                            }
                                            targetFieldIsFocused = false
                                            durationFieldIsFocused = false
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Enhanced status feedback
                    CommandStatusView(statusManager: statusManager, onRetry: {
                        // Determine which action to retry based on current context
                        if newHKTarget.doubleValue(for: UserDefaultsRepository.getPreferredUnit()) > 0 &&
                           duration.doubleValue(for: HKUnit.minute()) > 0 {
                            enactTempTarget()
                        }
                    })
                }
            }
            .navigationTitle("Remote")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmCommand:
                    return Alert(
                        title: Text("Confirm Command"),
                        message: Text("New Target: \(Localizer.formatQuantity(newHKTarget)) \(UserDefaultsRepository.getPreferredUnit().localizedShortUnitString)\nDuration: \(Int(duration.doubleValue(for: HKUnit.minute()))) minutes"),
                        primaryButton: .default(Text("Confirm"), action: {
                            enactTempTarget()
                        }),
                        secondaryButton: .cancel()
                    )
                case .confirmCancellation:
                    return Alert(
                        title: Text("Confirm Cancellation"),
                        message: Text("Are you sure you want to cancel the existing temp target?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            cancelTempTarget()
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
            .sheet(isPresented: $showPresetSheet) {
                VStack {
                    Text("Save Preset")
                        .font(.headline)
                        .padding()
                    TextField("Preset Name", text: $presetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    HStack {
                        Button("Cancel") {
                            showPresetSheet = false
                        }
                        .padding()
                        Spacer()
                        Button("Save") {
                            presetManager.addPreset(name: presetName, target: newHKTarget, duration: duration)
                            presetName = ""
                            showPresetSheet = false
                        }
                        .disabled(presetName.isEmpty)
                        .padding()
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }

    private var isButtonDisabled: Bool {
        return newHKTarget.doubleValue(for: UserDefaultsRepository.getPreferredUnit()) == 0 ||
        duration.doubleValue(for: HKUnit.minute()) == 0 || statusManager.isLoading
    }

    private func enactTempTarget() {
        statusManager.updateStatus(.sending)

        pushNotificationManager.sendTempTargetPushNotification(target: newHKTarget, duration: duration) { success, errorMessage, apnsError in
            DispatchQueue.main.async {
                if success {
                    LogManager.shared.log(category: .apns, message: "sendTempTargetPushNotification succeeded with target: \(newHKTarget), duration: \(duration)")
                    self.statusManager.updateStatus(.success)
                } else if let apnsError = apnsError {
                    LogManager.shared.log(category: .apns, message: "sendTempTargetPushNotification failed with target: \(newHKTarget), duration: \(duration), error: \(apnsError.technicalMessage)")
                    self.statusManager.updateStatus(.failed(error: apnsError))
                } else {
                    let fallbackError = APNSErrorInfo(
                        type: .unknownError("Unknown error"),
                        shouldRetry: false,
                        suggestedDelay: nil,
                        userMessage: errorMessage ?? "Failed to send temp target command.",
                        technicalMessage: "Unknown error in temp target command"
                    )
                    self.statusManager.updateStatus(.failed(error: fallbackError))
                }
            }
        }
    }

    private func cancelTempTarget() {
        statusManager.updateStatus(.sending)

        pushNotificationManager.sendCancelTempTargetPushNotification { success, errorMessage, apnsError in
            DispatchQueue.main.async {
                if success {
                    LogManager.shared.log(category: .apns, message: "sendCancelTempTargetPushNotification succeeded")
                    self.statusManager.updateStatus(.success)
                } else if let apnsError = apnsError {
                    LogManager.shared.log(category: .apns, message: "sendCancelTempTargetPushNotification failed with error: \(apnsError.technicalMessage)")
                    self.statusManager.updateStatus(.failed(error: apnsError))
                } else {
                    let fallbackError = APNSErrorInfo(
                        type: .unknownError("Unknown error"),
                        shouldRetry: false,
                        suggestedDelay: nil,
                        userMessage: errorMessage ?? "Failed to send cancel temp target command.",
                        technicalMessage: "Unknown error in cancel temp target command"
                    )
                    self.statusManager.updateStatus(.failed(error: fallbackError))
                }
            }
        }
    }

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validation
        showAlert = true
    }
}
