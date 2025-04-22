
local mocked_socket = require("tests.helpers.mocked_socket")
local test_env = require("tests.helpers.test_env")
local NATS = require("nats.nats_cli")

return {
    ["test new client default opts"] = function()
        test_env.with_test_client(function(client, mock)
            assert(type(client) == "table", "Client should be a table")
            assert(client.verbose == false, "Default verbose should be false")
        end)
    end,

    ["test custom opts"] = function()
        test_env.with_test_client(function(client, mock)
            local client = NATS.new("localhost", {verbose = true}, 9999)
            assert(client.host == "localhost")
            assert(client.port == 9999)
            assert(client.verbose == true)
        end)
    end,

    ["test connect sends CONNECT"] = function()
        test_env.with_test_client(function(client, mock)
            client:connect()

            assert(mock.connected, "Socket should be connected")
            assert(#mock.sent_data > 0, "Data should be sent")
            assert(mock.sent_data[1]:match('^CONNECT {"verbose":false}\r\n$'), "CONNECT message should be sent")
            assert(client.connected == true, "self.connected should be true")
        end)
    end,

    ["test connect verbose sends CONNECT "] = function()
        test_env.with_test_client(function(client, mock)
            client.verbose = true
            client:connect()

            assert(mock.connected, "Socket should be connected")
            assert(#mock.sent_data > 0, "Data should be sent")
            assert(mock.sent_data[1]:match('^CONNECT {"verbose":true}\r\n$'), "CONNECT message should be sent")
            assert(client.connected == true, "self.connected should be true")
        end)
    end,

    ["test publish sends PUB"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.conn = socket.tcp()
            client.conn:settimeout(1)
            client:publish("test", "hello")
            assert(#mock.sent_data > 0, "Data should be sent")
            assert(mock.sent_data[1]:match("^PUB test 5\r\nhello\r\n$"), "PUB message should be sent")
        end)
    end,

    ["test subscribe stores callback and sends SUB"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.conn = socket.tcp()
            client.conn:settimeout(1)
            local func = function() end 
            sid = client:subscribe("test", func)
            assert(client.subscriptions[sid] == func, "Subscription should be stored")
            assert(sid == "1", "Subscription ID should be 1")
            assert(#mock.sent_data > 0, "Data should be sent")
            assert(mock.sent_data[1]:match("^SUB test 1\r\n$"), "Message sent does not match expected format")
        end)
    end,

    ["test subscribe fails if not connected"] = function()
        test_env.with_test_client(function(client, mock)
            local ok, err = pcall(function()
                client:subscribe("test", function() end)
            end)
    
            assert(not ok, "subscribe() should fail if not connected")
            assert(tostring(err):match("Cannot subscribe before connecting"), "Proper error message expected")
        end)
    end,

    ["test connect fails if not able to connect"] = function()
        test_env.with_test_client(function(client, mock)
            function mock:connect(host, port)
                return nil, "Connection failed"
            end
            local ok, err = pcall(function()
                client:connect()
            end)
            assert(not ok, "connect() should fail")
            assert(tostring(err):match("connection failed"), "Proper error message expected")
        end)
    end,

    ["test unsubscribe removes subscription"] = function()
        test_env.with_test_client(function(client, mock)
            local sid = "1"
            local func = function() end
            client.connected = true
            client.conn = socket.tcp()
            client.conn:settimeout(1)
            client.subscriptions[sid] = func
            client:unsubscribe(sid)
            assert(client.subscriptions[sid] == nil, "Subscription should be removed")
            assert(#mock.sent_data > 0, "Data should be sent")
            assert(mock.sent_data[1]:match(string.format("^UNSUB %s\r\n$", sid)), "Message sent does not match expected format")
        end)
    end,

    ["test unsubscribe fails if not subscribed"] = function()
        test_env.with_test_client(function(client, mock)
            local ok, err = pcall(function()
                client:unsubscribe("nonexistent_sid")
            end)
            assert(not ok, "unsubscribe() should fail if no subscription found")
            assert(tostring(err):match("dont exist"), "Proper error message expected")
        end)
    end,

    ["test read_loop does not block indefinitely"] = function()
        test_env.with_test_client(function(client, mock)
            local iterations = 0
            function client:poll()
                iterations = iterations + 1
                if iterations > 5 then
                    self.read_loop_run = false -- zatrzymujemy pętlę
                end
                assert(iterations < 10, "read_loop should not block indefinitely")
            end
    
            client:read_loop()
            assert(iterations > 0, "read_loop should have called poll at least once")
        end)
    end,

    ["test poll handles PING"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.conn = socket.tcp()
    
            function mock:receive(_) return "PING" end
    
            local hook_called = false
            client.hooks:set("ping", function() hook_called = true end)
    
            client:poll()
    
            assert(#mock.sent_data > 0, "Data should be sent")
            assert(mock.sent_data[1]:match("^PONG\r\n$"), "Should send PONG on PING")
            assert(hook_called, "Should call ping hook")
        end)
    end,
    
    ["test poll ignores OK"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.conn = socket.tcp()
            function mock:receive(_) return "+OK" end
    
            local ok, err = pcall(function()
                client:poll()
            end)
    
            assert(ok, "Should not fail on +OK")
        end)
    end,
    
    ["test poll handles ERR line"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.conn = socket.tcp()
            function mock:receive(_) return "-ERR Some error" end
    
            local ok, err = pcall(function()
                client:poll()
            end)
    
            assert(ok, "Should handle -ERR without crashing")
        end)
    end,
    
    ["test poll handles INFO and triggers hook"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.debug = true
            client.conn = socket.tcp()

            function mock:receive(_) return "INFO {\"server_id\":\"test\"}" end
    
            local info_received = false
            client.hooks:set("ok", function(line)
                if line:match("INFO {\"server_id\":\"test\"}") then info_received = true end
            end)
    
            client:poll()
    
            assert(info_received, "Should call 'ok' hook with INFO line")
        end)
    end,
    
    ["test poll handles unknown line"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.conn = socket.tcp()
            function mock:receive(_) return "RANDOM GARBAGE" end
    
            local ok, err = pcall(function()
                client:poll()
            end)
    
            assert(ok, "Should ignore unknown lines gracefully")
        end)
    end,
    
    ["test poll handles nil safely"] = function()
        test_env.with_test_client(function(client, mock)
            client.connected = true
            client.conn = socket.tcp()
            function mock:receive(_) return nil, "timeout" end
    
            local ok, err = pcall(function()
                client:poll()
            end)
    
            assert(ok, "Should not crash on nil return from receive")
        end)
    end,

    ["test set_hook works correctly"] = function()
        test_env.with_test_client(function(client, mock)
            local test_hook = function() print("Hook triggered!") end
            client:set_hook("ping", test_hook)
            assert(client.hooks.registry["ping"] == test_hook, "Hook should be set")
        end)
    end,

    ["test close disconnects correctly"] = function()
        test_env.with_test_client(function(client, mock)
            client:close()
            assert(not client.connected, "Client should be disconnected")
            assert(client.conn == nil, "Client connection should be nil after closing")
        end)
    end
}