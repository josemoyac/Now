//
//  NOWTests.swift
//  NOWTests
//
//  Created by Jose Moya Carrasco on 9/21/26.
//

import Foundation
import Testing
@testable import NOW

struct NOWTests {
    @Test func decodesRadarWithoutUserLocation() throws {
        let json = #"{"intent":null,"signal":"quiet","countBand":"Actividad por descubrir","message":"Privado","match":null}"#.data(using: .utf8)!
        let value = try JSONDecoder().decode(RadarViewModel.self, from: json)
        #expect(value.signal == "quiet")
        #expect(String(data: json, encoding: .utf8)?.contains("lat") == false)
    }

    @Test func formatsISOTime() {
        #expect("2026-09-22T18:30:00.000Z".formattedTime.isEmpty == false)
    }
}
