//
// FeedTypeTests.swift
//
// Copyright (c) 2016 - 2026 Nuno Dias
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@testable import FeedKit
import Foundation
import Testing

@Suite("FeedType")
struct FeedTypeTests: FeedKitTestable {
  @Test
  func atomFeedType() throws {
    // Given
    let data = data(resource: "Atom", withExtension: "xml")
    let expected: FeedType = .atom

    // When
    let actual = try FeedType(data: data)

    // Then
    #expect(actual.isXML)
    #expect(expected == actual)
  }

  @Test
  func rssFeedType() throws {
    // Given
    let data = data(resource: "RSS", withExtension: "xml")
    let expected: FeedType = .rss

    // When
    let actual = try FeedType(data: data)

    // Then
    #expect(actual.isXML)
    #expect(expected == actual)
  }

  @Test
  func jsonFeedType() throws {
    // Given
    let data = data(resource: "feed", withExtension: "json")
    let expected: FeedType = .json

    // When
    let actual = try FeedType(data: data)

    // Then
    #expect(actual.isJson)
    #expect(expected == actual)
  }

  @Test
  func shortRSSFeed() throws {
    let xml = #"<rss version="2.0"><channel><title>Short RSS</title></channel></rss>"#
    #expect(try FeedType(data: Data(xml.utf8)) == .rss)
    #expect(try Feed(string: xml).rss?.channel?.title == "Short RSS")
  }

  @Test
  func shortAtomFeed() throws {
    let xml = #"<feed xmlns="http://www.w3.org/2005/Atom"><title>Short Atom</title></feed>"#
    #expect(try FeedType(data: Data(xml.utf8)) == .atom)
    #expect(try Feed(string: xml).atom?.title?.text == "Short Atom")
  }

  @Test
  func shortJSONFeed() throws {
    let json = #"{"version":"https://jsonfeed.org/version/1.1","title":"Short JSON","items":[]}"#
    #expect(try FeedType(data: Data(json.utf8)) == .json)
    #expect(try Feed(string: json).json?.title == "Short JSON")
  }

  @Test(arguments: [149, 647])
  func xmlFeedsWithLongPrologs(rootOffset: Int) throws {
    // Declarations, stylesheet instructions and padding can push the root
    // beyond the old detection window, as in the reported Freak Show feed.
    let declaration = #"<?xml version="1.0" encoding="UTF-8"?><?xml-stylesheet type="text/xsl" href="feed.xsl"?><!-- Feed -->"#
    let prolog = declaration + String(repeating: " ", count: rootOffset - declaration.utf8.count)
    let rss = prolog + #"<rss version="2.0"><channel><title>Padded RSS</title></channel></rss>"#
    let atom = prolog + #"<feed xmlns="http://www.w3.org/2005/Atom"><title>Padded Atom</title></feed>"#

    #expect(try FeedType(data: Data(rss.utf8)) == .rss)
    #expect(try FeedType(data: Data(atom.utf8)) == .atom)
    #expect(try Feed(string: rss).rss?.channel?.title == "Padded RSS")
    #expect(try Feed(string: atom).atom?.title?.text == "Padded Atom")
  }

  @Test(arguments: ["", " \n\t", "not a feed", "<html><body>Error</body></html>"])
  func unsupportedShortInputStillThrows(input: String) {
    #expect(throws: FeedError.self) {
      try FeedType(data: Data(input.utf8))
    }
  }

  @Test
  func malformedShortXMLStillThrows() throws {
    let xml = "<rss><channel></wrong></rss>"
    #expect(try FeedType(data: Data(xml.utf8)) == .rss)
    #expect(throws: (any Error).self) {
      try Feed(string: xml)
    }
  }
}
