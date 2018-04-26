struct Exception: Error {
  let description: String
}

let indent = "  "

protocol Lines {
  var lines: [String] { get }
}

extension CustomStringConvertible where Self: Lines {
  var description: String { return lines.joined(separator: "\n") }
}

extension Array: Lines where Element: Lines {
  var lines: [String] {
    return map { $0.lines.map { indent + $0 } }.joined(separator: [","]).map { $0 }
  }
}

extension Subject: Lines, CustomStringConvertible {
  var lines: [String] {
    switch self {
    case .value(let value):
      return value.atom.lines
    case .variable(let variable):
      return ["Variable: \(variable.name)"]
    }
  }
}

extension Atom: Lines, CustomStringConvertible {
  var lines: [String] {
    if subjects.count == 0 {
      return ["Atom: \(predicate)"]
    }
    return ["Atom: \(predicate)("] + subjects.lines.map { indent + $0 } + [")"]
  }
}

extension Body: Lines, CustomStringConvertible {
  var lines: [String] {
    return ["Body"] + terms.flatMap { $0.lines }.map { indent + $0 }
  }
}

extension Sentence: Lines, CustomStringConvertible {
  var lines: [String] {
    return ["Sentence"] + ["head: \(head)", "body: \(String(describing: body))"].map { indent + $0 }
  }
}

extension KnowledgeBase: Lines, CustomStringConvertible {
  var lines: [String] {
    return ["Program"] + sentences.flatMap { $0.lines }.map { indent + $0 }
  }
}

extension Query: Lines, CustomStringConvertible {
  var lines: [String] {
    return ["Query"] + terms.flatMap { $0.lines }.map { indent + $0 }
  }
}


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
  var atomToGoal: [Variable: Subject] = [:]
  var goalToAtom: [Variable: Value] = [:]
  for (atomSubject, goalSubject) in zip(atom.subjects, goal.subjects) {
    if case let .value(atomSubjectValue) = atomSubject, case let .value(goalSubjectValue) = goalSubject {
      guard atomSubjectValue.atom == goalSubjectValue.atom else {
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
//  print(goals)
  if goals.isEmpty {
    return [:]
  }

  guard let goal = selectGoal(fromGoals: goals) else {
    return nil
  }
  let goals = goals.subtracting([goal])

  for sentence in kb.sentences.filter({ $0.head == goal }) {
    guard let (atomToGoal, goalToAtom) = unify(sentence.head, with: goal) else {
      return nil
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
//    print(body)
//    print(body.terms)
//    print("KK\(goals.union(body.terms))")
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
