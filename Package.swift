// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Event",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Event",
            targets: ["Event"]),
    ],
    dependencies: [
        .package(name: "Platform"),
        .package(name: "Log"),
        .package(name: "Test"),
    ],
    targets: [
        .target(
            name: "Event",
            dependencies: [
                .product(name: "Platform", package: "platform"),
                .product(name: "Log", package: "log"),
            ]),
        .executableTarget(
            name: "Tests/Event",
            dependencies: [
                .target(name: "Event"),
                .product(name: "Test", package: "test"),
            ],
            path: "Tests/Event"),
    ]
)

#if os(Linux)
package.targets.append(.systemLibrary(name: "CEpoll", path: "./Headers/CEpoll"))
package.targets[0].dependencies.append("CEpoll")
#endif

// MARK: - custom package source

#if canImport(ObjectiveC)
import Darwin.C
#else
import Glibc
#endif

extension Package.Dependency {
    enum Source: String {
        case local, remote, github

        static var `default`: Self { .github }

        var baseUrl: String {
            switch self {
            case .local: return "../"
            case .remote: return "https://swiftstack.io/"
            case .github: return "https://github.com/swiftstack/"
            }
        }

        func url(for name: String) -> String {
            return self == .local
                ? baseUrl + name.lowercased()
                : baseUrl + name.lowercased() + ".git"
        }
    }

    static func package(name: String) -> Package.Dependency {
        guard let pointer = getenv("SWIFTSTACK") else {
            return .package(name: name, source: .default)
        }
        guard let source = Source(rawValue: String(cString: pointer)) else {
            fatalError("Invalid source. Use local, remote or github")
        }
        return .package(name: name, source: source)
    }

    static func package(name: String, source: Source) -> Package.Dependency {
        return source == .local
            ? .package(name: name, path: source.url(for: name))
            : .package(url: source.url(for: name), branch: "dev")
    }
}
