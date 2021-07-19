-- noirv~
-- Spring Class - for animation and stylized linear movement lerping

-- Dependencies
local replicatedstorage=game:GetService('ReplicatedStorage')
local utils = replicatedstorage:WaitForChild('utils')
local VectorN = require(utils:WaitForChild('nvector'))


-- RK4Stepper // A runge-kutta 4th order ODE solver
    -- @param system - ODE System to call (this should return a derivative)
    -- @param state_vec - The state vector
    -- @param t - Time variable for time non-autonomous systems
    -- @param h - Step size
    -- @return Newtime
    -- @return New State Vec
function RK4Stepper(system, state_vec, t, h)
    local coefs = {1,2,2,1}
    local k_vecs = {}

    table.insert(k_vecs, h * system(state_vec, t))
    local summed_vecs = k_vecs[1]
    for i = 2, 4 do
        local c = coefs[i]
        table.insert(k_vecs, h * system(k_vecs[i-1]/c, t+(h/c)))
        summed_vecs = summed_vecs + (k_vecs[i]*c)
    end

    return t+h, state_vec + (summed_vecs/ 6)
end




-- Spring Class
local springClass = {}
springClass.__index = springClass

    
function springClass.new(speed, dampening)
    local self = setmetatable({}, springClass)

    self._time = 0
    self._state = nil
    self._target = nil

    self.s = speed or 1
    self.d = dampening or 1
    self.hertz = 20     -- Fairly quick & no significant difference in accuracy


    self._update_func = function(s, t)
        local pos, vel = s[1], s[2]

        local pos_dt = vel
        local vel_dt = (-pos * (self.s^2)) - (2 * self.s * self.d * vel)
        
        return VectorN.new(pos_dt, vel_dt)
    end

    return self
end

function springClass:SetState(pos, vel)
    self._state = VectorN.new(pos, vel)
    if not self._target then
        self._target = self._state * 0 end
end

function springClass:SetTarget(pos, vel)
    self._target = VectorN.new(pos, vel)
    if not self._state then
        self._state = self._target * 0 end
end

function springClass:GetState()
    return self._state[1], self._state[2] end


function springClass:Update(dt)
    local step_rate = 1/ self.hertz
    for _= 1, math.floor(dt/ step_rate) do
        local newtime, newrawstate = RK4Stepper(
            self._update_func, self._state-self._target, self._time, step_rate
        )
        self._time, self._state = newtime, newrawstate + self._target
    end

    local newtime, newrawstate = RK4Stepper(
        self._update_func, self._state-self._target, self._time, dt % step_rate
    )
    self._time, self._state = newtime, newrawstate + self._target
end

return springClass