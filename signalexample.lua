	local Signal = require(signalmodule)
	local sig = Signal.new()

	local conn = sig:Connect(function(...)
		print(...)
	end)

	sig:Fire("hi")
	conn:Disconnect()

	sig:Once(function(msg)
		print(msg)
	end)

	task.spawn(function()
		local msg = sig:Wait()
		print(msg)
	end)

	sig:DisconnectAll()
	sig:Destroy()
