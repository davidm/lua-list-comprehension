#!/usr/bin/env lua

local comp = require 'comprehension' . new()
comp 'x^2 for x' {2,3} --> {2^2,3^2}
comp 'x^2 for _,x in ipairs(_1)' {2,3} --> {2^2,3^2}
comp 'x^2 for x=_1,_2' (2,3) --> {2^2,3^2}

comp 'sum(x^2 for x)' {2,3} --> 2^2+3^2
comp 'max(x*y for x for y if x<4 if y<6)' ({2,3,4}, {4,5,6}) --> 3*5
comp 'table(v,k for k,v in pairs(_1))' {[3]=5, [5]=7} --> {[5]=3, [7]=5}

