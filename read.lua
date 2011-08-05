---
-- The Lemma Reader
---

require 'type'
require 'env'
require 'class/List'
require 'class/Vector'
require 'class/PreHashMap'
require 'class/Symbol'


tostring, print = (function()
	local xtostring = tostring
	return function(s)
		if type(s) == 'string' then
			return string.format('%q', s)
		elseif s == false then
			return "false"
		end
	
		return xtostring(s)
	end,
	function(...)
		local args = {...}
		
		for i, v in ipairs(args) do
			args[i] = xtostring(v)
		end
		
		io.write(table.concat(args, '\t'))
		io.write'\n'
	end
end)()

---
-- Write an external representation of t to stdout
---
function write(...)
	local args = {...}
	
	if #args > 0 then
		for i, t in ipairs(args) do
			io.write(tostring(t))
			io.write(' ')
		end
	else
		io.write('nil')
	end
	io.write('\n')
end

local symbol =			 -- this is perhaps a little too permissive
[[([%a%-%?%*%+%%%$%^<>/\\_=:&!][%.%a%d%-%?%*%+%%%$%^<>/\\_=:&|!~@']*)]]

function symbol_patterns()
	return {
		full = symbol,
		table = [[([%a%-%?%*%+%%%$%^<>/\\_=:&!][%a%d%-%?%*%+%%%$%^<>/\\_=:&|!~@']*)]],
		ns = [[([%a%-%?%*%+%%%$%^<>/\\_=:&!][%.%a%d%-%?%*%+%%%$%^<>\\_=:&|!~@']*)]]
	}
end

local function tovalue(x)
	local t = {['true'] = true, ['false'] = false}
	return t[x]
end

-- these are tried in order (make them specific!)
local atoms = {
	'^([%+%-]?%d+%.?%d+)',		tonumber,	-- with decimal point
	'^([%+%-]?%d+)',			tonumber,	-- without decimal point
	'^(true)',					tovalue,
	'^(false)',					tovalue,
	'^(nil)',					tovalue,
	'^'..symbol,				Symbol
}

local number = {}
for i = 0, 9 do
	number[i] = true
end

local whitespace = {
	[' '] = true,
	['\t'] = true,
	['\n'] = true,
	[','] = true
}

local delim = {
	['('] = true,
	[')'] = true,
	['['] = true,
	[']'] = true,
	['{'] = true,
	['}'] = true
}

-- TODO: would probably be beneficial to make this tail-recursive
local function read_seq(eos, func)
	return function(f)
		local list = {}
		
		while true do
			local c = f:get()
			if not c then return 'eof' end
			
			while whitespace[c] do
				c = f:get()
				if not c then return 'eof' end
			end
			
			if c == eos then
				return func(unpack(list))
			else
				f:unget(c)
				local form = read(f)
				if form == 'eof' then return 'eof' end
				table.insert(list, form)
			end
		end
	end
end

local function read_delimed(delim, constr)
	return function(f)
		local str = {}
		local escape = false
		
		while true do
			local c = f:get()
			if not c then return 'eof' end
			
			if c == delim and not escape then
				local str = table.concat(str)
				
				if constr then
					return constr(str)
				else
					return str
				end
			elseif c == 'n' and escape then
				c = '\n'
				escape = false
			elseif c == '\\' then
				if not escape then
					escape = true
				else
					c = '\\'
					escape = false
				end
			else
				escape = false
			end
			
			if not escape then
				table.insert(str, c)
			end
		end
	end
end

local function read_keyword(f)
	local str = {}
	while true do
		local c = f:get()
		if not c then return 'eof' end
		
		if delim[c] or whitespace[c] then
			f:unget(c)
			return table.concat(str)
		end
		
		table.insert(str, c)
	end
end

local function read_comment(f)
	local c
	repeat
		c = f:get()
		if not c then return 'eof' end
	until c == '\n'
	return nil
end

local function read_multicomment(f)
	local last, c
	
	while true do
		last = c
		c = f:get()
		if not c then return 'eof' end
		
		if last == '#' and c == '|' then
			read_multicomment(f)
		elseif last == '|' and c == '#' then
			return nil
		end
	end
end

local function read_datumcomment(f)
	read(f)
	return nil
end

local function read_quote(sym)
	return function(f)
		local q = List()
		return q:cons(read(f)):cons(Symbol(sym))
	end
end

local function table_idx(func)
	return function(f)
		local k = read(f):string()
		local t = read(f)
		return List():cons(k):cons(t):cons(Symbol(func))
	end
end


local reader_macros = {
	['(']    = read_seq(')', List),
	['[']    = read_seq(']', Vector),
	['{']    = read_seq('}', PreHashMap),
	['"']    = read_delimed('"'),
	['|']    = read_delimed('|', Symbol),
	['.']    = table_idx('method'),
	[':']    = read_keyword,
	["'"]    = read_quote('quote'),
	['`']    = read_quote('quasiquote'),
	['~']    = read_quote('unquote'),
	['@']    = read_quote('splice'),
	[';']    = read_comment,
	['#']    = {
		['|'] = read_multicomment,
		[';'] = read_datumcomment,
	}
}


---
-- Read the next form from stream f
---
function read(f)
	local form = nil
	
	---
	-- If it's not whitespace, and it's not a reader macro, then
	-- it's either a symbol or number.
	---
	
	local c = f:get()
	if not c then return 'eof' end
	
	while whitespace[c] do
		c = f:get()
		if not c then return 'eof' end
	end
	
	local macro = reader_macros[c]
	while type(macro) == 'table' do
		c = f:get()
		if c == 'eof' then return 'eof' end
		macro = macro[c]
	end
	
	if type(macro) == 'function' then
		form = macro(f)
	else
		local str = {}
		while not delim[c] and not whitespace[c] do
			table.insert(str, c)
			c = f:get()
			if not c then return 'eof' end
		end
		
		f:unget(c)
		str = table.concat(str)
		
		-- Do a pattern match on str to identify type of atom
		-- if no matches, lexical error
		for i = 1, #atoms, 2 do
			if string.find(str, atoms[i]) then
				 form = atoms[i+1](str)
				 return form
			end
		end
		
		if not form then
			return nil, 'lexical error on token: '..f:get()..str
		end
	end
	
	return form
end
