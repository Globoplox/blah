require "./race.sl"

struct Person {
  space
  age
  name: *
  friends: *Person; best_friend: *Person
}

struct Pet {
  name: *
  race: Race
}
