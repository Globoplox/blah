Brainstorming here. Meant for myself.

Transform the TACs into a graph
(
   graph root elements are: Store, Call, Return, 
   (and load marked as for wasting IO (
      idea: A specific type for IO, behave like word, but allow to propagate a marker for load ?
   )))
(TODO: how to handle blocks/goto)

Each node represent a TAC (And so the Anonymous representing it's output if any)
Each edge represent that this node output is dependent on other node output

Each node can declare itself as Constant:
- A  Reference node is always constant
- An Add or Nand node is constant if its dependecies are constant
- A node that is affected several time CANNOT be constant.
  (happen if we generate code that reuse a temporary , such as an inlined loop for moving large memory areas)

Each node can declare itself as Aliased:
- Reference node is Aliased if it hold a Global
- Reference node is Aliased if it hold a Local and that local is Aliased
  (a local is considered aliased if it address is read manually)
- Reference node is Aliased if it is a parameter (it could be a pointer)
- Call node is aliased (return value could be a pointer)
- Immediate is never aliased
- Add and Nand are aliased if they depend on any node that is aliased
Unless it is constant, an aliased node cannot be replaced by an equivalent node
  because it is not constant AND its value can change at any time.

Then those optimizations can be run, looping until nothing happen anymore:

When several nodes are similar (different output name but same righthand expression) and
  the node is constant (if one is, they should all be)
  then all the nodes but one can be removed and all the outputs of removed nodes
  are replaced with the output of the node that is kept (the first to be assigned).
  => allow reuse of cache => is that really usefull anyway? => address dont really need to be cahed;
   constexpr are pre-optimized.

An Add node can flatten it's dependencies deeply as long as thay are also Add node, and
 all children that are Immediate can be merged into one Immediate child.
 => pre optimize

An Add node whose children are a Immediate and a Reference node can be merged into a Reference node
=> pre optimize

A Load node dependent on a Store node storing into an unaliased can replaced by the value stored:
*t1 = t0
t2 = *t1
t3 = t2 + t2
If t1 is unaliased, it can be rewrote:
t3 = t0 + t0
=> Yeah ok

An node that has no other node dependent on it, (unless its a aliased Store node or other side effect node), can be removed. 
(TODO: need a way to also flag a Load node to be kept (when we want to read an IO but do not care about the value read)).
This handle trimming node orphaned by other optimizations

DRAFT, branch selection:
For Add and Nand, choose the order (right, left) to codegen:
- Right then Left IF the left branch is shorter than right branch AND they have no common aliased node
- else left then right, which is the logical intuitive order.

Look into this case:
a = [1, 10]
b = &a
c = (a = a + 1) + *b
The order of the evaluation of the parameters impact the result of the operation (+) which is supposed to be commutative.

Same for Load an Store: the into address is loaded first, then the value
unless the value branch is shorter and they don't conflict.

------ 
Once nothing optimize anymore:

Constant immediate nodes whose value fit in a small risc immediate are replaced by the immediate itself


------

Codegeneration:
Each anonymous can be stored into a register/a register can store an anonymous.
Take the roots of the graphs, in order, and generate the node recursively depth first.


When generating code for a TAC:
- Take all the anonymous (or Literal / Local / Global in some case) it needs
- If they are in a register, keep the register
- If they are not, grab a free register and load them into it.
  - If no register are free
    - Take the register holding the temporary that will be used in the most time
    - Store the temporary on stack
    - Set the regitser as free and use it 
- Compile the TAC (load and store may be NO-OP)
- For each anonymous that had been loaded:
  - If they are not live anymore (that was there last usage ever), unload the register
  - if they are aliased: unload the register
  - In other case, keep the value. It may be reused later, or spilled

--------------------

Handling Jump, Goto:

Before a Call:
  spill temporaries / free register, no question.

About call/push:
if pushing is a code in itself, it mean the stack size (and so temporaries) should be fixed for the duration of the function <= unless TAC always generate the push just before the call.
if call include its parameters it does only requiere the current stack size. 

If and while:
  At the label of the beginning of the computation of the condition:
    - Store the state of the temporaries: which register hold which temporary
  When jumping to a label:
    - Spill all variable that were not spilled at the beginning og the label
    - Load all variables that were cached at the beginning of the label

BTW: 
assigning literal 0 to a CONSTANT temporary will noop and assign r0 to the tmeporary

A non initialized local is considred to be stored in r0.




Most important optimization would be reusing common subexpressio, but this requires to detect that there have been no write to dependable stuff, which is hard.