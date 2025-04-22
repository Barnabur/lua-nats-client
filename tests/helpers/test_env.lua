local mocked_socket = require("tests.helpers.mocked_socket")
local socket = require("socket")

local original_tcp = socket.tcp

local function with_test_client(test_func)
    local mock = mocked_socket.new()

    socket.tcp = function()
        return mock
    end

    local NATS = require("nats.nats_cli")
    local client = NATS.new()

    local ok, err = pcall(function()
        test_func(client, mock)
    end)

    socket.tcp = original_tcp

    if not ok then
        error(err)
    end
end

return {
    with_test_client = with_test_client
}