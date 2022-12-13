// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "DriverLicenseScanner",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "DriverLicenseScanner",
      targets: ["DriverLicenseScanner"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/yhkaplan/Reg.git", from: "0.3.0"),
    .package(url: "https://github.com/yhkaplan/Sukar.git", from: "0.1.0")
  ],
  targets: [
    .target(
      name: "DriverLicenseScanner",
      dependencies: [
        "Reg",
        "Sukar"
      ]
    ),
    .testTarget(
      name: "DriverLicenseScannerTests",
      dependencies: ["DriverLicenseScanner"]
    )
  ]
)
