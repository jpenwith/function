// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "function",
	platforms: [.macOS(.v15)],
	products: [
		 .library(name: "Function", targets: ["Function"]),
         .library(name: "FunctionLambda", targets: ["FunctionLambda"]),
	],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
		.package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.20.0"),
    ],
    targets: [
        .target(
            name: "Function",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),

        .target(
            name: "FunctionLambda",
            dependencies: [
                "Function",

                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            ]
        ),

        .testTarget(
            name: "FunctionTests",
            dependencies: [
                "Function",
            ]
        ),

        .executableTarget(
            name: "Example",
            dependencies: [
                "Function",
                "FunctionLambda",

                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
		),
    ]
)
