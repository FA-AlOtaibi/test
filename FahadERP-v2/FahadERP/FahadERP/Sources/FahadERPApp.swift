import SwiftUI

@main
struct FahadERPApp: App {
    @State private var auth = AuthViewModel()
    @State private var store = ERPStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
