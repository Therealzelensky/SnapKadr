import Foundation

public struct StenoSnoozeState: Equatable, Sendable {
    private var snoozed: Set<UInt32> = []

    public init() {}

    public mutating func snooze(_ id: UInt32) {
        snoozed.insert(id)
    }

    public mutating func reap(presentIDs: Set<UInt32>) {
        snoozed = snoozed.intersection(presentIDs)
    }

    public func isSnoozed(_ id: UInt32) -> Bool {
        snoozed.contains(id)
    }
}
