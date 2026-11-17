import Foundation

/// Tracks which owner (one per Flutter engine) wants which groups. A group
/// runs while at least one owner wants it, so the last owner to leave stops it.
struct GroupOwners {
  typealias Group = DynamicDeviceState.Group

  /// The groups that began or ended running after a change.
  struct Change: Equatable {
    var started: Set<Group> = []
    var stopped: Set<Group> = []

    var isEmpty: Bool {
      started.isEmpty && stopped.isEmpty
    }
  }

  private var groupsByOwner: [ObjectIdentifier: Set<Group>] = [:]

  /// The groups at least one owner wants.
  var running: Set<Group> {
    groupsByOwner.values.reduce(into: Set<Group>()) { $0.formUnion($1) }
  }

  /// Replaces the groups `owner` wants.
  mutating func set(_ owner: ObjectIdentifier, groups: Set<Group>) -> Change {
    let before = running
    groupsByOwner[owner] = groups.isEmpty ? nil : groups
    return change(since: before)
  }

  /// Removes `owner`, which then wants no group.
  mutating func release(_ owner: ObjectIdentifier) -> Change {
    let before = running
    groupsByOwner[owner] = nil
    return change(since: before)
  }

  private func change(since before: Set<Group>) -> Change {
    let after = running
    return Change(started: after.subtracting(before), stopped: before.subtracting(after))
  }
}
