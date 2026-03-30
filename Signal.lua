--[[
	how to use?

	local Signal = require(signal)
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
]]--

local Connection = require(game.ReplicatedStorage.rblx["@connection"])

export type Connection = Connection.Connection

export type Signal<T...> = {
	Connect: (self: Signal<T...>, cb: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, cb: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type ConnectionData<T...> = Connection & {
	_callback: (T...) -> (),
	_next: ConnectionData<T...>?,
	_prev: ConnectionData<T...>?,
	_once: boolean,
	_signal: SignalData<T...>?,
}

type SignalData<T...> = Signal<T...> & {
	_head: ConnectionData<T...>?,
	_tail: ConnectionData<T...>?,
	_destroyed: boolean,
}

local Signal = {}
Signal.__index = Signal

local function RemoveConnection<T...>(conn: ConnectionData<T...>)
	local signal, nextConn, prevConn

	signal = conn._signal
	if not signal then return end

	nextConn = conn._next
	prevConn = conn._prev

	if prevConn then
		prevConn._next = nextConn
	else
		signal._head = nextConn
	end

	if nextConn then
		nextConn._prev = prevConn
	else
		signal._tail = prevConn
	end

	conn._signal = nil
	conn._next = nil
	conn._prev = nil
end

local function NewConnection<T...>(signal: SignalData<T...>, cb: (T...) -> (), once: boolean): Connection
	local conn
	local tail

	conn = Connection.new(function()
		RemoveConnection(conn)
	end) :: ConnectionData<T...>
	conn._callback = cb
	conn._next = nil
	conn._prev = nil
	conn._once = once
	conn._signal = signal

	tail = signal._tail
	if tail then
		tail._next = conn
		conn._prev = tail
	else
		signal._head = conn
	end

	signal._tail = conn

	return conn
end

function Signal:Connect(cb)
	if self._destroyed then error("signal is destroyed") end
	assert(type(cb) == "function", "callback has to be a function")

	return NewConnection(self, cb, false)
end

function Signal:Once(cb)
	if self._destroyed then error("signal is destroyed") end
	assert(type(cb) == "function", "callback has to be a function")

	return NewConnection(self, cb, true)
end

function Signal:Wait()
	local thread
	local conn

	if self._destroyed then error("signal is destroyed") end

	thread = coroutine.running()
	assert(thread, "Wait has to run in a coroutine")

	conn = nil
	conn = NewConnection(self, function(...)
		if conn.Connected then
			conn:Disconnect()
		end

		-- resume on another task or roblox complains about yielding
		task.spawn(thread, ...)
	end, false)

	return coroutine.yield()
end

function Signal:Fire(...)
	local conn
	local nextConn

	if self._destroyed then return end

	conn = self._head
	while conn do
		nextConn = conn._next
		if conn.Connected then
			if conn._once then
				conn:Disconnect()
			end

			-- grab next first so callbacks can disconnect safely
			task.spawn(conn._callback, ...)
		end
		conn = nextConn
	end
end

function Signal:DisconnectAll()
	local conn
	local nextConn

	conn = self._head
	while conn do
		nextConn = conn._next
		conn.Connected = false
		conn._signal = nil
		conn._next = nil
		conn._prev = nil
		conn = nextConn
	end

	self._head = nil
	self._tail = nil
end

function Signal:Destroy()
	if self._destroyed then return end

	self._destroyed = true
	self:DisconnectAll()
end

local module = {}

function module.new<T...>(): Signal<T...>
	local self

	self = setmetatable({}, Signal) :: SignalData<T...>
	self._head = nil
	self._tail = nil
	self._destroyed = false

	return self
end

return module
