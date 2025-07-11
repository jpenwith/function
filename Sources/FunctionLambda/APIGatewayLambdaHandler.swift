//
//  APIGatewayHandler.swift
//  api-guard
//
//  Created by James Penwith on 12/06/2025.
//
import AsyncHTTPClient
import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import NIO
import Function


/// A Lambda handler that adapts a RemoteFunction into an AWS API Gateway handler.
/// It decodes incoming API Gateway V2 request events into the function’s Input type using the provided request decoder and event decoder,
/// invokes the function,
/// and encodes the function’s output into an API Gateway V2 response using the provided output encoder and response encoder.
/// - generic parameters:
///   - Function: The RemoteFunction.Function type.
///   - ResponseEncoder: Encoder for serializing API Gateway V2 Response.
///   - RequestDecoder: Decoder for deserializing API Gateway V2 Request.
///   - OutputEncoder: Encoder for serializing the function output.
///   - EventDecoder: Decoder for deserializing the Lambda event into function input.
public struct APIGatewayLambdaHandler<
    F, ResponseEncoder, RequestDecoder, OutputEncoder, EventDecoder
>: StreamingLambdaHandler
where
    F: Function,
    ResponseEncoder: AWSLambdaRuntime.LambdaOutputEncoder,
    RequestDecoder: AWSLambdaRuntime.LambdaEventDecoder,
    OutputEncoder: AWSLambdaRuntime.LambdaOutputEncoder,
    EventDecoder: AWSLambdaRuntime.LambdaEventDecoder,
    F.Input: Decodable,
    F.Output: Encodable,
    ResponseEncoder.Output == AWSLambdaEvents.APIGatewayV2Response,
    OutputEncoder.Output == F.Output
{
    var internalHandler: LambdaCodableAdapter<
        LambdaHandlerAdapter<
            AWSLambdaEvents.APIGatewayV2Request,
            AWSLambdaEvents.APIGatewayV2Response,
            InternalAPIGatewayHandler<
                EventDecoder,
                OutputEncoder,
                InternalEventLambdaHandler<
                    F
                >
            >
        >,
        AWSLambdaEvents.APIGatewayV2Request,
        AWSLambdaEvents.APIGatewayV2Response,
        RequestDecoder,
        ResponseEncoder
    >

    public init(
        function: sending F,
        responseEncoder: sending ResponseEncoder,
        requestDecoder: sending RequestDecoder,
        outputEncoder: sending OutputEncoder,
        eventDecoder: sending EventDecoder
    ) {
        self.internalHandler = LambdaCodableAdapter(
            encoder: responseEncoder,
            decoder: requestDecoder,
            handler: LambdaHandlerAdapter(
                handler: InternalAPIGatewayHandler(
                    eventDecoder: eventDecoder,
                    outputEncoder: outputEncoder,
                    handler: InternalEventLambdaHandler(
                        function: function
                    )
                )
            )
        )

    }
    
    public init(
        function: sending F
    )
    where
        RequestDecoder == LambdaJSONEventDecoder,
        ResponseEncoder == LambdaJSONOutputEncoder<APIGatewayV2Response>,
        EventDecoder == LambdaJSONEventDecoder,
        OutputEncoder == LambdaJSONOutputEncoder<F.Output>
    {
        self.init(
            function: function,
            responseEncoder: LambdaJSONOutputEncoder<APIGatewayV2Response>(.init()),
            requestDecoder: LambdaJSONEventDecoder(.init()),
            outputEncoder: LambdaJSONOutputEncoder<F.Output>(.init()),
            eventDecoder: LambdaJSONEventDecoder(.init()))
    }

    public mutating func handle(_ event: ByteBuffer, responseWriter: some LambdaResponseStreamWriter, context: LambdaContext) async throws {
        do {
            try await internalHandler.handle(event, responseWriter: responseWriter, context: context)
        }
        catch {
//            let errorOutput = ErrorOutput(error: error.localizedDescription)
            let errorOutput = ErrorOutput(error: "\(error)")
            
            let errorOutputBuffer = try JSONEncoder(outputFormatting: .prettyPrinted)
                .encodeAsByteBuffer(errorOutput, allocator: .init())
            
            try await responseWriter.writeAndFinish(errorOutputBuffer)
        }
    }

    public struct ErrorOutput: Codable {
        public let error: String
    }    
}

/// Internal API Gateway handler that adapts a decoded API Gateway request into the function invocation.
/// It decodes the APIGatewayV2Request's body into the nested handler's Event using `eventDecoder`,
/// invokes the nested handler to produce an output,
/// and encodes the output into a body for an APIGatewayV2Response using `outputEncoder`.
struct InternalAPIGatewayHandler<EventDecoder, OutputEncoder, Handler>: LambdaHandler
where
    EventDecoder: AWSLambdaRuntime.LambdaEventDecoder,
    OutputEncoder: AWSLambdaRuntime.LambdaOutputEncoder,
    Handler: LambdaHandler,
    Handler.Event: Decodable,
    Handler.Output: Encodable,
    OutputEncoder.Output == Handler.Output
{
    let eventDecoder: EventDecoder
    let outputEncoder: OutputEncoder
    let handler: Handler
    
    init(eventDecoder: EventDecoder, outputEncoder: OutputEncoder, handler: Handler) {
        self.eventDecoder = eventDecoder
        self.outputEncoder = outputEncoder
        self.handler = handler
    }
    
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        context.logger.trace(.init(stringLiteral: String(describing: event)))
        context.logger.trace(.init(stringLiteral: String(describing: context)))

        let request = event

        //Grab the request body
        guard let requestBodyData = request.body?.data(using: .utf8) else {
            throw Error.noRequestBody
        }

        //Decode if necessary
        guard let requestBodyDecodedData = event.isBase64Encoded ? Data(base64Encoded: requestBodyData) : requestBodyData else {
            throw Error.invalidRequestBody
        }

        //Decode the event from the request body
        let handlerEvent = try eventDecoder.decode(Handler.Event.self, from: .init(data: requestBodyDecodedData))

        //Pass to the handler
        let handerOutput = try await handler.handle(handlerEvent, context: context)

        //Encode the output into the response body
        var responseBodyBuffer = ByteBuffer()
        try outputEncoder.encode(handerOutput, into: &responseBodyBuffer)

        //Return the response
        return .init(
            statusCode: .ok,
            body: String(buffer: responseBodyBuffer),
            isBase64Encoded: false
        )
    }

    enum Error: Swift.Error {
        case noRequestBody
        case invalidRequestBody
    }
}
