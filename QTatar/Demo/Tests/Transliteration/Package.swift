// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Transliteration", platforms: [.macOS(.v13)], targets: [
    .target(name: "Transliteration", resources: [.process("TransliterationRules.json")]),
    .testTarget(name: "TransliterationTests", dependencies: ["Transliteration"], resources: [.copy("Resources/parity.json")])
])
