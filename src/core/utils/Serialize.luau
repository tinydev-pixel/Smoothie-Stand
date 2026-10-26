--!strict
--[[
	Serialize
	Converts Vector3 and CFrame values to plain tables of numbers (safe for
	DataStores / JSON / attributes) and back again.

	Formats:
		Vector3 -> { x, y, z }
		CFrame  -> { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }

	Usage:
		local Serialize = require(path.to.Serialize)

		local data = Serialize.SerializeVector3(part.Position)
		local pos  = Serialize.UnserializeVector3(data)

		local cf  = Serialize.SerializeCFrame(part.CFrame)
		part.CFrame = Serialize.UnserializeCFrame(cf)

		-- Whole tables (Vector3s / CFrames anywhere inside get converted):
		local saved  = Serialize.SerializeTable({ Spawn = part.CFrame, Items = { part.Position } })
		local loaded = Serialize.UnserializeTable(saved)
]]

local Serialize = {}

export type SerializedVector3 = { number }
export type SerializedCFrame = { number }

local function isNumberArray(value: any, length: number): boolean
	if type(value) ~= "table" then
		return false
	end
	for i = 1, length do
		if type(value[i]) ~= "number" then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------
-- Vector3
----------------------------------------------------------------------

function Serialize.SerializeVector3(vector: Vector3): SerializedVector3
	assert(typeof(vector) == "Vector3", "SerializeVector3 expected a Vector3")
	return { vector.X, vector.Y, vector.Z }
end

function Serialize.UnserializeVector3(data: SerializedVector3): Vector3
	assert(isNumberArray(data, 3), "UnserializeVector3 expected a table of 3 numbers")
	return Vector3.new(data[1], data[2], data[3])
end

----------------------------------------------------------------------
-- CFrame
----------------------------------------------------------------------

function Serialize.SerializeCFrame(cframe: CFrame): SerializedCFrame
	assert(typeof(cframe) == "CFrame", "SerializeCFrame expected a CFrame")
	return { cframe:GetComponents() }
end

function Serialize.UnserializeCFrame(data: SerializedCFrame): CFrame
	assert(isNumberArray(data, 12), "UnserializeCFrame expected a table of 12 numbers")
	return CFrame.new(table.unpack(data, 1, 12))
end

----------------------------------------------------------------------
-- Whole-table helpers
-- Vector3 / CFrame values are replaced with { Type = "...", Data = {...} }
-- so they can be told apart when loading. Everything else is copied as-is.
----------------------------------------------------------------------

function Serialize.SerializeTable(value: any): any
	local valueType = typeof(value)

	if valueType == "Vector3" then
		return { Type = "Vector3", Data = Serialize.SerializeVector3(value) }
	elseif valueType == "CFrame" then
		return { Type = "CFrame", Data = Serialize.SerializeCFrame(value) }
	elseif valueType == "table" then
		local result = {}
		for key, inner in pairs(value) do
			result[key] = Serialize.SerializeTable(inner)
		end
		return result
	end

	return value
end

function Serialize.UnserializeTable(value: any): any
	if type(value) ~= "table" then
		return value
	end

	if value.Type == "Vector3" and type(value.Data) == "table" then
		return Serialize.UnserializeVector3(value.Data)
	elseif value.Type == "CFrame" and type(value.Data) == "table" then
		return Serialize.UnserializeCFrame(value.Data)
	end

	local result = {}
	for key, inner in pairs(value) do
		result[key] = Serialize.UnserializeTable(inner)
	end
	return result
end

return Serialize