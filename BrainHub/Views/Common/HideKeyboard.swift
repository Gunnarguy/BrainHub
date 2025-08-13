import SwiftUI

extension View {
    /// Dismisses the keyboard (end editing) for UIKit-backed scenes.
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
