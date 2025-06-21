//
//  LambdaRuntime.swift
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


/// A Lambda handler that adapts a RemoteFunction into an AWS Lambda handler.
/// It decodes incoming events into the function's Input type using the provided event decoder,
/// invokes the function,
/// and encodes the function's Output type into a Lambda response using the provided output encoder.
/// - generic parameters:
///   - Function: The RemoteFunction.Function type.
///   - OutputEncoder: Encoder for serializing the function output.
///   - EventDecoder: Decoder for deserializing the Lambda event into function input.
public struct EventLambdaHandler<F, OutputEncoder, EventDecoder>: StreamingLambdaHandler
where
    F: Function,
    OutputEncoder: AWSLambdaRuntime.LambdaOutputEncoder,
    EventDecoder: AWSLambdaRuntime.LambdaEventDecoder,
    F.Input: Decodable,
    F.Output: Encodable,
    OutputEncoder.Output == F.Output
{
    var internalHandler: LambdaCodableAdapter<
        LambdaHandlerAdapter<
            F.Input,
            F.Output,
            InternalEventLambdaHandler<
                F
            >
        >,
        F.Input,
        F.Output,
        EventDecoder,
        OutputEncoder
    >
    
    public init(
        function: sending F,
        lambdaOutputEncoder: sending OutputEncoder,
        lambdaEventDecoder: sending EventDecoder
    ) {
        self.internalHandler = LambdaCodableAdapter(
            encoder: lambdaOutputEncoder,
            decoder: lambdaEventDecoder,
            handler: LambdaHandlerAdapter(
                handler: InternalEventLambdaHandler(
                    function: function
                )
            )
        )
    }
    
    public init(
        function: sending F
    )
    where
        EventDecoder == LambdaJSONEventDecoder,
        OutputEncoder == LambdaJSONOutputEncoder<F.Output>
    {
        self.init(
            function: function,
            lambdaOutputEncoder: LambdaJSONOutputEncoder<F.Output>(.init()),
            lambdaEventDecoder: LambdaJSONEventDecoder(.init())
        )
    }

    
    public mutating func handle(_ event: ByteBuffer, responseWriter: some LambdaResponseStreamWriter, context: LambdaContext) async throws {
        try await internalHandler.handle(event, responseWriter: responseWriter, context: context)
    }
}

/// Internal handler that invokes the RemoteFunction client with decoded input
/// and returns the function's output.
///
/// It receives events of type `F.Input`, calls `client.execute`, and returns `F.Output`.
struct InternalEventLambdaHandler<F>: LambdaHandler
where
    F: Function
{
    let function: F

    init(
        function: F
    ) {
        self.function = function
    }

    func handle(_ event: F.Input, context: LambdaContext) async throws -> F.Output {
        context.logger.trace(.init(stringLiteral: String(describing: event)))
        context.logger.trace(.init(stringLiteral: String(describing: context)))

        let output = try await function.execute(event)

        context.logger.trace(.init(stringLiteral: String(describing: output)))

        return output
    }
}
