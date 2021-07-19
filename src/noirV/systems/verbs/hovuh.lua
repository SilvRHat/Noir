-- Noir Verscottie
-- noirv~

-- HOVUH // Hovering mobility
-- VERSE (verb system) #1


-- DEPENDENCIES
local runservice = game:GetService('RunService')
local replicatedstorage = game:GetService('ReplicatedStorage')
local contextactionservice = game:GetService('ContextActionService')

local verbs, systems, noirroot: Instance
verbs = script.Parent; systems = verbs.Parent;  noirroot = systems.Parent;

local utils = replicatedstorage:WaitForChild('utils')
local maid = require(utils.maid)
local spring = require(utils.spring)
local linalg = require(utils.linalg)



-- CONSTANTS
local BASE_LEVI_HEIGHT = 4.2;
local SPRINT_LEVI_HEIGHT = 2;

local LEVI_SPRING_SPEED, LEVI_SPRING_DAMPING = 22, 1.2

local CAM_MAX_ANGLE = 10
local SURF_MAX_ANGLE_DT = 360

local ZERO_VECTOR3 = Vector3.new()
local LARGE_SCALAR = 10000
local GRAV_MAX = 20
local MAX_ANGLE_CHANGE = 30


-- NOIR // SYS // VERSE
local NOIR = require(noirroot.noir)
local MOBILITY = require(systems.mobility)
local VERSE = {
    -- Internals
    _maid = nil;

    -- Exernals
    levitate = true;
    levitateSpring = nil;

    _speed_pieces = {};
    targetspeed = 0;
    surfnorm = Vector3.new(0,1,0).Unit;
    hoverCF = CFrame.new();
    offsurf = BASE_LEVI_HEIGHT;
}



-- SOURCE
local keys_pressed = {}
function updateMoveVec(act_name, input_state, input_data)
    local key_vals = {
        [Enum.KeyCode.W] = Vector2.new(1,0);
        [Enum.KeyCode.S] = Vector2.new(-1,0);
        [Enum.KeyCode.D] = Vector2.new(0,1);
        [Enum.KeyCode.A] = Vector2.new(0,-1);
    }

    local calc_int = Vector2.new()
    keys_pressed[input_data.KeyCode] = (input_state == Enum.UserInputState.Begin)
    
    for key, val in pairs(key_vals) do
        if keys_pressed[key] then
            calc_int += val end
    end 

    if calc_int.Magnitude>1 then
        calc_int = calc_int.Unit end

    MOBILITY.invals.mobility = calc_int
end

function updateSprint(act_name, input_state, input_data)
    local isSprinting: boolean = (input_state == Enum.UserInputState.Begin)
    MOBILITY.invals.sprinting = isSprinting
    VERSE.targetspeed = isSprinting and 40 or 24
end





-- surveySurfaces() - Gathers data about the surfaces of nearby rectangular parts
    -- @param radius (number) - Maximum radius of to survey parts from character
    -- @returns - Array of surface data; 
    -- For each surface gives part, closest point to part, closest point on closest ideal plane of part
local function surveySurfaces(radius)
    local charRoot = NOIR.charRoot
    local region = Region3.new(
        charRoot.Position - (Vector3.new(1,1,1)*radius),
        charRoot.Position + (Vector3.new(1,1,1)*radius)
    )
    local parts =  workspace:FindPartsInRegion3(region, charRoot, 100)

    local surfs = {}
    for i, p in ipairs(parts) do
        if not (p:IsA('Part') and (not p:FindFirstChildWhichIsA('DataModelMesh'))) then
            continue end -- Only consider Rectangles
        
        local fromPartCF = p.CFrame:ToObjectSpace(charRoot.CFrame)
        local fromEnds = Vector3.new(
            math.abs(fromPartCF.Position.X),
            math.abs(fromPartCF.Position.Y),
            math.abs(fromPartCF.Position.Z)
        ) - (p.Size/2)


        local surface, mask, maxsurface : Vector3 = 
            Vector3.new(), Vector3.new(), Vector3.new()
        for _, axis in ipairs({'X','Y','Z'}) do
            surface = surface + (
                Vector3.fromAxis(axis) *                                    -- Axis calculated
                (math.abs(fromPartCF[axis]) > p.Size[axis]/2 and 1 or 0) *  -- Direction
                ((fromPartCF[axis] > 0) and 1 or -1)                        -- Negative Directional component
            )
            mask = mask + (
                Vector3.fromAxis(axis) *
                (surface[axis]==0 and 1 or 0)
            )
            maxsurface = maxsurface + (
                Vector3.fromAxis(axis) * 
                surface[axis] * 
                (fromEnds[axis]==math.max(fromEnds.X, fromEnds.Y, fromEnds.Z) and 1 or 0)
            )
        end

        local hit
        local surf = {
            pos = Vector3.new();            -- Position of closest point on part
            maxnormpos = Vector3.new();     -- Position of closest point to plane defined by the 'dominant' (farthest) normal vector off part
            part = p;                       -- Part in calculation
        }

        -- Calculate the point in closest point in space on the part
        if surface.Magnitude==1 then
            hit = linalg.lineToPlaneIntersection(
                fromPartCF.Position, surface, (p.Size*surface)/2, surface)
        elseif surface.Magnitude>1 then
            hit = (p.Size/2 * surface) + (fromPartCF.Position * mask)
        else 
            continue end

        surf.pos = p.CFrame:PointToWorldSpace(hit)
        surf.maxnormpos = p.CFrame:PointToWorldSpace(
            linalg.lineToPlaneIntersection(fromPartCF.Position, maxsurface, (p.Size*maxsurface)/2, maxsurface)
        )
        
        table.insert(surfs, surf)
    end

    return surfs
end

-- Figure out best surface
function readGround(step)
    local bestscore: number = 0
    local bestsurf: table = nil
    local bestdiff: Vector3 = nil

    for i, surf in ipairs(VERSE._surfs) do
        local pos = MOBILITY.invals.sprinting and surf.pos or surf.maxnormpos
        
        local diff = NOIR.charRoot.Position - pos
        local angle = math.deg(
            math.acos(diff.Unit:Dot(VERSE.surfnorm))
        )
        if (angle>MAX_ANGLE_CHANGE) then
            continue end
        
        local score = (MAX_ANGLE_CHANGE-angle)^2 / (MAX_ANGLE_CHANGE*(diff.Magnitude + 6))
        if score>bestscore then
            bestscore=score
            bestsurf=surf
            bestdiff=diff
        end
    end
    if not bestsurf then
        VERSE.offsurf = LARGE_SCALAR
        NOIR.charRoot.A1.Position = Vector3.new()
    return end
    
    VERSE.surfnorm = bestdiff.Unit 
    VERSE.offsurf = bestdiff.Magnitude
    
    NOIR.charRoot.A1.WorldPosition = NOIR.charRoot.Position - bestdiff
    NOIR.charRoot.A2.Position = VERSE.surfnorm * 4
end


-- hover
function hover(gear, runtime, step)
    local cam=workspace.CurrentCamera
    local upvec=VERSE.surfnorm

    local cam_end_mult = math.min(1, 
        ((math.pi/2) - math.abs((math.pi/2) - math.acos(cam.CFrame.LookVector:Dot(upvec)))) / math.rad(CAM_MAX_ANGLE)
    )^1.5

    local linear = VERSE.hoverCF * (
        Vector3.new(MOBILITY.invals.mobility.Y, 0, -MOBILITY.invals.mobility.X)
    )

    MOBILITY:OneTimeVelocity(linear, ZERO_VECTOR3, 
        VERSE:GetActivation(), cam_end_mult, MOBILITY.speed)    -- Multipliers
end

function levitate(gear, runtime, step)
    --check if jumping or blah
    local s = VERSE.levitateSpring
    local linvel = VERSE.hoverCF:PointToObjectSpace(MOBILITY.linearVelocity).Y
    
    local _, oldvel = s:GetState()
    local target = (MOBILITY.invals.sprinting and MOBILITY.invals.mobility.Magnitude>0)
        and SPRINT_LEVI_HEIGHT or BASE_LEVI_HEIGHT 
    
        s:SetState(VERSE.offsurf, linvel)
    s:SetTarget(target, 0)

    s:Update(step)
    local _, newvel = s:GetState()
    
    local levivel = VERSE.hoverCF:PointToWorldSpace(Vector3.new(0, math.clamp(.5*(oldvel+newvel), -GRAV_MAX, GRAV_MAX), 0))
    MOBILITY:OneTimeVelocity(levivel, ZERO_VECTOR3, 
        VERSE:GetActivation())
end



-- updateHoverCF // Updates the hover CFrame after camera updates
function updateHoverCF()
    local camCF = workspace.CurrentCamera.CFrame
    local up = VERSE.surfnorm

    local lookfromup, look: Vector3
    local upCF = CFrame.lookAt(Vector3.new(), up) * CFrame.Angles(math.rad(-90),0,0)
    lookfromup = upCF:PointToObjectSpace(camCF.LookVector) * Vector3.new(1,0,1)

    look = upCF:PointToWorldSpace(lookfromup)
    VERSE.hoverCF = CFrame.lookAt(Vector3.new(), look, up)
end



-- lookStep // Survey's environment and current state in various claculations useful for later physics calc
    -- (Noir looking around)
function lookStep(step)
    -- Get surfaces
    VERSE._surfs = surveySurfaces(20)    
    -- Find surface / calc dist
    readGround(step)
    -- Calculate aviation

    -- update CFrame
    if 1-MOBILITY.aviation>1e-2 then
        updateHoverCF() end
end

function speedStep(step)
    
end


local init=false
function VERSE.live()
    if init then VERSE:Destroy() end
        init = true
    
    -- Functionality
    runservice:BindToRenderStep('HOVER_LOOKSTEP', Enum.RenderPriority.Camera.Value+1, lookStep)
    runservice:BindToRenderStep('HOVER_LOOKSTEP', Enum.RenderPriority.Input.Value+1, speedStep)

    VERSE._maid = maid.new()
    MOBILITY:BindGear('HOVER_MOVE', hover)

    local s = spring.new(LEVI_SPRING_SPEED, LEVI_SPRING_DAMPING)
    VERSE.levitateSpring = s
    s:SetState(BASE_LEVI_HEIGHT, 0)
    s:SetTarget(BASE_LEVI_HEIGHT, 0)
    s.hertz = 100
    MOBILITY:BindGear('HOVER_LEVITATE', levitate)

    MOBILITY:BindGear('SPEED_HOVER', speedStep)

    contextactionservice:BindAction("KEYBOARD_MOVE", updateMoveVec, false,
        table.unpack(MOBILITY.inputs.hover))
    contextactionservice:BindAction("KEYBOARD_SPRINT", updateSprint, false,
        table.unpack(MOBILITY.inputs.sprint))
    
    return VERSE
end

function VERSE:Destroy()
    self._maid:Clean()
end

function VERSE:GetActivation()
    return 1 - (MOBILITY.aviation^2)
end

return VERSE