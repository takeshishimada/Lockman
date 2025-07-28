import Foundation
@testable import Lockman

// MARK: - Test-Only Equatable Conformance

extension LockmanResult: Equatable {
  public static func == (lhs: LockmanResult, rhs: LockmanResult) -> Bool {
    switch (lhs, rhs) {
    case (.success, .success):
      return true
    case (
      .successWithPrecedingCancellation(let lhsError),
      .successWithPrecedingCancellation(let rhsError)
    ):
      // Compare errors by their localized description since Error is not Equatable
      return lhsError.localizedDescription == rhsError.localizedDescription
    case (.cancel(let lhsError), .cancel(let rhsError)):
      // Compare errors by their localized description since Error is not Equatable
      return lhsError.localizedDescription == rhsError.localizedDescription
    default:
      return false
    }
  }
}