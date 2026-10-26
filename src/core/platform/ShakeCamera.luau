local RunService = game:GetService("RunService")

return function(camera: Camera, duration: number?, intensity: number?)
	duration = duration or 0.5
	intensity = intensity or 0.5

	local startTime = os.clock()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = elapsed / duration

		if alpha >= 1 then
			connection:Disconnect()
			return
		end

		local strength = intensity * (1 - alpha)

		local x = math.noise(elapsed * 15, 0, 0) * strength
		local y = math.noise(0, elapsed * 15, 0) * strength
		local z = math.noise(0, 0, elapsed * 15) * strength

		camera.CFrame *= CFrame.Angles(
			math.rad(x),
			math.rad(y),
			math.rad(z)
		)
	end)
end