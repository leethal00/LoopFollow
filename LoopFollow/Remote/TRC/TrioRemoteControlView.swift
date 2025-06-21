//
//  TrioRemoteControlView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct CommandButton {
    let command: String
    let iconName: String
    let destination: AnyView
}

struct TrioRemoteControlView: View {
    @ObservedObject var viewModel: TrioRemoteControlViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var enableCarbEntry = Storage.shared.enableCarbEntry
    @ObservedObject private var enableCancelTempTarget = Storage.shared.enableCancelTempTarget
    
    private var trioCommands: [CommandButton] {
        return [
            CommandButton(command: "Meal", iconName: "fork.knife", destination: AnyView(MealView())),
            CommandButton(command: "Bolus", iconName: "syringe", destination: AnyView(BolusView())),
            CommandButton(command: "Temp Target", iconName: "scope", destination: AnyView(TempTargetView())),
            CommandButton(command: "Overrides", iconName: "slider.horizontal.3", destination: AnyView(OverrideView()))
        ]
    }
    
    private var nightscoutCommands: [CommandButton] {
        var commands: [CommandButton] = []
        
        if enableCarbEntry.value {
            commands.append(CommandButton(command: "Carb Entry", iconName: "leaf.fill", destination: AnyView(CarbEntryView())))
        }
        
        if enableCancelTempTarget.value {
            commands.append(CommandButton(command: "Cancel Target", iconName: "xmark.circle.fill", destination: AnyView(CancelTempTargetView())))
        }
        
        return commands
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]
                    
                    // MARK: - Trio Remote Control Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Trio Remote Control")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(trioCommands.indices, id: \.self) { index in
                                let command = trioCommands[index]
                                CommandButtonView(
                                    command: command.command,
                                    iconName: command.iconName,
                                    destination: command.destination
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Nightscout Remote Control Section
                    if !nightscoutCommands.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Nightscout Remote Control")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(nightscoutCommands.indices, id: \.self) { index in
                                    let command = nightscoutCommands[index]
                                    CommandButtonView(
                                        command: command.command,
                                        iconName: command.iconName,
                                        destination: command.destination
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationBarTitle("Remote Commands", displayMode: .inline)
        }
    }
}

struct CommandButtonView: View {
    let command: String
    let iconName: String
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            VStack {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                Text(command)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
