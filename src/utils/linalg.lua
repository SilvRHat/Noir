-- noirv~

-- Math Utility Functions

local LINALG= {}


function LINALG.lineToPlaneIntersection(linePoint, lineDirection, planePoint, planeNormal)
	local denominator = lineDirection:Dot(planeNormal)
	if denominator == 0 then
		return linePoint
	end
	local distance = ((planePoint - linePoint):Dot(planeNormal)) / denominator
	return linePoint + lineDirection * distance
end




return LINALG