-- Noir Verscottie
-- noirv~

-- Environment

local root, sys_src
root = script.Parent; sys_src = root.systems

local loadCharacter


-- Life // Player Singleton
local NOIR = {}


local sys_mods = {
    mobility = sys_src.mobility;
}

function NOIR.live()
    NOIR.character = loadCharacter(); -- Request server to loadCharacter
    NOIR.charRoot = NOIR.character:FindFirstChildWhichIsA('BasePart').AssemblyRootPart
    -- Server Parents player.Character to its created instance; waits to acknowledge character post replication.
    -- Also fixes camera (in a lower layer)

    for sys, path in pairs(sys_mods) do
        NOIR[sys] = require(path)
        if NOIR[sys].live then
            NOIR[sys].live() end
    end
    print("Noir: Hello world!")

    NOIR.live = function() end
    return NOIR
end



-- Source
-- TODO: LoadCharacter on Server and transition replication priveleges to client
function loadCharacter()
    local char = Instance.new('Model')
    char.Name = 'Character'
    char.Parent = workspace

    local body = Instance.new('Part')
    body.Name = 'HumanoidRootPart'
    body.Position = (workspace.Spawn and workspace:FindFirstChild('Spawn').Position) or Vector3.new(-32, 8.6, 118)
    body.Material = Enum.Material.Neon
    body.Color = Color3.fromRGB(246, 255, 193)
    body.Size = Vector3.new(2,2,2)
    body.Transparency = .4
    body.Parent = char
    char.PrimaryPart = body

        local sph_mesh = Instance.new('SpecialMesh')
        sph_mesh.MeshType = Enum.MeshType.Sphere
        sph_mesh.Parent = body

        local att0 = Instance.new('Attachment')
        att0.Name='A0'
        att0.Parent = body

        local att1 = Instance.new('Attachment')
        att1.Name='A1'
        att1.Parent = body

        local beam = Instance.new('Beam')
        beam.Attachment0=att0
        beam.Attachment1 = att1
        beam.LightEmission=1
        beam.Width0=.2
        beam.Width1=.2
        beam.Name='Look'
        beam.Color=ColorSequence.new(Color3.fromRGB(255, 0, 0))
        beam.FaceCamera=true
        beam.Parent=body

        local att2 = Instance.new('Attachment')
        att2.Name='A2'
        att2.Parent = body

        local beam1 = Instance.new('Beam')
        beam1.Attachment0=att0
        beam1.Attachment1 = att2
        beam1.LightEmission=1
        beam1.Width0=.2
        beam1.Width1=.2
        beam1.Name='Up'
        beam1.FaceCamera=true
        beam1.Parent=body
    
    local hum = Instance.new('Humanoid')
    hum.Name = 'Humanoid'
    hum.Parent = char

    -- Set Camera
    workspace.CurrentCamera.CameraSubject = char.Humanoid.RootPart or body
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

    return char
end

-- Loadable
return NOIR