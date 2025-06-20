// The Swift Programming Language
// https://docs.swift.org/swift-book
import AsyncHTTPClient
import Foundation
import HTTPTypes
import Logging
import NIO
import NIOFoundationCompat
import NIOHTTP1

public protocol Function {
    associatedtype Input
    associatedtype Output
    
    func execute(_ input: Input) async throws -> Output
}
