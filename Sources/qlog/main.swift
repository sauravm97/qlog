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

KnowledgeBase.parse(tokens: tokenise(code: kb), failure: { exceptions in
  print("ERROR:")
  for exception in exceptions {
    print(exception.description)
  }
}) { kb, tokens in
  Query.parse(tokens: tokenise(code: query), failure: { exceptions in
    print("ERROR:")
    for exception in exceptions {
      print(exception.description)
    }
  }) { query, tokens in
    let goals = Set<Atom>(query.terms)
    let goalVariables = variables(goals)
    let yes = Atom.yes(subjects: goalVariables.map { .variable($0) })
    let substitution = search(kb: kb, goals: goals, names: Set())
    if let substitution = substitution {
      print(yes)
      print()
      for (variable, value) in substitution {
        if goalVariables.contains(variable) {
          print("\(variable): \(value)")
        }
      }
    } else {
      print(Atom.no)
    }
  }
}
