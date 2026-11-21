--[[

Helper Utils

--]]

function getRandomPointInBand(originX, originY, minRadius, maxRadius)
    angle = math.random() * math.pi * 2;
    radius =(math.sqrt(math.random()) * (maxRadius-minRadius)) + minRadius;
    x = radius * math.cos(angle);
    y = radius * math.sin(angle);
    return {x=x+originX,y=y+originY};
end

function getAngleFacing(x, y, targetX, targetY)
	angle = math.atan2(targetX - x, targetY - y);	
	return angle;
end

function getDistanceBetweenActors(actor1, actor2)
	-- GetPos() returns x, y, z, rotation, zone as separate values.
	local x1, y1, z1 = actor1:GetPos();
	local x2, y2, z2 = actor2:GetPos();

	local dx = x1 - x2;
	local dy = y1 - y2;
	local dz = z1 - z2;
	
	return math.sqrt(dx * dx + dy * dy + dz *dz);
end

function getXZDistanceBetweenActors(actor1, actor2)
	local x1, _, z1 = actor1:GetPos();
	local x2, _, z2 = actor2:GetPos();

	local dx = x1 - x2;
	local dz = z1 - z2;

	return math.sqrt(dx * dx + dz *dz);
end

function math.Clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val))
end