//
//  NOWApp.swift
//  NOW
//
//  Created by Jose Moya Carrasco on 9/21/26.
//

import SwiftUI

@main
struct NOWApp: App {
    @StateObject private var model = NOWModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
