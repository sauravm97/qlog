// swift-tools-version:4.1

import PackageDescription

let package = Package(
  name: "qlog",
  products: [
    .library(
      name: "qlog",
      targets: ["qlog"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "qlog",
      dependencies: [])
  ]
)
