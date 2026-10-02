import Foundation

enum WatchError: Error, Equatable {
    /// The requested end time is not after the start time.
    case endNotInFuture
    /// A watch is already active; only one may run at a time.
    case activeWatchExists
    /// The operation needs an active watch and there is none.
    case notActive
    /// The operation needs an ended watch, but this one is still active.
    case stillActive
    /// The change could not be written to the store.
    case persistenceFailed
}
