import Foundation

/// Generates deterministic friendly names from UUIDs
/// Same UUID always produces the same name
public struct NameGenerator {
    // 50 adjectives for variety (50 * 50 = 2500 unique names)
    private static let adjectives = [
        "swift", "bold", "calm", "keen", "warm",
        "cool", "wise", "fair", "kind", "pure",
        "free", "true", "glad", "soft", "firm",
        "deep", "wild", "neat", "safe", "rich",
        "rare", "vast", "tall", "slim", "dark",
        "pale", "gold", "jade", "ruby", "onyx",
        "iron", "zinc", "mint", "sage", "teal",
        "rust", "navy", "plum", "lime", "rose",
        "aqua", "dawn", "dusk", "noon", "peak",
        "base", "core", "apex", "node", "edge"
    ]

    // 50 nouns for variety
    private static let nouns = [
        "falcon", "river", "storm", "flame", "frost",
        "spark", "wind", "wave", "cloud", "stone",
        "maple", "cedar", "birch", "aspen", "oak",
        "pine", "lotus", "iris", "daisy", "fern",
        "hawk", "crane", "finch", "raven", "dove",
        "wolf", "bear", "deer", "fox", "lynx",
        "tiger", "lion", "cobra", "viper", "owl",
        "comet", "nova", "star", "moon", "mars",
        "atlas", "delta", "gamma", "sigma", "theta",
        "prism", "nexus", "pulse", "helix", "axis"
    ]

    /// Generate a friendly name from a UUID string
    /// The name is deterministic - same UUID always produces same name
    public static func nameFromUUID(_ uuid: String) -> String {
        // Use first 8 chars of UUID as seed
        let cleanUUID = uuid.replacingOccurrences(of: "-", with: "").lowercased()

        // Parse first 8 hex chars as two 4-char values for adjective and noun indices
        let prefix = String(cleanUUID.prefix(8))

        // Split into two 4-char hex values
        let adjHex = String(prefix.prefix(4))
        let nounHex = String(prefix.suffix(4))

        // Convert to indices (mod by array length)
        let adjIndex = (UInt32(adjHex, radix: 16) ?? 0) % UInt32(adjectives.count)
        let nounIndex = (UInt32(nounHex, radix: 16) ?? 0) % UInt32(nouns.count)

        return "\(adjectives[Int(adjIndex)])-\(nouns[Int(nounIndex)])"
    }

    /// Get short UUID (first 8 chars)
    public static func shortUUID(_ uuid: String) -> String {
        String(uuid.prefix(8))
    }
}
