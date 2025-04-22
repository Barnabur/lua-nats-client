local function new_mocked_socket()
    local self = {
        connected = false,
        closed = false,
        sent_data = {},
        receive_queue = {}, 
    }

    function self:connect(host, port)
        self.connected = true
        self.host = host
        self.port = port
        return true
    end

    function self:send(data)
        table.insert(self.sent_data, data)
        return #data
    end

    function self:receive(pattern)
        if #self.receive_queue > 0 then
            return table.remove(self.receive_queue, 1)
        else
            return nil
        end
    end

    function self:enqueue_receive(data)
        table.insert(self.receive_queue, data)
    end

    function self:settimeout(timeout)
        self.timeout = timeout
        return true
    end

    function self:close()
        self.closed = true
    end



    return self
end

return {
    new = new_mocked_socket
}