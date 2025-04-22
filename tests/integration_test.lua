local socket = require("socket")
local NATS = require("nats.nats_cli")

return {
    ["integration: connect and subscribe"] = function()
        local client = NATS.new()
        client:connect()

        local got_message = false

        client:subscribe("test.foo", function(subject, msg)
            assert(subject == "test.foo")
            assert(msg == "hello!")
            got_message = true
        end)

        client:publish("test.foo", "hello!")

        local t0 = socket.gettime()
        while not got_message and socket.gettime() - t0 < 2 do
            client:poll(0.1)
            socket.sleep(0.1)
        end

        assert(got_message, "did not receive published message")
        client:close()
    end
}