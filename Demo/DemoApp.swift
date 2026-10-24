import ConstrainedDecoding
import ConstrainedDecodingUI
import SwiftUI

/// The app owns the feature's contract: the schema a ticket-triage feature must
/// produce, and the text the stand-in model "learned" (a chatty, almost-JSON
/// answer with prose, a float, a string boolean and trailing commas). The
/// library's playground runs the same model through two instances of the same
/// decoding engine: one unconstrained, one with this schema as a token mask.
@main
struct ConstrainedDecodingDemoApp: App {
    static let ticketSchema = Schema.object([
        .init("title", .string(minLength: 1, maxLength: 48)),
        .init("priority", .enumeration(["low", "medium", "high", "critical"])),
        .init("estimate_hours", .integer(maxDigits: 3)),
        .init("blocking", .boolean),
        .init("labels", .array(of: .enumeration(["crash", "editor", "ipad", "performance", "ui"]),
                               minItems: 1, maxItems: 3)),
    ])

    static let modelReference = """
    Sure! Here's the ticket as JSON. I'd call it "high" priority, it blocks the release (true), and my estimate is 6, maybe 6.5 hours:
    {"title": "Crash when rotating the photo editor", "priority": "P1", "estimate_hours": 6.5, "blocking": "yes", "labels": ["crash", "editor", "ipad",],}
    Let me know if you need anything else!
    """

    var body: some Scene {
        WindowGroup {
            ConstrainedDecodingPlayground(
                scenario: PlaygroundScenario(title: "Ticket triage",
                                             schema: Self.ticketSchema,
                                             reference: Self.modelReference))
        }
    }
}
