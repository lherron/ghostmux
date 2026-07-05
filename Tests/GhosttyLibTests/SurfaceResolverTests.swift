import XCTest
@testable import GhosttyLib

final class SurfaceResolverTests: XCTestCase {
  private let exactId = "550e8400-e29b-41d4-a716-446655440000"
  private let prefixTwinA = "12345678-0000-4000-8000-000000000001"
  private let prefixTwinB = "12345678-ffff-4000-8000-000000000002"
  private let focusedId = "99999999-0000-4000-8000-000000000003"
  private let envId = "aaaaaaaa-0000-4000-8000-000000000004"

  private func terminals() -> [Terminal] {
    [
      Terminal(id: exactId, title: "Build Console"),
      Terminal(id: prefixTwinA, title: "Worker Alpha"),
      Terminal(id: prefixTwinB, title: "Worker Alphabet"),
      Terminal(id: focusedId, title: "Focused Pane", focused: true),
      Terminal(id: envId, title: "Environment Pane"),
    ]
  }

  func testExplicitSelectorModes() throws {
    let resolver = SurfaceResolver(
      terminals: terminals(),
      environment: { name in name == "GHOSTTY_SURFACE_UUID" ? self.envId : nil }
    )
    let policy = SurfaceResolutionPolicy(
      allowedModes: [.exactUUID, .uuidPrefix, .title, .friendlyName],
      fallbackModes: []
    )

    XCTAssertEqual(try resolver.resolve(.argument(exactId), policy: policy).id, exactId)
    XCTAssertEqual(try resolver.resolve(.argument("550e8400"), policy: policy).id, exactId)
    XCTAssertEqual(try resolver.resolve(.argument("Build Console"), policy: policy).id, exactId)
    XCTAssertEqual(
      try resolver.resolve(.argument(NameGenerator.nameFromUUID(exactId)), policy: policy).id,
      exactId
    )
  }

  func testFallbackAndFailures() throws {
    let resolver = SurfaceResolver(
      terminals: terminals(),
      environment: { name in name == "GHOSTTY_SURFACE_UUID" ? self.envId : nil }
    )

    XCTAssertEqual(
      try resolver.resolve(
        .none,
        policy: SurfaceResolutionPolicy(
          allowedModes: [.exactUUID],
          fallbackModes: [.environment("GHOSTTY_SURFACE_UUID")]
        )
      ).id,
      envId
    )

    XCTAssertEqual(
      try resolver.resolve(
        .none,
        policy: SurfaceResolutionPolicy(allowedModes: [.exactUUID], fallbackModes: [.focused])
      ).id,
      focusedId
    )

    XCTAssertThrowsError(
      try resolver.resolve(
        .argument("12345678"),
        policy: SurfaceResolutionPolicy(allowedModes: [.uuidPrefix], fallbackModes: [])
      )
    ) { error in
      guard case SurfaceResolutionError.ambiguous(let selector, let matches) = error else {
        return XCTFail("expected ambiguity, got \(error)")
      }
      XCTAssertEqual(selector, "12345678")
      XCTAssertEqual(matches.map(\.id).sorted(), [prefixTwinA, prefixTwinB].sorted())
    }
  }
}
