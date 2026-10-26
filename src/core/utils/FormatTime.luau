return function(time: number): string
	local hours = math.floor(time / 3600)
	local minutes = math.floor((time % 3600) / 60)
	local seconds = math.floor(time % 60)

	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, seconds)
	end

	return string.format("%02d:%02d", minutes, seconds)
end