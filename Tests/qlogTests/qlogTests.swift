import XCTest
@testable import qlog

final class qlogTests: XCTestCase {
    func testBasic() {
      let kb = """
        happy(sam).
        fun(ai).
        live_underground(worms).
        night_time.
        eats(bird, apple).
        eaten(X) <- eats(Y, X).
        switch(up) <- in_room(sam), night_time.
      """

      let query = """
        ask eaten(X), fun(Y), eaten(Z) ?
      """

      let solution = [
        Variable(name: "X"): Value(atom: Atom(predicate: "apple", subjects: [])),
        Variable(name: "Y"): Value(atom: Atom(predicate: "ai", subjects: [])),
        Variable(name: "Z"): Value(atom: Atom(predicate: "apple", subjects: [])),
      ]

      solve(kb: kb, query: query) { result in
        switch result {
        case .yes(let (_, substitution)):
          XCTAssert(substitution == solution)
        case .no:
          XCTAssert(false)
        }
      }
    }

    static var allTests = [
        ("testBasic", testBasic),
    ]
}
