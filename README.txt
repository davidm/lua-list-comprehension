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

== Author ==

(c) 2008 David Manura. Licensed under the same terms as Lua (MIT license).

== References ==

[1] http://en.wikipedia.org/wiki/List_comprehension
[2] http://lua-users.org/wiki/ShortAnonymousFunctions
[3] http://penlight.luaforge.net/