require "./types.sl"
require "./globals.sl" // just to check if it go boom
require "../src/stacklang/stdlib/stacklang_startup_prototypes.sl"

var jack : Person
var bean : Pet

var space

fun main:_ {
   //var toto : Person
   //var tata : Person

   //toto.age = 5
   //*(&toto + sizeof(Person)) = toto

   return ~0x1111
    
   //  //return 0x9
   //  //var ptr :* = &error_code_success
   //  //*ptr = 0xb
   //  //return error_code_success
    
   //  // glob_color.r = 0x0
   //  // glob_color.g = 0xff
   //  // glob_color.b = 0x0

   
   // //*0x0 = 0xf0f0
   // //*null_ptr = 0xf0f0
   
   // //return 0x0	
   // var major_person: Person
   //  //var a = 0x5
   //  //var b
   //  //var c

   //  // this will effectively crash compiler when using a lock for register holding address of lvalue during assignment
   //  //jack = jack = jack = jack = jack = jack = jack = jack
   //  // we are out of register.

   //  major_person.age = 18

   //  jack = major_person

   //  // This is a write a address 0 but lets see in debugger if it behave as it should
   //  // write into dereferenecment
   //  *(jack.friends) = jack

   //  // some fuckery:
   //  *null_ptr = 0xf0f0
   //  // same as but only if implict cast to ptr allowed: *0x0 = 0xf0f0
    
   //  // We take the non initialized (== 0) ptr to friend and we write jack on it.
   //  //once done, we should see jack age (so 18) in ram at address 1 (offset of field age to beginning of struct Person is 1)

   //  // write into access, read of external interop global
   //  //major_person.age = error_code_success
   //  // multiple assignment
   //  //a = b = c = major_person.age

   //     // return
   //  //return b
   //  return error_code_success
    
   //  // It works IF: stack as a 0x12 in offset 1
   //  // Absolute addresse 0x0001 containt a 0x12 too
   //  // main return the value of error_code_success (0xC)
}