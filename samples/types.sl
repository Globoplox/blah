require "./race.sl"

struct Person {
  age
  name: *
  friends: *Person; best_friend: *Person
  pets: *Pet
}

struct Pet {
  name: *
  race: Race
  color: Color
}

struct Color { r;v;b }