enum Result<Y, N> {
  case yes(Y)
  case no(N)
}

func solve(kb: String, query: String, success: @escaping (Result<(Atom, Substitution), Atom>) -> Void) {
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
      if let substitution = search(kb: kb, goals: goals, names: Set()) {
        success(.yes((yes, substitution.filter { goalVariables.contains($0.key) })))
      } else {
        success(.no(Atom.no))
      }
    }
  }
}
