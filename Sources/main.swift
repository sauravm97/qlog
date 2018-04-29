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

func selectGoal(fromGoals goals: Set<Atom>) -> Atom? {
  return goals.first
}

func unify(_ atom: Atom, with goal: Atom) -> (atomToGoal: [Variable: Subject], goalToAtom: [Variable: Value])? {
  guard atom.predicate == goal.predicate else {
    return nil
  }
  var atomToGoal: [Variable: Subject] = [:]
  var goalToAtom: [Variable: Value] = [:]
  for (atomSubject, goalSubject) in zip(atom.subjects, goal.subjects) {
    if case let .value(atomSubjectValue) = atomSubject, case let .value(goalSubjectValue) = goalSubject {
      guard
        let subunification = unify(atomSubjectValue.atom, with: goalSubjectValue.atom),
        let _ = try? atomToGoal.merge(subunification.atomToGoal, uniquingKeysWith: {
          s1, s2 in
          guard s1 == s2 else {
            throw Exception(description: "")
          }
          return s1
        }),
        let _ = try? goalToAtom.merge(subunification.goalToAtom, uniquingKeysWith: {
          v1, v2 in
          guard v1 == v2 else {
            throw Exception(description: "")
          }
          return v1
        }) else {
          return nil
      }
    } else if case let .variable(atomSubjectVariable) = atomSubject {
      atomToGoal[atomSubjectVariable] = goalSubject
    } else if case let .variable(goalSubjectVariable) = goalSubject, case let .value(atomSubjectValue) = atomSubject {
      goalToAtom[goalSubjectVariable] = atomSubjectValue
    }
  }
  return (atomToGoal: atomToGoal, goalToAtom: goalToAtom)
}

func variables<T: Sequence>(_ atoms: T) -> Set<Variable> where T.Element == Atom {
  return Set(atoms.flatMap { $0.subjects }.compactMap {
    if case let .variable(variable) = $0 {
      return variable
    }
    return nil
  })
}

var counter = 0
func uniqueVariable(from: Set<Variable>) -> Variable {
  let name = "temp\(counter)"
  counter += 1
  return Variable(name: name)
}

func search(kb: KnowledgeBase, goals: Set<Atom>, names: Set<Variable>) -> Substitution? {
  if goals.isEmpty {
    return [:]
  }

  guard let goal = selectGoal(fromGoals: goals) else {
    return nil
  }
  let goals = goals.subtracting([goal])

  for sentence in kb.sentences {
    guard let (atomToGoal, goalToAtom) = unify(sentence.head, with: goal) else {
      continue
    }
    let terms = sentence.body.terms.map { atom in
      Atom(predicate: atom.predicate, subjects: atom.subjects.map {
        if case let .variable(subjectVariable) = $0, let subject = atomToGoal[subjectVariable] {
          return subject
        }
        return $0
      })
    }
    let goalVariables = variables(goals)
    let nameClashes = variables(terms).intersection(goalVariables)
    let renamings = nameClashes.reduce([:], {
      $0.merging([$1: uniqueVariable(from: names.union(goalVariables.union($0.keys)))], uniquingKeysWith: { $1 })
    })
    let body = Body(terms: terms.map { atom in
        Atom(predicate: atom.predicate, subjects: atom.subjects.map {
          if case let .variable(subjectVariable) = $0, let variable = renamings[subjectVariable] {
            return .variable(variable)
          }
          return $0
        })
    })
    let goals = Set(goals.map { atom in
      Atom(predicate: atom.predicate, subjects: atom.subjects.map {
        if case let .variable(subjectVariable) = $0, let value = goalToAtom[subjectVariable] {
          return .value(value)
        }
        return $0
      })
    })
    if let substitution = search(kb: kb, goals: goals.union(body.terms), names: names.union(goalToAtom.keys)) {
      return goalToAtom.merging(substitution, uniquingKeysWith: { $1 })
    }
  }
  return nil
}

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
