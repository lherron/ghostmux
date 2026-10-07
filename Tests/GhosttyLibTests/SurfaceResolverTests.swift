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

  /// Records which terminal-source calls a resolution made.
  private final class TerminalSourceSpy {
    let terminals: [Terminal]
    var fetchedIds: [String] = []
    var listCalls = 0

    init(terminals: [Terminal]) {
      self.terminals = terminals
    }

    func fetch(_ id: String) throws -> Terminal? {
      fetchedIds.append(id)
      return terminals.first { $0.id.lowercased() == id.lowercased() }
    }

    func list() throws -> [Terminal] {
      listCalls += 1
      return terminals
    }
  }

  private func resolveWithSource(
    _ target: String?,
    policy: SurfaceResolutionPolicy,
    spy: TerminalSourceSpy,
    environment: @escaping SurfaceResolver.EnvironmentLookup = { _ in nil }
  ) throws -> Terminal {
    try SurfaceResolver.resolve(
      target: target,
      policy: policy,
      environment: environment,
      fetchTerminal: spy.fetch,
      listTerminals: spy.list
    )
  }

  func testFullUUIDTargetFetchesOneTerminalWithoutListing() throws {
    let spy = TerminalSourceSpy(terminals: terminals())

    let resolved = try resolveWithSource(exactId.uppercased(), policy: .regularTarget, spy: spy)

    XCTAssertEqual(resolved.id, exactId)
    XCTAssertEqual(spy.fetchedIds, [exactId.uppercased()])
    XCTAssertEqual(spy.listCalls, 0)
  }

  func testEnvironmentFullUUIDFallbackFetchesWithoutListing() throws {
    let spy = TerminalSourceSpy(terminals: terminals())

    let resolved = try resolveWithSource(
      nil,
      policy: .regularTarget,
      spy: spy,
      environment: { name in name == "GHOSTTY_SURFACE_UUID" ? self.envId : nil }
    )

    XCTAssertEqual(resolved.id, envId)
    XCTAssertEqual(spy.listCalls, 0)
  }

  func testNonUUIDSelectorsStillListTerminals() throws {
    let selectors = ["550e8400", "Build Console", NameGenerator.nameFromUUID(exactId)]
    for selector in selectors {
      let spy = TerminalSourceSpy(terminals: terminals())

      let resolved = try resolveWithSource(selector, policy: .regularTarget, spy: spy)

      XCTAssertEqual(resolved.id, exactId, selector)
      XCTAssertEqual(spy.fetchedIds, [], selector)
      XCTAssertEqual(spy.listCalls, 1, selector)
    }
  }

  func testMissingFullUUIDFallsBackToListingAndKeepsNotFoundError() {
    let missing = "00000000-0000-4000-8000-00000000dead"
    let spy = TerminalSourceSpy(terminals: terminals())

    XCTAssertThrowsError(try resolveWithSource(missing, policy: .regularTarget, spy: spy)) {
      error in
      guard case SurfaceResolutionError.notFound(let selector, let modes) = error else {
        return XCTFail("expected notFound, got \(error)")
      }
      XCTAssertEqual(selector, missing)
      XCTAssertEqual(modes, SurfaceResolutionPolicy.regularTarget.allowedModes)
    }
    XCTAssertEqual(spy.fetchedIds, [missing])
    XCTAssertEqual(spy.listCalls, 1)
  }

  func testPolicyWithoutExactUUIDNeverFetchesDirectly() throws {
    let spy = TerminalSourceSpy(terminals: terminals())
    let titleOnly = SurfaceResolutionPolicy(allowedModes: [.title], fallbackModes: [])

    XCTAssertThrowsError(try resolveWithSource(exactId, policy: titleOnly, spy: spy))
    XCTAssertEqual(spy.fetchedIds, [])
    XCTAssertEqual(spy.listCalls, 1)
  }

  func testFocusedFallbackStillLists() throws {
    let spy = TerminalSourceSpy(terminals: terminals())

    let resolved = try resolveWithSource(nil, policy: .focusedTarget, spy: spy)

    XCTAssertEqual(resolved.id, focusedId)
    XCTAssertEqual(spy.fetchedIds, [])
    XCTAssertEqual(spy.listCalls, 1)
  }
}
