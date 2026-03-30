 local Signal = require(game.ReplicatedStorage.rblx["@signal"])
local sig = Signal.new()


  local conn = sig:Connect(function(msg)
        print(msg)
  end)

  sig:Fire("hi")
  conn:Disconnect()



  sig:Once(function(msg)
        print(msg)
  end)

  sig:Fire("first")
  sig:Fire("second") 
