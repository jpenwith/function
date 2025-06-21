// The Swift Programming Language
// https://docs.swift.org/swift-book
import AsyncHTTPClient
import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import HTTPTypes
import Logging
import NIO
import NIOFoundationCompat
import NIOHTTP1
import Function
import FunctionLambda



struct NameToAgeRemoteFunction: Function {
    let client: AsyncHTTPClient.HTTPClient

    func transformAgeRequest(_ input: AgeRequest) -> AsyncHTTPClient.HTTPClientRequest {
        var request = HTTPClientRequest(url: "https://api.agify.io/?name=\(input.name)")

        request.headers.add(name: "Accept-Encoding", value: "identity") //api.agify.io seems to invalidly `deflate` the response if no accept is specified

        return request
    }

    func transformHTTPResponse(_ response: HTTPClientResponse) async throws -> AgeResponse {
        let bodyBuffer = try await response.body.collect(upTo: .max)

        let responseBody = try JSONDecoder().decode(AgeResponse.self, from: bodyBuffer)

        return .init(age: responseBody.age)
    }
    
    func execute(_ input: AgeRequest) async throws -> AgeResponse {
        let httpRequest = transformAgeRequest(input)

        let httpResponse = try await client.execute(httpRequest, deadline: .now() + .seconds(30), logger: nil)
        
        let ageResponse = try await transformHTTPResponse(httpResponse)
        
        return ageResponse
    }

    struct AgeRequest: Codable {
        let name: String
    }

    struct AgeResponse: Codable {
        let age: Int
    }
}

try await LambdaRuntime(
    handler: FunctionLambda.APIGatewayLambdaHandler(function: NameToAgeRemoteFunction(client: .shared))
)
.run()
