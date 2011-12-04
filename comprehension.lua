--[[
 comprehension.lua
 List comprehensions implemented in Lua.

 http://lua-users.org/wiki/ListComprehensions

SYNOPSIS
 
  local comp = require 'comprehension' . new()
  comp 'x^2 for x' {2,3} --> {2^2,3^2}
  comp 'x^2 for _,x in ipairs(_1)' {2,3} --> {2^2,3^2}
  comp 'x^2 for x=_1,_2' (2,3) --> {2^2,3^2}

  comp 'sum(x^2 for x)' {2,3} --> 2^2+3^2
  comp 'max(x*y for x for y if x<4 if y<6)' ({2,3,4}, {4,5,6}) --> 3*5
  comp 'table(v,k for k,v in pairs(_1))' {[3]=5, [5]=7} --> {[5]=3, [7]=5}
 
DESCRIPTION

  List comprehensions [1] provide concise syntax for building lists in
  mathematical set-builder notation. A number of programming languages
  (e.g. Haskell and Python) provide built-in support for list comprehensions.
  Lua does not; however, there are are ways to implement it in Lua.

  Unlike some other approaches, the following approach implements list
  comprehensions in pure Lua as a library (without patching or token filters).
  It uses a technique with dynamic code generation (`loadstring`) and caching
  somewhat analogous to ShortAnonymousFunctions.

  This library has been incorporated into [Penlight].
  
  ## Run-time behavior

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
  but that is done only on the first invocation due to caching/memoization).
  Also, no global variables are referenced.


DEPENDENCIES

  None (other than Lua 5.1 or 5.2).
  
HOME PAGE

  http://lua-users.org/wiki/ListComprehensions
  https://github.com/davidm/lua-list-comprehension

DOWNLOAD/INSTALL

  If using LuaRocks:
    luarocks install lua-list-comprehension

  Otherwise, download <https://github.com/davidm/lua-list-comprehension/zipball/master>.
  Alternately, if using git:
    git clone git://github.com/davidm/lua-list-comprehension.git
    cd lua-list-comprehension
  Optionally unpack and install in LuaRocks:
    ./util.mk
    cd tmp/* && luarocks make
  
POSSIBLE EXTENSIONS

  A simple extension would be to provide a more mathematical (or more
  Haskell-like) syntax:

    assert(comp 'sum { x^2 | x <- ?, x % 2 == 0 }' {2,3,4} == 2^2+4^2)
    A compelling extension, as recommended by Greg Fitzgerald, is to implement
    the generalized list comprehensions proposed by SPJ and Wadler [2].
    This provides some clear directions to take this to the next level, and
    the related work in Microsoft LINQ [3] shows what this could look like
    in practice.

  The "zip" extension to list comprehensions, using the Haskell-like notation in the paper

    [ (x,y,z,w) | (x <- xs | y <- ys), (z <- zs | w <- ws) ] ,
    would require only small changes. The corresponding Lua function to generate that would be like this:

    local __xs, __ys, __zs, __ws = ...
    local __ret = {}   -- i.e. $list_init
    for __i=1,__math_min(#__xs, #__ys) do
      local x, y = __xs[__i], __ys[__i]
      for __j=1,__math_min(#__zs, #__ws) do
        local z, w = __zs[__j], __ws[__j]
        __ret[#__ret+1] = {x,y,z,w}   -- i.e. $list_accum(__ret, x, y, z, w)
      end
    end
    return ret
    (The "$" notation here is a short-hand for compile-time macros that were used to expand the source.)

  Supporting sort or grouped by, e.g. again using notation in the paper

    [ the x.name, sum x.deposit | x <- transactions, group by x.name ] ,
    could be achieved by generating functions like this:

    local __transactions = ...
    local __groups1 = {}
    local __groups2 = {}
    for __i = 1, #__transactions do
      local x = __transactions[__i]
      local __key = ( x.name )  -- i.e. $group_by_key
      __groups1[__key] = ( x.name )
             -- i.e. $accum_the(__groups1[__key], $val1)
      __groups2[__key] = (__groups2[__key] or 0) + ( x.deposit )
             -- i.e. $accum_sum(__groups2[__key], $val2)
    end
    local __result = {}   -- i.e. $list_init
    for __key in __pairs(__groups1) do
      __result[__result+1] = {__groups1[__key], __groups2[__key]}
             -- i.e. $accum_list(__result, __v)
    end
    return __result
    Taking this to its full fruition seems quite achievable (after some
    research), though it would be a significant extension to this module
    (any takers?).
  
STATUS

  This module is new and likely still has some bugs.

RELATED WORK

  - LuaMacros http://lua-users.org/wiki/LuaMacros
    http://lua-users.org/lists/lua-l/2007-12/msg00014.html
  - MetaLua http://lua-users.org/wiki/MetaLua
    http://metalua.luaforge.net/metalua-manual.html#htoc52
    http://metalua.luaforge.net/src/lib/ext-syntax/clist.lua.html

REFERENCES

  [1] http://en.wikipedia.org/wiki/List_comprehension
  [2] http://research.microsoft.com/~simonpj/papers/list-comp/
  [3] http://en.wikipedia.org/wiki/Language_Integrated_Query
      
 (c) 2008-2011 David Manura. Licensed under the same terms as Lua (MIT license).
--]]

local comprehension = {_TYPE='module', _NAME='comprehension', _VERSION='0.1.20111203'}

local assert = assert
local loadstring = loadstring
local tonumber = tonumber
local math_max = math.max
local table_concat = table.concat
local getfenv = getfenv
local setfenv = setfenv
local ipairs = ipairs
local setmetatable = setmetatable

local lb = require "luabalanced"

-- fold operations
-- http://en.wikipedia.org/wiki/Fold_(higher-order_function)
local ops = {
  list = {init=' {} ', accum=' __result[#__result+1] = (%s) '},
  table = {init=' {} ', accum=' local __k, __v = %s __result[__k] = __v '},
  sum = {init=' 0 ', accum=' __result = __result + (%s) '},
  min = {init=' nil ', accum=' local __tmp = %s ' ..
                             ' if __result then if __tmp < __result then ' ..
                             '__result = __tmp end else __result = __tmp end '},
  max = {init=' nil ', accum=' local __tmp = %s ' ..
                             ' if __result then if __tmp > __result then ' ..
                             '__result = __tmp end else __result = __tmp end '},
}


-- Parses comprehension string <expr>.
-- Returns output expression list <out> string, array of for types
-- ('=', 'in' or nil) <fortypes>, array of input variable name
-- strings <invarlists>, array of input variable value strings
-- <invallists>, array of predicate expression strings <preds>,
-- operation name string <opname>, and number of placeholder
-- parameters <max_param>.
--
-- The is equivalent to the mathematical set-builder notation:
--
--   <opname> { <out> | <invarlist> in <invallist> , <preds> }
--
-- Examples:
--   "x^2 for x"                 -- array values
--   "x^2 for x=1,10,2"          -- numeric for
--   "k^v for k,v in pairs(_1)"  -- iterator for
--   "(x+y)^2 for x for y if x > y"  -- nested
--
local function parse_comprehension(expr)
  local t = {}
  local pos = 1

  -- extract opname (if exists)
  local opname
  local tok, post = expr:match('^%s*([%a_][%w_]*)%s*%(()', pos)
  local pose = #expr + 1
  if tok then
    local tok2, posb = lb.match_bracketed(expr, post-1)
    assert(tok2, 'syntax error')
    if expr:match('^%s*$', posb) then
      opname = tok
      pose = posb - 1
      pos = post
    end
  end
  opname = opname or "list"

  -- extract out expression list
  local out; out, pos = lb.match_explist(expr, pos)
  assert(out, "syntax error: missing expression list")
  out = table_concat(out, ', ')

  -- extract "for" clauses
  local fortypes = {}
  local invarlists = {}
  local invallists = {}
  while 1 do
    local post = expr:match('^%s*for%s+()', pos)
    if not post then break end
    pos = post

    -- extract input vars
    local iv; iv, pos = lb.match_namelist(expr, pos)
    assert(#iv > 0, 'syntax error: zero variables')
    for _,ident in ipairs(iv) do
      assert(not ident:match'^__',
             "identifier " .. ident .. " may not contain __ prefix")
    end
    invarlists[#invarlists+1] = iv

    -- extract '=' or 'in' (optional)
    local fortype, post = expr:match('^(=)%s*()', pos)
    if not fortype then fortype, post = expr:match('^(in)%s+()', pos) end
    if fortype then
      pos = post
      -- extract input value range
      local il; il, pos = lb.match_explist(expr, pos)
      assert(#il > 0, 'syntax error: zero expressions')
      assert(fortype ~= '=' or #il == 2 or #il == 3,
             'syntax error: numeric for requires 2 or three expressions')
      fortypes[#invarlists] = fortype
      invallists[#invarlists] = il
    else
      fortypes[#invarlists] = false
      invallists[#invarlists] = false
    end
  end
  assert(#invarlists > 0, 'syntax error: missing "for" clause')

  -- extract "if" clauses
  local preds = {}
  while 1 do
    local post = expr:match('^%s*if%s+()', pos)
    if not post then break end
    pos = post
    local pred; pred, pos = lb.match_expression(expr, pos)
    assert(pred, 'syntax error: predicated expression not found')
    preds[#preds+1] = pred
  end

  -- extract number of parameter variables (name matching "_%d+")
  local stmp = ''; lb.gsub(expr, function(u, sin)  -- strip comments/strings
    if u == 'e' then stmp = stmp .. ' ' .. sin .. ' ' end
  end)
  local max_param = 0; stmp:gsub('[%a_][%w_]*', function(s)
    local s = s:match('^_(%d+)$')
    if s then max_param = math_max(max_param, tonumber(s)) end
  end)

  if pos ~= pose then
    assert(false, "syntax error: unrecognized " .. expr:sub(pos))
  end

  --DEBUG:
  --print('----\n', string.format("%q", expr), string.format("%q", out), opname)
  --for k,v in ipairs(invarlists) do print(k,v, invallists[k]) end
  --for k,v in ipairs(preds) do print(k,v) end

  return out, fortypes, invarlists, invallists, preds, opname, max_param
end


-- Create Lua code string representing comprehension.
-- Arguments are in the form returned by parse_comprehension.
local function code_comprehension(
    out, fortypes, invarlists, invallists, preds, opname, max_param
)
  local op = assert(ops[opname])
  local code = op.accum:gsub('%%s',  out)

  for i=#preds,1,-1 do local pred = preds[i]
    code = ' if ' .. pred .. ' then ' .. code .. ' end '
  end  
  for i=#invarlists,1,-1 do
    if not fortypes[i] then
      local arrayname = '__in' .. i
      local idx = '__idx' .. i
      code =
        ' for ' .. idx .. ' = 1, #' .. arrayname .. ' do ' ..
        ' local ' .. invarlists[i][1] .. ' = ' .. arrayname .. '['..idx..'] ' ..
        code .. ' end '
    else
      code =
        ' for ' ..
        table_concat(invarlists[i], ', ') ..
        ' ' .. fortypes[i] .. ' ' ..
        table_concat(invallists[i], ', ') ..
        ' do ' .. code .. ' end '      
    end
  end
  code = ' local __result = ( ' .. op.init .. ' ) ' .. code
  return code
end


-- Convert code string represented by code_comprehension
-- into Lua function.  Also must pass ninputs = #invarlists,
-- max_param, and invallists (from parse_comprehension).
-- Uses environment env.
local function wrap_comprehension(code, ninputs, max_param, invallists, env)
  assert(ninputs > 0)
  local ts = {}
  for i=1,max_param do
    ts[#ts+1] = '_' .. i
  end
  for i=1,ninputs do
    if not invallists[i] then
      local name = '__in' .. i
      ts[#ts+1] = name
    end
  end
  if #ts > 0 then
    code = ' local ' .. table_concat(ts, ', ') .. ' = ... ' .. code
  end
  code = code .. ' return __result '
  --print('DEBUG:', code)
  local f, err = loadstring(code)
  if not f then assert(false, err .. ' with generated code ' .. code) end
  setfenv(f, env)
  return f
end


-- Build Lua function from comprehension string.
-- Uses environment env.
local function build_comprehension(expr, env)
  local out, fortypes, invarlists, invallists, preds, opname, max_param
    = parse_comprehension(expr)
  local code = code_comprehension(
    out, fortypes, invarlists, invallists, preds, opname, max_param)
  local f = wrap_comprehension(code, #invarlists, max_param, invallists, env)
  return f
end


-- Creates new comprehension cache.
-- Any list comprehension function created are set to the environment
-- env (defaults to caller of new).
local function new(env)
  -- Note: using a single global comprehension cache would have had
  -- security implications (e.g. retrieving cached functions created
  -- in other environments).
  -- The cache lookup function could have instead been written to retrieve
  -- the caller's environment, lookup up the cache private to that
  -- environment, and then looked up the function in that cache.
  -- That would avoid the need for this <new> call to
  -- explicitly manage caches; however, that might also have an undue
  -- performance penalty.

  env = env or getfenv(2)

  local mt = {}
  local cache = setmetatable({}, mt)

  -- Index operator builds, caches, and returns Lua function
  -- corresponding to comprehension expression string.
  --
  -- Example: f = comprehension['x^2 for x']
  --
  function mt:__index(expr)
    local f = build_comprehension(expr, env)
    self[expr] = f  -- cache
    return f
  end

  -- Convenience syntax.
  -- Allows comprehension 'x^2 for x' instead of comprehension['x^2 for x'].
  function mt:__call(expr) return self[expr] end

  cache.new = new

  return cache
end


comprehension.new = new


return comprehension
