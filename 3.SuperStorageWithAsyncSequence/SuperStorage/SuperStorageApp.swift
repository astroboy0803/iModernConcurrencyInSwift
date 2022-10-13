//
//  SuperStorageApp.swift
//  SuperStorage
//
//  Created by BruceHuang on 2022/5/5.
//

import SwiftUI

@main
struct SuperStorageApp: App {
    var body: some Scene {
        WindowGroup {
            ListView(model: SuperStorageModel())
        }
    }
}
