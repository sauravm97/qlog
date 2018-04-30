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

    solve(kb: kb, query: query, failure: { exceptions in
      print("ERROR:")
      for exception in exceptions {
        print(exception.description)
      }
      XCTAssert(false)
    }) { result in
      switch result {
      case .yes(let (_, substitution)):
        XCTAssert(substitution == solution)
      case .no:
        XCTAssert(false)
      }
    }
  }

  func testAdvanced() {
    let kb = """
      % imm_west(W,E) is true if room W is immediately west of room E.
      imm_west(r101,r103).
      imm_west(r103,r105).
      imm_west(r105,r107).
      imm_west(r107,r109).
      imm_west(r109,r111).
      imm_west(r131,r129).
      imm_west(r129,r127).
      imm_west(r127,r125).

      % imm_east(E,W) is true if room E is immediately east of room W.
      imm_east(E,W) <- imm_west(W,E).

      % next_door(R1,R2) is true if room R1 is next door to room R2.
      next_door(E,W) <- imm_east(E,W).
      next_door(W,E) <- imm_west(W,E).

      % two_doors_east(E,W) is true if room E is two doors east of room W.
      two_doors_east(E,W) <- imm_east(E,M), imm_east(M,W).

      % west(W,E) is true if room W is west of room E.
      west(W,E) <- imm_west(W,E).
      west(W,E) <- imm_west(W,M), west(M,E).
      """

    let query = """
      ask two_doors_east(R,r107)?
    """

    let solution = [
      Variable(name: "R"): Value(atom: Atom(predicate: "r111", subjects: [])),
      ]

    solve(kb: kb, query: query, failure: { exceptions in
      print("ERROR:")
      for exception in exceptions {
        print(exception.description)
      }
      XCTAssert(false)
    }) { result in
      switch result {
      case .yes(let (_, substitution)):
        print(substitution)
        XCTAssert(substitution == solution)
      case .no:
        XCTAssert(false)
      }
    }
  }

  static var allTests = [
    ("testBasic", testBasic),
    ("testAdvanced", testAdvanced),
    ]
}
