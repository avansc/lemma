
require '../interface/Seq'
require '../interface/Reversible'

do

local function __tostring(e)
	local str = {}
	
	for k, v in pairs(e) do
		if k ~= '_length' then
			table.insert(str, tostring(k))
			table.insert(str, ' ')
			table.insert(str, tostring(v))
			table.insert(str, ', ')
		end
	end
	
	table.remove(str)
	return '{'..table.concat(str)..'}'
end

local t = {}
local mt = {
	class = 'HashMap',
	implements = { 'Seq' },
	__index = t,
	__tostring = __tostring
}

function t:cons(...)
	local new = HashMap()
	local args = {...}
	
	for k, v in pairs(self) do
		new[k] = v
	end
	
	for i = 1, #args, 2 do
		new[args[i]] = args[i+1]
	end
	
	new['_length'] = self:length() + #args / 2
	return new
end

function t:length()
	return self['_length'] or 0
end

function t:first()
	for k, v in pairs(self) do
		if k ~= '_length' then
			return Vector(k, v)
		end
	end
end

function t:rest()
	local new = HashMap()
	local skip = false
	
	for k, v in pairs(self) do
		if skip then
			new[k] = v
		elseif k ~= '_length' then
			skip = true
		end
	end
	
	new['_length'] = self:length() - 2
	
	return new
end

t['empty?'] = function(self)
	return (self:length() == 0)
end

function HashMap(...)
	local args = {...}
	local o = {}
	
	o._length = 0
	
	for i = 1, #args, 2 do
		o[args[i]] = args[i+1]
		o._length = o._length + 1
	end
	
	setmetatable(o, mt)
	return o
end

function t:seq()
	local o = {}
	setmetatable(o, mt)
	return o
end

end
