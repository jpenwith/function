# Function

`Function` is a Swift package that provides a simple protocol for defining asynchronous functions (`Function`) and adapters for running them as AWS Lambda handlers (`FunctionLambda`). It includes:

- **Function** protocol: Defines a generic async function interface.
- **FunctionLambda** target: Provides `APIGatewayLambdaHandler` and `EventLambdaHandler` for deploying to AWS Lambda via API Gateway or direct event streams.
- Example implementation in `Sources/Example` demonstrating a name-to-age lookup using the Agify API.

## Features

- Define functions with `execute(_:) async throws -> Output`
- Automatic `Codable` encoding/decoding of inputs and outputs
- Built-in adapters for AWS Lambda & API Gateway V2
- AsyncHTTPClient-based request transformation in examples

## Getting Started

1. Add the package dependency in your `Package.swift`:
   ```swift
   .package(url: "https://github.com/yourusername/function.git", from: "1.0.0"),
   ```
2. Import and implement your function:
   ```swift
   import Function

   struct MyFunction: Function {
       func execute(_ input: MyInput) async throws -> MyOutput {
           // Your implementation here
       }
   }
   ```
3. Choose a Lambda handler:
   ```swift
   import FunctionLambda
   import AWSLambdaRuntime

   Lambda.run(APIGatewayLambdaHandler<MyFunction, JSONEncoder, JSONDecoder>())
   ```

## Example

The Example target defines `NameToAgeRemoteFunction` which fetches age data:
```swift
let function = NameToAgeRemoteFunction(
    client: .init(eventLoopGroupProvider: .createNew)
)
```

## Testing

Run the included tests with:
```bash
swift test
```

## License

MIT
