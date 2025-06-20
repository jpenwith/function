//
//  RemoteFunctionTests.swift
//  api-guard
//
//  Created by James Penwith on 19/06/2025.
//

import Foundation
import Testing
@testable import RemoteFunction

@Test func testDoubleFunction() async throws {
    struct DoubleFunction: RemoteFunction.Function {
        func execute(_ input: Int) async throws -> Int { input * 2 }
    }
    
    let doubleFunction = DoubleFunction()
    #expect(try await doubleFunction.execute(7) == 14)
}

@Test func testStringCountFunction() async throws {
    struct StringCountFunction: RemoteFunction.Function {
        func execute(_ input: String) async throws -> Int { input.count }
    }
    
    let stringCountFunction = StringCountFunction()
    #expect(try await stringCountFunction.execute("Hi there") == 8)
}

@Test func testStartOfDayFunction() async throws {
    struct StartOfDayFunction: RemoteFunction.Function {
        func execute(_ input: Date) async throws -> Date? { Calendar.autoupdatingCurrent.startOfDay(for: input) }
    }

    let startOfDayFunction = StartOfDayFunction()
    #expect(try await startOfDayFunction.execute(Date(timeIntervalSinceReferenceDate: 12345)) == Date(timeIntervalSinceReferenceDate: 0))
}
