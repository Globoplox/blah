require "./types.sl"
require "./globals.sl" // just to check if it go boom

require "../src/stacklang/stdlib/stacklang_startup_prototypes.sl"

var jack : Person
var bean : Pet

fun main(i_can_take_param):_ {
    var major_person: Person
    var a
    var b
    var c
    
    major_person.age = 18

    jack = major_person

    // This is a write a address 0 but lets see in debugger if it behave as it should
    *(jack.friends) = jack

    // We take the non initialized (== 0) ptr to friend and we write jack on it.
    //once done, we should see jack age (so 18) in ram at address 1 (offset of field age to beginning of struct Person is 1)

    // = is right associative 
    a = b = c = error_code_success
    return a
}