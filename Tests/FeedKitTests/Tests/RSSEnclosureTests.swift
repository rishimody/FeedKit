//
// RSSEnclosureTests.swift
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

import FeedKit
import Foundation
import Testing

@Suite("RSS enclosure length")
struct RSSEnclosureTests {
  struct LengthCase: Sendable {
    let value: String?
    let expected: Int64?
  }

  static let lengthCases: [LengthCase] = [
    .init(value: "12345", expected: 12345),
    .init(value: "0", expected: 0),
    .init(value: String(Int64.max), expected: Int64.max),
    .init(value: " 12345 ", expected: 12345),
    .init(value: nil, expected: nil),
    .init(value: "", expected: nil),
    .init(value: "   ", expected: nil),
    .init(value: "unknown", expected: nil),
    .init(value: "12.5", expected: nil),
    .init(value: "-1", expected: nil),
    .init(value: "9223372036854775808", expected: nil)
  ]

  @Test(arguments: lengthCases)
  func decodesLength(testCase: LengthCase) throws {
    let rss = try #require(Feed(string: Self.feed(items: Self.item(length: testCase.value))).rss)
    let item = try #require(rss.channel?.items?.first)
    let enclosure = try #require(item.enclosure?.attributes)

    #expect(enclosure.length == testCase.expected)
    #expect(enclosure.url == "https://example.com/episode-1.mp3")
    #expect(enclosure.type == "audio/mpeg")
    #expect(item.guid?.text == "episode-1")
    #expect(item.title == "Episode 1")
    #expect(item.iTunes?.duration == 3723)
    #expect(item.pubDate != nil)
  }

  @Test
  func invalidLengthsDoNotDiscardItems() throws {
    let items = Self.lengthCases.enumerated().map { index, testCase in
      Self.item(index: index + 1, length: testCase.value)
    }.joined()
    let rss = try #require(Feed(string: Self.feed(items: items)).rss)
    let decoded = try #require(rss.channel?.items)

    #expect(decoded.count == Self.lengthCases.count)
    for (index, item) in decoded.enumerated() {
      #expect(item.enclosure?.attributes?.length == Self.lengthCases[index].expected)
      #expect(item.guid?.text == "episode-\(index + 1)")
      #expect(item.enclosure?.attributes?.url == "https://example.com/episode-\(index + 1).mp3")
    }
  }

  @Test
  func unknownDurationRemainsIndependentOfLength() throws {
    for duration: String? in [nil, "", "unknown", "0"] {
      let rss = try #require(Feed(string: Self.feed(items: Self.item(length: "", duration: duration))).rss)
      let item = try #require(rss.channel?.items?.first)
      #expect(item.enclosure?.attributes?.length == nil)
      #expect(item.guid?.text == "episode-1")
      #expect(item.iTunes?.duration == (duration == "0" ? 0 : nil))
    }
  }

  @Test
  func codableRoundTripsPreserveNumericLengths() throws {
    for length: Int64? in [nil, 0, 12345, Int64.max] {
      let original = RSSFeedEnclosureAttributes(
        url: "https://example.com/audio.mp3", length: length, type: "audio/mpeg"
      )
      let data = try JSONEncoder().encode(original)
      #expect(try JSONDecoder().decode(RSSFeedEnclosureAttributes.self, from: data) == original)
      let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      if length != nil {
        #expect(object["length"] is NSNumber)
      } else {
        #expect(object["length"] == nil)
      }
    }
  }

  @Test
  func xmlRoundTripsPreserveEnclosures() throws {
    for length: String? in [nil, "", "0", "12345", String(Int64.max)] {
      let original = try RSSFeed(string: Self.feed(items: Self.item(length: length)))
      let xml = try original.toXMLString(formatted: false)
      let decoded = try RSSFeed(string: xml)
      let expected = try #require(original.channel?.items?.first?.enclosure)
      let actual = try #require(decoded.channel?.items?.first?.enclosure)
      #expect(actual == expected)
    }
  }

  @Test
  func invalidOtherFieldsStillThrow() throws {
    for field in ["url", "type"] {
      let data = try JSONSerialization.data(withJSONObject: [field: 123, "length": ""])
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(RSSFeedEnclosureAttributes.self, from: data)
      }
    }
  }

  @Test
  func malformedXMLStillThrows() {
    let xml = Self.feed(items: Self.item(length: "")).replacingOccurrences(of: "</channel>", with: "</wrong>")
    #expect(throws: (any Error).self) {
      try Feed(string: xml)
    }
  }

  private static func feed(items: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>Enclosure regression feed</title>
        <link>https://example.com/</link>
        <description>A podcast with optional or malformed enclosure byte counts.</description>
        <itunes:author>Example Publisher</itunes:author>
        <itunes:image href="https://example.com/artwork.png"/>
        \(items)
      </channel>
    </rss>
    """
  }

  private static func item(index: Int = 1, length: String?, duration: String? = "01:02:03") -> String {
    let lengthAttribute = length.map { " length=\"\($0)\"" } ?? ""
    let durationElement = duration.map { "<itunes:duration>\($0)</itunes:duration>" } ?? ""
    return """
    <item>
      <title>Episode \(index)</title>
      <description>Playable audio whose byte count is not essential to loading.</description>
      <guid isPermaLink="false">episode-\(index)</guid>
      <pubDate>Mon, 09 Nov 2026 10:00:00 GMT</pubDate>
      <enclosure url="https://example.com/episode-\(index).mp3" type="audio/mpeg"\(lengthAttribute)/>
      \(durationElement)
    </item>
    """
  }
}
