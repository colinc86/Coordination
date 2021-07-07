// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Coordination",
  products: [
    .library(
      name: "Coordination",
      targets: ["Coordination"]),
  ],
  dependencies: [
    .package(url: "https://github.com/colinc86/ApplicationKey", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "Coordination",
      dependencies: ["ApplicationKey"]),
    .testTarget(
      name: "CoordinationTests",
      dependencies: ["Coordination"]),
  ]
)
