// swift-tools-version:5.4
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
  ],
  targets: [
    .target(
      name: "Coordination",
      dependencies: []),
    .testTarget(
      name: "CoordinationTests",
      dependencies: ["Coordination"]),
  ]
)
