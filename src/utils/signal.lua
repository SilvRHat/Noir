-- Signal Class
-- Modified from EgoMoose's signal class
-- Allows custom signals for triggering/ invoking certain code by events
-- noirv~


-- Class
local signalClass = {}
signalClass.__index = signalClass
signalClass.ClassName = 'Signal'


-- Public Constructors
function signalClass.new()
    local self = setmetatable({}, signalClass)
    
    self._connections = {}
    self._bind = Instance.new("BindableEvent")

    return self
end


-- Public Methods
function signalClass:Connect(func)
    local connection = self._bind.Event:Connect(function (params) 
        func(table.unpack(params)) 
    end)
    table.insert(self._connections, connection)
    return connection
end

function signalClass:Fire(...)
    self._bind:Fire({...})
end

function signalClass:Wait()
    return signalClass._bind.Event:Wait()
end

function signalClass:Clear()
    for i, connection in ipairs(self._connections) do
        if connection.Connected then 
            connection:Disconnect() end
        self.connections[i] = nil
    end
end

function signalClass:Destroy()
    self:Clear()
    self._bind:Destroy()
    self._bind = nil
end


-- 
return signalClass