import { describe, expect, test } from "bun:test";
import {
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = new URL("..", import.meta.url).pathname;

function readRepoFile(path) {
  return readFileSync(join(root, path), "utf8");
}

function makeSwiftTestPackage() {
  const dir = mkdtempSync(join(tmpdir(), "ghostmux-surface-selector-"));
  cpSync(join(root, "Sources"), join(dir, "Sources"), { recursive: true });

  writeFileSync(
    join(dir, "Package.swift"),
    `// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ghostmux-surface-selector-contract",
  platforms: [.macOS(.v13)],
  products: [],
  targets: [
    .target(name: "GhosttyLib", path: "Sources/GhosttyLib"),
    .testTarget(
      name: "GhosttyLibTests",
      dependencies: ["GhosttyLib"],
      path: "Tests/GhosttyLibTests"
    ),
  ]
)
`,
  );

  mkdirSync(join(dir, "Tests/GhosttyLibTests"), { recursive: true });
  writeFileSync(
    join(dir, "Tests/GhosttyLibTests/SurfaceSelectorResolverTests.swift"),
    `import XCTest
@testable import GhosttyLib

final class SurfaceSelectorResolverTests: XCTestCase {
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

  func testExplicitSelectorModesAndStructuredFailures() throws {
    // This is the public resolver contract for T-05632: policy chooses allowed modes,
    // and every command consumes the same result/error surface instead of bespoke matching.
    let resolver = SurfaceResolver(
      terminals: terminals(),
      environment: { name in name == "GHOSTTY_SURFACE_UUID" ? self.envId : nil }
    )
    let fullPolicy = SurfaceResolutionPolicy(
      allowedModes: [.exactUUID, .uuidPrefix, .title, .friendlyName],
      fallbackModes: []
    )

    XCTAssertEqual(
      try resolver.resolve(.argument(exactId), policy: fullPolicy).id,
      exactId,
      "exact UUID selectors resolve deterministically"
    )
    XCTAssertEqual(
      try resolver.resolve(.argument("550e8400"), policy: fullPolicy).id,
      exactId,
      "UUID prefixes and short IDs resolve through the shared policy"
    )
    XCTAssertEqual(
      try resolver.resolve(.argument("Build Console"), policy: fullPolicy).id,
      exactId,
      "title selectors remain available to regular target commands"
    )
    XCTAssertEqual(
      try resolver.resolve(.argument(NameGenerator.nameFromUUID(exactId)), policy: fullPolicy).id,
      exactId,
      "friendly generated names resolve through the shared policy"
    )

    XCTAssertThrowsError(try resolver.resolve(.argument("missing"), policy: fullPolicy)) { error in
      guard case SurfaceResolutionError.notFound(let selector, let allowedModes) = error else {
        return XCTFail("missing selectors must throw .notFound, got \\(error)")
      }
      XCTAssertEqual(selector, "missing")
      XCTAssertTrue(allowedModes.contains(.friendlyName))
    }

    XCTAssertThrowsError(try resolver.resolve(.argument("12345678"), policy: fullPolicy)) { error in
      guard case SurfaceResolutionError.ambiguous(let selector, let matches) = error else {
        return XCTFail("ambiguous prefixes must throw .ambiguous, got \\(error)")
      }
      XCTAssertEqual(selector, "12345678")
      XCTAssertEqual(matches.map(\\.id).sorted(), [prefixTwinA, prefixTwinB].sorted())
      XCTAssertTrue(
        SurfaceResolutionError.format(error).contains(prefixTwinA),
        "actionable ambiguity text lists matching surfaces"
      )
    }
  }

  func testImplicitFallbackPoliciesStayBounded() throws {
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
      envId,
      "commands that opt into environment fallback use GHOSTTY_SURFACE_UUID"
    )

    XCTAssertEqual(
      try resolver.resolve(
        .none,
        policy: SurfaceResolutionPolicy(
          allowedModes: [.exactUUID],
          fallbackModes: [.focused]
        )
      ).id,
      focusedId,
      "commands that opt into focused fallback resolve the focused pane"
    )

    XCTAssertThrowsError(
      try resolver.resolve(
        .none,
        policy: SurfaceResolutionPolicy(allowedModes: [.exactUUID], fallbackModes: [])
      )
    ) { error in
      guard case SurfaceResolutionError.missingSelector = error else {
        return XCTFail("commands without fallback must fail clearly, got \\(error)")
      }
    }
  }
}
`,
  );

  return dir;
}

describe("surface selector resolver contract", () => {
  test("GhosttyLib exposes one policy-driven resolver for every selector mode", () => {
    const dir = makeSwiftTestPackage();
    try {
      const result = spawnSync(
        "swift",
        ["test", "--filter", "^GhosttyLibTests.SurfaceSelectorResolverTests"],
        {
          cwd: dir,
          encoding: "utf8",
          timeout: 120_000,
        },
      );

      expect(
        result.status,
        `swift test should pass once the shared resolver contract exists.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
      ).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }, 150_000);

  test("screenshot, ghostchat, and regular commands do not carry bespoke target resolvers", () => {
    const utils = readRepoFile("Sources/GhosttyLib/Utils.swift");
    const screenshot = readRepoFile("Sources/ghostmux/Commands/ScreenshotCommand.swift");
    const ghostchat = readRepoFile("Sources/ghostchat/main.swift");

    expect(utils).toContain("SurfaceResolver");
    expect(utils).toContain("SurfaceResolutionPolicy");
    expect(utils).toContain("SurfaceResolutionError");
    expect(utils).not.toMatch(/public\s+func\s+resolveTarget[\s\S]*?terminals\.first/);

    expect(screenshot).not.toContain("resolveScreenshotTarget");
    expect(screenshot).toContain("SurfaceResolutionPolicy");
    expect(screenshot).toContain("SurfaceResolver");

    expect(ghostchat).not.toContain("Try to resolve target by friendly name first");
    expect(ghostchat).not.toContain("resolveTarget(target, terminals: terminals)");
    expect(ghostchat).toContain("SurfaceResolutionPolicy");
    expect(ghostchat).toContain("SurfaceResolver");

    for (const path of [
      "Sources/ghostmux/Commands/SendKeysCommand.swift",
      "Sources/ghostmux/Commands/FocusCommand.swift",
      "Sources/ghostmux/Commands/CapturePaneCommand.swift",
      "Sources/ghostmux/Commands/NewPaneCommand.swift",
      "Sources/ghostmux/Commands/PanesGridCommand.swift",
    ]) {
      const source = readRepoFile(path);
      expect(source, `${path} should resolve targets through the shared resolver`).toContain(
        "SurfaceResolutionPolicy",
      );
    }
  });
});
