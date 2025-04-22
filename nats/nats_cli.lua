local socket = require("socket")
local Hooks = require("nats.hooks")

local NATS = {}
NATS.__index = NATS

function NATS.new(host, opts, port)
    opts = opts or {}
    local self = {}
    self.host = host or "127.0.0.1"
    self.port = port or 4222
    self.debug = opts.debug or false
    self.verbose = opts.verbose or false
    self.sub_id = 0
    self.subscriptions = {}
    self.connected = false
    self.hooks = Hooks.new()
    return setmetatable(self, { __index = NATS })
end

function NATS:connect()
    self.conn = socket.tcp()
    self.conn:settimeout(1)
    assert(self.conn:connect(self.host, self.port), "connection failed")
    local info = self.conn:receive("*l")
    if self.verbose then print("INFO:", info) end
    self.conn:send(string.format('CONNECT {"verbose":%s}\r\n', self.verbose and "true" or "false"))
    if self.verbose then 
        local OK = self.conn:receive("*l")
        print("INFO:", OK)
    end
    self.connected = true
    return true
end

function NATS:publish(subject, message)
    if not self.connected then
        error("Cannot publish before connecting to NATS server")
    end
    local msg = string.format("PUB %s %d\r\n%s\r\n", subject, #message, message)
    self.conn:send(msg)
end

function NATS:subscribe(subject, callback)
    if not self.connected then
        error("Cannot subscribe before connecting to NATS server")
    end
    self.sub_id = self.sub_id + 1
    local sid = tostring(self.sub_id)
    self.conn:send(string.format("SUB %s %s\r\n", subject, sid))
    self.subscriptions[sid] = callback
    return sid
end

function NATS:read_loop()
    self.read_loop_run = true
    while self.read_loop_run do
        self:poll(0.1)
        socket.sleep(0.01)
    end
end

function NATS:poll(timeout)
    self.conn:settimeout(timeout or 0)
    local line, err = self.conn:receive("*l")
    if not line then return end

    if self.debug then
        print("[DEBUG] Received line:", line)
    end

    if line:sub(1, 4) == "PING" then
        if self.debug then 
            print("[DEBUG] Recived PING, sending PONG") 
        end
        self.conn:send("PONG\r\n")
        if self.hooks then
            self.hooks:call("ping")
        end

    elseif line:sub(1, 4) == "-ERR" then
        print("NATS ERROR:", line)
        if self.hooks then
            self.hooks:call("ERR", line)
        end

    elseif line:sub(1, 4) == "INFO" and self.debug then
        if self.debug then print("[DEBUG] OK:", line) end
        if self.hooks and self.hooks:call("ok", line) then self.hooks:call("ok", line) end
        
    elseif line:sub(1, 3) == "+OK" then

    elseif line:match("^MSG") then
        local subject, sid, size = string.match(line, "^MSG%s+(%S+)%s+(%S+)%s+(%d+)")
        local payload = self.conn:receive(tonumber(size))
        self.conn:receive(2)
        local callback = self.subscriptions[sid]
        if callback then callback(subject, payload) end
    end

end

function NATS:set_hook(event, funct)
    self.hooks:set(event, funct)
end

function NATS:unsubscribe(sid)
    local sid = tostring(sid)
    if self.subscriptions[sid] then
        self.conn:send(string.format("UNSUB %s\r\n", sid))
        self.subscriptions[sid] = nil
    else
        error(string.format("Sub with sid %s dont exist", sid))
    end
end

function NATS:close()
    if self.conn then self.conn:close() end
    self.connected = false
end

return NATS