--[[
	Notifications (Server):
		Server-side entry point. Mirrors the client's Show() shape but takes a player (or list of
		players) and fires the shared remote instead of touching any UI directly.
]]

export type NotificationOptions = {
	message: string,
	duration: number?,
	color: Color3?,
}

return function(remote: RemoteEvent)
	local Notifications = {}

	function Notifications.Show(player: Player, options: NotificationOptions)
		remote:FireClient(player, options)
	end

	function Notifications.ShowAll(options: NotificationOptions)
		remote:FireAllClients(options)
	end

	function Notifications.ShowMany(players: { Player }, options: NotificationOptions)
		for _, targetPlayer in players do
			remote:FireClient(targetPlayer, options)
		end
	end

	function Notifications.ClearAll(player: Player)
		remote:FireClient(player, { clear = true })
	end

	function Notifications.ClearAllForAll()
		remote:FireAllClients({ clear = true })
	end

	function Notifications.ClearAllForMany(players: { Player })
		for _, targetPlayer in players do
			remote:FireClient(targetPlayer, { clear = true })
		end
	end

	return Notifications
end