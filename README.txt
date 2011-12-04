== Description ==

List comprehensions [1] provide concise syntax for building lists in
mathematical set-builder notation. A number of programming languages
(e.g. Haskell and Python) provide built-in support for list
comprehensions. Lua does not; however, there are are ways to implement
it in Lua.

Unlike some other approaches, the following approach implements list
comprehensions in pure Lua as a library (without patching or token
filters). It uses a trick with dynamic code generation (loadstring)
and caching somewhat analogous to ShortAnonymousFunctions [2].

This library has been incorporated into Penlight [4]. 

== Project Page ==

http://lua-users.org/wiki/ListComprehensions

== Examples ==

  local comp = require 'comprehension' . new()
  comp 'x^2 for x' {2,3} --> {2^2,3^2}
  comp 'x^2 for _,x in ipairs(_1)' {2,3} --> {2^2,3^2}
  comp 'x^2 for x=_1,_2' (2,3) --> {2^2,3^2}

  comp 'sum(x^2 for x)' {2,3} --> 2^2+3^2
  comp 'max(x*y for x for y if x<4 if y<6)' ({2,3,4}, {4,5,6}) --> 3*5
  comp 'table(v,k for k,v in pairs(_1))' {[3]=5, [5]=7} --> {[5]=3, [7]=5}

== Run-Time Behavior ==

To illustrate the run-time characteristics, consider the following code:

  comp 'sum(x^2 for x if x % 2 == 0)'

That gets code generated to this Lua function:

  local __in1 = ...
  local __result = (  0  )
  for __idx1 = 1, #__in1 do
    local x = __in1[__idx1]
    if x % 2 == 0 then
      __result = __result + ( __x^2 )
    end
  end
  return __result

Note that no intermediate lists are built. The code efficiently avoids
memory allocations (apart from the allocation of the function itself,
but that is done only on the first invocation due to
caching/memoization). Also, no global variables are referenced.

== Dependencies ==

This module depends on LuaBalanced [4].

== Author ==

(c) 2008 David Manura. Licensed under the same terms as Lua (MIT license).

== References ==

[1] http://en.wikipedia.org/wiki/List_comprehension
[2] http://lua-users.org/wiki/ShortAnonymousFunctions
[3] http://penlight.luaforge.net/
[4] http://lua-users.org/wiki/LuaBalanced
