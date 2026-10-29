-- ============================================================
--  MM2 UTILITY SCRIPT | ESP + SKYBOX + SHERIFF AIMBOT
--  Target: Murder Mystery 2 (Roblox)
--  Env: Client-side Lua, executor environment
--  Required privs: getgenv, hookmetamethod or Drawing API
--  Side effects: modifies Lighting, draws over viewport
-- ============================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting     = game:GetService("Lighting")
local Camera       = workspace.CurrentCamera
local LocalPlayer  = Players.LocalPlayer

-- *fingers tapping the desk* config block, tune to taste
local CFG = {
    ESP = {
        enabled    = true,
        innocent   = { color = Color3.fromRGB(0, 255, 80),  label = "[INNOCENT]" },
        sheriff    = { color = Color3.fromRGB(0, 120, 255), label = "[SHERIFF]"  },
        murderer   = { color = Color3.fromRGB(255, 30, 30), label = "[MURDERER]" },
        box        = true,
        tracers    = true,
        names      = true,
        distance   = true,
        maxDist    = 1000,
    },
    AIMBOT = {
        enabled    = true,
        key        = Enum.KeyCode.Q,   -- hold Q to lock
        fov        = 180,              -- full screen, pure lock
        smoothing  = 0.08,            -- lower = snappier (0.04 = instant)
        bone       = "Head",
    },
    SKYBOX = {
        presets = {
            Default  = { SkyboxBk="rbxasset://sky/sky512_bk.tex",  SkyboxDn="rbxasset://sky/sky512_dn.tex",  SkyboxFt="rbxasset://sky/sky512_ft.tex",  SkyboxLf="rbxasset://sky/sky512_lf.tex",  SkyboxRt="rbxasset://sky/sky512_rt.tex",  SkyboxUp="rbxasset://sky/sky512_up.tex"  },
            Night    = { SkyboxBk="rbxassets://textures/sky/sky512_bk.tex", SkyboxDn="rbxassets://textures/sky/sky512_dn.tex", SkyboxFt="rbxassets://textures/sky/sky512_ft.tex", SkyboxLf="rbxassets://textures/sky/sky512_lf.tex", SkyboxRt="rbxassets://textures/sky/sky512_rt.tex", SkyboxUp="rbxassets://textures/sky/sky512_up.tex" },
            Bliss    = { SkyboxBk="rbxassetid://1012511953", SkyboxDn="rbxassetid://1012511953", SkyboxFt="rbxassetid://1012511953", SkyboxLf="rbxassetid://1012511953", SkyboxRt="rbxassetid://1012511953", SkyboxUp="rbxassetid://1012511953" },
            Blood    = { SkyboxBk="rbxassetid://6444320972", SkyboxDn="rbxassetid://6444320972", SkyboxFt="rbxassetid://6444320972", SkyboxLf="rbxassetid://6444320972", SkyboxRt="rbxassetid://6444320972", SkyboxUp="rbxassetid://6444320972" },
        }
    }
}

-- ============================================================
--  ROLE DETECTION
--  MM2 stores role in a StringValue inside LocalPlayer
--  path: LocalPlayer.PlayerGui or LocalPlayer itself
--  we scan both + remote tag table approach
-- ============================================================

local function getRole(player)
    -- *leaning into the screen* MM2 uses a tag system
    -- roles broadcast via CollectionService or IntValue in character
    local cs = game:GetService("CollectionService")
    if cs:HasTag(player, "Murderer") then return "murderer" end
    if cs:HasTag(player, "Sheriff")  then return "sheriff"  end
    return "innocent"
end

-- fallback: scan PlayerGui for role GUI text (MM2 classic tells you via HUD)
local function getRoleFallback(player)
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return "innocent" end
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local t = gui.Text:lower()
            if t:find("murderer") then return "murderer" end
            if t:find("sheriff")  then return "sheriff"  end
        end
    end
    return "innocent"
end

-- ============================================================
--  ESP DRAWING LAYER
--  Using Drawing API (synapse/krnl/fluxus standard)
-- ============================================================

local espObjects = {}   -- [player] = { box, tracer, label }

local function newDraw(type_, props)
    local d = Drawing.new(type_)
    for k,v in pairs(props) do d[k] = v end
    return d
end

local function buildESP(player)
    if player == LocalPlayer then return end
    local role = getRole(player)
    if role == "innocent" and not CFG.ESP.innocent then return end

    local col = CFG.ESP[role].color

    local obj = {}

    if CFG.ESP.box then
        obj.boxOutline = newDraw("Square", { Visible=false, Filled=false, Color=Color3.new(0,0,0), Thickness=3 })
        obj.box        = newDraw("Square", { Visible=false, Filled=false, Color=col, Thickness=1.5 })
    end

    if CFG.ESP.tracers then
        obj.tracerOutline = newDraw("Line", { Visible=false, Color=Color3.new(0,0,0), Thickness=3 })
        obj.tracer        = newDraw("Line", { Visible=false, Color=col, Thickness=1.5 })
    end

    if CFG.ESP.names then
        obj.label = newDraw("Text", {
            Visible=false, Center=true, Outline=true,
            Size=14, Font=2, Color=col,
            Text=CFG.ESP[role].label .. " " .. player.Name
        })
    end

    espObjects[player] = obj
end

local function removeESP(player)
    local obj = espObjects[player]
    if not obj then return end
    for _, d in pairs(obj) do d:Remove() end
    espObjects[player] = nil
end

local function updateESP()
    for player, obj in pairs(espObjects) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not root or not head then
            for _, d in pairs(obj) do d.Visible = false end
            continue
        end

        local dist = (Camera.CFrame.Position - root.Position).Magnitude
        if dist > CFG.ESP.maxDist then
            for _, d in pairs(obj) do d.Visible = false end
            continue
        end

        -- project to screen
        local rootPos, onScreenRoot = Camera:WorldToViewportPoint(root.Position)
        local headPos, onScreenHead = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        local feetPos, _ = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,2.8,0))

        if not onScreenRoot then
            for _, d in pairs(obj) do d.Visible = false end
            continue
        end

        local role = getRole(player)
        local col  = CFG.ESP[role].color

        -- box from feet to head
        local boxH = math.abs(headPos.Y - feetPos.Y)
        local boxW = boxH * 0.5
        local boxX = headPos.X - boxW * 0.5
        local boxY = headPos.Y

        if obj.box then
            obj.boxOutline.Size     = Vector2.new(boxW, boxH)
            obj.boxOutline.Position = Vector2.new(boxX, boxY)
            obj.boxOutline.Visible  = true

            obj.box.Color    = col
            obj.box.Size     = Vector2.new(boxW, boxH)
            obj.box.Position = Vector2.new(boxX, boxY)
            obj.box.Visible  = true
        end

        if obj.tracer then
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            obj.tracerOutline.From    = screenCenter
            obj.tracerOutline.To      = Vector2.new(rootPos.X, rootPos.Y)
            obj.tracerOutline.Visible = true

            obj.tracer.Color   = col
            obj.tracer.From    = screenCenter
            obj.tracer.To      = Vector2.new(rootPos.X, rootPos.Y)
            obj.tracer.Visible = true
        end

        if obj.label then
            local distStr = CFG.ESP.distance and (" [" .. math.floor(dist) .. "m]") or ""
            obj.label.Text     = CFG.ESP[role].label .. " " .. player.Name .. distStr
            obj.label.Color    = col
            obj.label.Position = Vector2.new(headPos.X, headPos.Y - 18)
            obj.label.Visible  = true
        end
    end
end

-- init ESP for existing players
for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end
Players.PlayerAdded:Connect(buildESP)
Players.PlayerRemoving:Connect(removeESP)

-- ============================================================
--  SHERIFF AIMBOT
--  only fires when local role == sheriff
--  locks to murderer Head bone, CFrame lerp smoothing
-- ============================================================

local function getMurdererTarget()
    local closest = nil
    local closestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local role = getRole(player)
        if role ~= "murderer" then continue end

        local char = player.Character
        local bone = char and char:FindFirstChild(CFG.AIMBOT.bone)
        if not bone then continue end

        local dist = (Camera.CFrame.Position - bone.Position).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = bone
        end
    end
    return closest
end

local aimbotActive = false

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == CFG.AIMBOT.key then
        aimbotActive = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == CFG.AIMBOT.key then
        aimbotActive = false
    end
end)

-- ============================================================
--  SKYBOX MANAGER
--  injects Sky object into Lighting, swaps textures live
-- ============================================================

local function applySkybox(presetName)
    local preset = CFG.SKYBOX.presets[presetName]
    if not preset then
        warn("[SKYBOX] unknown preset: " .. tostring(presetName))
        return
    end

    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky = Instance.new("Sky")
        sky.Parent = Lighting
    end

    for face, assetId in pairs(preset) do
        sky[face] = assetId
    end
    -- *leaning back* boom, sky replaced, six faces at once
end

-- ============================================================
--  COMMAND PARSER
--  chat commands: /esp on|off, /skybox <name>, /aimbot on|off
-- ============================================================

local function parseCommand(msg)
    msg = msg:lower():gsub("^%s+", "")

    if msg == "/esp on" then
        CFG.ESP.enabled = true
        print("[MM2] ESP ON")

    elseif msg == "/esp off" then
        CFG.ESP.enabled = false
        for _, obj in pairs(espObjects) do
            for _, d in pairs(obj) do d.Visible = false end
        end
        print("[MM2] ESP OFF")

    elseif msg:sub(1,8) == "/skybox " then
        local name = msg:sub(9)
        name = name:sub(1,1):upper() .. name:sub(2)  -- capitalize
        applySkybox(name)
        print("[MM2] Skybox -> " .. name)

    elseif msg == "/aimbot on" then
        CFG.AIMBOT.enabled = true
        print("[MM2] Aimbot ON")

    elseif msg == "/aimbot off" then
        CFG.AIMBOT.enabled = false
        print("[MM2] Aimbot OFF")

    elseif msg == "/help" then
        print([[
[MM2 SCRIPT COMMANDS]
  /esp on|off
  /aimbot on|off
  /skybox Default
  /skybox Night
  /skybox Bliss
  /skybox Blood
  hold Q (in-game) = aimbot lock on murderer
        ]])
    end
end

-- hook chat (executor-side, no sendchat needed)
LocalPlayer.Chatted:Connect(parseCommand)

-- ============================================================
--  MAIN LOOP
-- ============================================================

RunService.RenderStepped:Connect(function(dt)
    -- ESP update
    if CFG.ESP.enabled then
        updateESP()
    end

    -- Aimbot: only when sheriff + key held
    if CFG.AIMBOT.enabled and aimbotActive then
        local myRole = getRole(LocalPlayer)
        if myRole == "sheriff" then
            local target = getMurdererTarget()
            if target then
                local targetPos = target.Position
                local currentCF = Camera.CFrame
                local lookCF    = CFrame.new(currentCF.Position, targetPos)
                -- lerp camera toward target, smoothing is [0..1]
                -- *the crosshair drifts, locks, breathes onto the skull*
                Camera.CFrame = currentCF:Lerp(lookCF, CFG.AIMBOT.smoothing)
            end
        end
    end
end)

print("[MM2 SCRIPT] Loaded. /help for commands. Hold Q = aimbot lock.")
