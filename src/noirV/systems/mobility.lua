-- Noir Verscottie
-- noirv~

-- MOBILITY // Singleton to operate mobility components and character verbs


-- DEPENDENCIES
local replicatedstorage = game:GetService('ReplicatedStorage')
local runservice = game:GetService('RunService')

local utils = replicatedstorage:WaitForChild('utils')
local maid = require(utils.maid)
local gear = require(utils.gear)
local drum = require(utils.drum)

local systems, noirroot, verbs: Instance
systems = script.Parent; noirroot = systems.Parent; verbs = systems.verbs


-- CONSTANTS
local ZERO_VECTOR3 = Vector3.new()

-- CONFIG
local verses = {
    hovuh = verbs.hovuh;
}

-- Input mappings prototype
local inputs = {
    hover = {
        Enum.KeyCode.W; -- Right
        Enum.KeyCode.A; -- Left
        Enum.KeyCode.S; -- Back
        Enum.KeyCode.D; -- Right
    };
    sprint = {
        Enum.KeyCode.RightShift;
        Enum.KeyCode.LeftShift;
    };
    jump = {
        Enum.KeyCode.Space;
    }
}


-- NOIR // SYS
-- Mobility contains information on the state of mobility pieces. It acts as a BaseCharacterController
local NOIR = require(noirroot.noir)
local MOBILITY = {
    _gears = {};        -- Binded functions to run update on
    
    linearVelocity = drum.new(ZERO_VECTOR3);
    angularVelocity = drum.new(ZERO_VECTOR3);
    speedDiff = drum.new(0);

    inputs = inputs;                -- List of input mappings
    invals = {                      -- Input Values
        mobility = Vector2.new();       -- Direction of mobility
        sprinting = false;              -- Actively using sprint mechanic
        jump = false;
    };
    
    aviation = 0;
    speed = 0;              -- True speed
}




-- mobilityStep // turns a set of imaginary gears, then calculates player velocity
    -- @param runtime - Runtime of game
    -- @param step - time since last step
function mobilityStep(self, runtime, step)
    -- Turn gears
    for name, g in pairs(self._gears) do
        g:Update(runtime, step) end

    local linear, angular: Vector3 = Vector3.new(), Vector3.new()
    for _, vel in ipairs(self._vel_pieces) do
        linear += vel.linearVelocity or ZERO_VECTOR3
        angular += vel.angularVelocity or ZERO_VECTOR3
    end

    local assembly: BasePart = NOIR.charRoot
    assembly.AssemblyLinearVelocity = linear
    assembly.AssemblyAngularVelocity = angular
    
    self._vel_pieces = {}
    self.linearVelocity = linear
    self.angularVelocity = angular
end




-- live // The Mobility singleton initializer
    -- Connects functionality and initializes verb modules which interface with the mobility class
local init=false
function MOBILITY.live()
    local self = MOBILITY
    if init then self:Destroy() end
        init = true
    
    -- Functionality
    local stepconn : RBXScriptConnection
    stepconn = runservice.Stepped:Connect(function (...)
        mobilityStep(MOBILITY, ...)
    end)

    self._maid = maid.new(
        stepconn
    )

    -- Start up verses
    for name, path in pairs(verses) do
        local verb = require(path)
        self[name] = verb
        if verb.live then
            verb.live() end
    end

    return self
end

function MOBILITY:Destroy()
    self._maid:Clean()
end

function MOBILITY:BindGear(name, func)
    local newgear = gear.new(func)
    newgear.Name = name
    if self._gears[name] then
        warn(name..' is already bound to mobility') return end
    self._gears[name] = newgear
    return newgear
end

function MOBILITY:UnbindGear(name)
    self._gears[name] = nil
end

function MOBILITY:OneTimeVelocity(linear: Vector3, angular: Vector3, ...)
    local multipliers = {...}
    local m = 1; 
    for i,multiplier in ipairs(multipliers) do 
        m*=multiplier end
    table.insert(self._vel_pieces, {
        linearVelocity = linear * m;
        angularVelocity = angular * m;
    })
end

function MOBILITY:OneTimeSpeedDt(num, ...)
    local multipliers = {...}
    local m = 1; 
    for i, multiplier in ipairs(multipliers) do 
        m*=multiplier end
    table.insert(self._speed_dt_pieces, num * m)
end

return MOBILITY