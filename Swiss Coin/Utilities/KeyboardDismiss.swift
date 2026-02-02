//
//  KeyboardDismiss.swift
//  Swiss Coin
//
//  Utility extension for dismissing the keyboard from any view.
//

import SwiftUI

extension View {
    /// Dismisses the keyboard by resigning the first responder.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
