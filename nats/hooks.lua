local Hooks = {}

function Hooks.new()
    return setmetatable({
        registry = {}
    }, { __index = Hooks })
end

function Hooks:set(event, callback)
    self.registry[event] = callback
end

function Hooks:call(event, ...)
    local callback = self.registry[event]
    if callback then
        return callback(...)
    end
end

return Hooks