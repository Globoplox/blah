// type: absance default to word, word, * default to *word
// cannot pass a complex type as parameter (must pass address) 
struct Person {
     age
     name: *
     friends: *Person; best_friend: Person
}

require "truc/pet.blah" // this extract only protoypes and types
// BE WARY OF recursive def

fun read_io(src: *, dst: *, limit) {
    var offset = 0x0
    var read = 0x0
    while (offset < max_size && (offset == 0x0 || read != 0xff00)) {
   	  *(src + offset) = *(dst + offset) // Here we need to handle a special case: affectation can be done to a var OR to a dereferencement (so its always 'somewhere').
    	  offset = offset + 0x1
    }
    //return offset
}

// When we do &something, something must be addressable. Something is addressable if: it's a var, or an access (which is sugar for &var + offset anyway).
// special case: &*something : in this case, compute 'something' as you should, but then instead of having it LW or SW, return it as is. or just dont do anything ?
// This allow to get the offset when doing &(a.c) - &a for example. 
