import SwiftUI

@MainActor
protocol Module: AnyObject {
    var id: String { get }
    var name: String { get }
    var sfSymbol: String { get }
    var tintColor: Color { get }
    func makeContent() -> AnyView
}
