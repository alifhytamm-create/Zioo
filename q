this is a RAW text
-- ================================================
-- Crazy War Gang Script
-- Executor LocalScript | CoreGui Safe
-- ================================================

local Players      = game:GetService("Players")
local VIM          = game:GetService("VirtualInputManager")
local VU           = game:GetService("VirtualUser")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ================================================
-- ANTI-AFK
-- ================================================
player.Idled:Connect(function()
    VU:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VU:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

-- ================================================
-- CONFIG
-- ================================================
local cfg = {
    Water       = "Water",
    Sugar       = "Sugar Block Bag",
    Gelatin     = "Gelatin",
    Bag         = "Empty Bag",

    WaterTime   = 21,
    GelatinTime = 46,
    BagTime     = 1,

    TeleportPos        = Vector3.new(510.73, 4.52, 602.21),
    SellCFrame         = CFrame.new(753.15, 3.71, 436.89),
    GsMidPos           = Vector3.new(160.86, 4.67, -188.50),
    GsEndPos           = Vector3.new(-465.51, 4.80, 360.13),
    AutoFarmPos        = Vector3.new(550.83, 3.66, -566.38),
    HomePos            = nil,
    RetreatHPThreshold = 0.5,
}

-- ================================================
-- STATE
-- ================================================
local isCooking     = false
local isLooping     = false
local isTeleporting = false
local isRetreating  = false
local autoRetreat   = false
local cookCount     = 0
local espData       = {}
local espEnabled    = false
local currentPage   = 1
local healthConn    = nil
local isMinimized   = false

-- ================================================
-- INVENTORY
-- ================================================

local function findToolByName(toolName)
    local lower = toolName:lower()
    local char  = player.Character
    local bp    = player:FindFirstChild("Backpack")
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower() == lower then return v end
        end
    end
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower() == lower then return v end
        end
    end
    return nil
end

local function switchTool(toolName)
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    hum:UnequipTools()
    task.wait(0.15)
    local tool = findToolByName(toolName)
    if not tool then return false end
    hum:EquipTool(tool)
    task.wait(0.25)
    return true
end

-- ================================================
-- INPUT
-- ================================================

local function pressE()
    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function holdE(seconds)
    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    local start = tick()
    while tick() - start < seconds do
        if not isCooking then break end
        task.wait(0.05)
    end
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function releaseE()
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- ================================================
-- VEHICLE
-- ================================================

local function getVehicle()
    local char = player.Character
    if not char then return nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local seat = hum.SeatPart
    if not seat then return nil end
    return seat:FindFirstAncestorOfClass("Model"), seat
end

-- ================================================
-- TELEPORT
-- ================================================

local function teleportHRP(pos)
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart", 5)
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false end
    local prevSpeed = hum and hum.WalkSpeed or 16
    local prevJump  = hum and hum.JumpPower  or 50
    if hum then
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end
    local wasAnchored = hrp.Anchored
    hrp.Anchored = true
    hrp.CFrame   = CFrame.new(pos)
    task.wait(0.3)
    hrp.Anchored = wasAnchored
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.wait(0.1)
        hum.WalkSpeed = prevSpeed
        hum.JumpPower = prevJump
    end
    return true
end

local function teleportWithVehicle(targetPos)
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart", 5)
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false, "error" end
    local vehicle, seat = getVehicle()
    if vehicle and vehicle.PrimaryPart then
        local states = {}
        for _, p in ipairs(vehicle:GetDescendants()) do
            if p:IsA("BasePart") then
                states[p] = p.Anchored
                p.Anchored = true
            end
        end
        vehicle:SetPrimaryPartCFrame(CFrame.new(targetPos))
        hrp.CFrame = CFrame.new(targetPos)
        task.wait(0.3)
        for p, s in pairs(states) do
            if p and p.Parent then p.Anchored = s end
        end
        if seat and seat:IsA("VehicleSeat") then
            task.wait(0.1)
            seat:Sit(hum)
        end
        return true, "vehicle"
    else
        teleportHRP(targetPos)
        return true, "character"
    end
end

local function teleportDs()
    local char = player.Character
    if not char then return false, "no character" end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false, "no humanoid" end
    local seat = hum.SeatPart
    if not seat then return false, "not in vehicle" end
    local dirtbike = seat:FindFirstAncestorOfClass("Model")
    if not dirtbike then return false, "no model" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local prevSpeed = hum.WalkSpeed
    local prevJump  = hum.JumpPower
    hum.WalkSpeed = 0
    hum.JumpPower = 0
    local states = {}
    for _, p in ipairs(dirtbike:GetDescendants()) do
        if p:IsA("BasePart") then
            states[p] = p.Anchored
            p.Anchored = true
        end
    end
    dirtbike:PivotTo(cfg.SellCFrame)
    if hrp then hrp.CFrame = cfg.SellCFrame end
    task.wait(0.3)
    for p, s in pairs(states) do
        if p and p.Parent then p.Anchored = s end
    end
    hum.WalkSpeed = prevSpeed
    hum.JumpPower = prevJump
    return true, "dirtbike"
end

-- ================================================
-- AUTO JAIL
-- ================================================

local function doRetreat()
    if isRetreating then return end
    isRetreating = true
    teleportWithVehicle(cfg.AutoFarmPos)
    task.wait(5)
    if cfg.HomePos then
        teleportWithVehicle(cfg.HomePos)
        task.wait(5)
    end
    isRetreating = false
end

local function connectHealthWatch()
    if healthConn then healthConn:Disconnect() healthConn = nil end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local prevHealth = hum.Health
    healthConn = hum.HealthChanged:Connect(function(newHealth)
        if not autoRetreat or isRetreating then return end
        if newHealth < prevHealth and newHealth > 0 then
            local pct = newHealth / math.max(hum.MaxHealth, 1)
            if pct < cfg.RetreatHPThreshold then
                task.spawn(doRetreat)
            end
        end
        prevHealth = newHealth
    end)
end

local function disconnectHealthWatch()
    if healthConn then healthConn:Disconnect() healthConn = nil end
end

player.CharacterAdded:Connect(function()
    task.wait(1)
    if autoRetreat then connectHealthWatch() end
end)

-- ================================================
-- ✅ ESP — same width 4.8, height increased to 8.5
-- HP bar height also 8.5 to match box
-- ================================================

local espFolder = Instance.new("Folder")
espFolder.Name   = "ESPFolder"
espFolder.Parent = game.CoreGui

local function getHPColor(pct)
    if pct > 0.6 then return Color3.fromRGB(0, 220, 80)
    elseif pct > 0.3 then return Color3.fromRGB(255, 200, 0)
    else return Color3.fromRGB(220, 40, 40) end
end

local function removeESP(name)
    local d = espData[name]
    if not d then return end
    if d.boxBB   and d.boxBB.Parent   then d.boxBB:Destroy()   end
    if d.nameBB  and d.nameBB.Parent  then d.nameBB:Destroy()  end
    if d.hpBB    and d.hpBB.Parent    then d.hpBB:Destroy()    end
    if d.hpNumBB and d.hpNumBB.Parent then d.hpNumBB:Destroy() end
    if d.charConn then d.charConn:Disconnect() end
    if d.hpConn   then d.hpConn:Disconnect()   end
    espData[name] = nil
end

local function applyESP(p, char)
    local prev = espData[p.Name]
    if prev then
        if prev.boxBB   and prev.boxBB.Parent   then prev.boxBB:Destroy()   end
        if prev.nameBB  and prev.nameBB.Parent  then prev.nameBB:Destroy()  end
        if prev.hpBB    and prev.hpBB.Parent    then prev.hpBB:Destroy()    end
        if prev.hpNumBB and prev.hpNumBB.Parent then prev.hpNumBB:Destroy() end
        if prev.hpConn  then prev.hpConn:Disconnect() end
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- ✅ BOX — width kept at 4.8, height increased to 8.5 (taller rectangle)
    local boxBB = Instance.new("BillboardGui")
    boxBB.Name           = "ESP_BOX_" .. p.Name
    boxBB.Adornee        = hrp
    boxBB.AlwaysOnTop    = true
    boxBB.Size           = UDim2.new(4.8, 0, 8.5, 0)  -- ✅ same width, taller
    boxBB.StudsOffset    = Vector3.new(0, 0.6, 0)
    boxBB.SizeOffset     = Vector2.new(0, 0)
    boxBB.LightInfluence = 0
    boxBB.ResetOnSpawn   = false
    boxBB.Parent         = espFolder

    local function mb(sz, pos, col)
        local f = Instance.new("Frame", boxBB)
        f.Size = sz f.Position = pos
        f.BackgroundColor3 = col f.BorderSizePixel = 0
        return f
    end

    local bc  = Color3.fromRGB(255, 50, 50)
    local top = mb(UDim2.new(1,0,0,1), UDim2.new(0,0,0,0),  bc)
    local bot = mb(UDim2.new(1,0,0,1), UDim2.new(0,0,1,-1), bc)
    local lft = mb(UDim2.new(0,1,1,0), UDim2.new(0,0,0,0),  bc)
    local rgt = mb(UDim2.new(0,1,1,0), UDim2.new(1,-1,0,0), bc)

    -- ✅ NAME — above box, StudsOffset raised to match taller box
    local nameBB = Instance.new("BillboardGui")
    nameBB.Name           = "ESP_NAME_" .. p.Name
    nameBB.Adornee        = hrp
    nameBB.AlwaysOnTop    = true
    nameBB.Size           = UDim2.new(0, 90, 0, 16)
    nameBB.StudsOffset    = Vector3.new(0, 5.0, 0)  -- ✅ raised to clear taller box top
    nameBB.LightInfluence = 0
    nameBB.ResetOnSpawn   = false
    nameBB.Parent         = espFolder

    local nameL = Instance.new("TextLabel", nameBB)
    nameL.Size                   = UDim2.new(1, 0, 1, 0)
    nameL.BackgroundTransparency = 1
    nameL.TextColor3             = Color3.fromRGB(255, 255, 255)
    nameL.TextStrokeTransparency = 0.2
    nameL.TextStrokeColor3       = Color3.new(0, 0, 0)
    nameL.Font                   = Enum.Font.GothamBold
    nameL.TextSize               = 11
    nameL.Text                   = p.Name
    nameL.TextXAlignment         = Enum.TextXAlignment.Center

    -- ✅ HP BAR — width 0.35, height 8.5 matching box, shrinks with distance
    local hpBB = Instance.new("BillboardGui")
    hpBB.Name           = "ESP_HP_" .. p.Name
    hpBB.Adornee        = hrp
    hpBB.AlwaysOnTop    = true
    hpBB.Size           = UDim2.new(0.35, 0, 8.5, 0)  -- ✅ height matches box
    hpBB.StudsOffset    = Vector3.new(-2.9, 0.6, 0)
    hpBB.LightInfluence = 0
    hpBB.ResetOnSpawn   = false
    hpBB.Parent         = espFolder

    local hpBg = Instance.new("Frame", hpBB)
    hpBg.Size             = UDim2.new(1, 0, 1, 0)
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hpBg.BorderSizePixel  = 0
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 2)

    local hpFill = Instance.new("Frame", hpBg)
    hpFill.AnchorPoint      = Vector2.new(0, 1)
    hpFill.Size             = UDim2.new(1, 0, 1, 0)
    hpFill.Position         = UDim2.new(0, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 220, 80)
    hpFill.BorderSizePixel  = 0
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 2)

    -- ✅ HP NUMBER — studs, shrinks with distance, below bar
    local hpNumBB = Instance.new("BillboardGui")
    hpNumBB.Name           = "ESP_HPNUM_" .. p.Name
    hpNumBB.Adornee        = hrp
    hpNumBB.AlwaysOnTop    = true
    hpNumBB.Size           = UDim2.new(1.8, 0, 0.65, 0)
    hpNumBB.StudsOffset    = Vector3.new(-2.7, -4.0, 0)  -- ✅ lowered to match taller bar
    hpNumBB.LightInfluence = 0
    hpNumBB.ResetOnSpawn   = false
    hpNumBB.Parent         = espFolder

    local hpNumL = Instance.new("TextLabel", hpNumBB)
    hpNumL.Size                   = UDim2.new(1, 0, 1, 0)
    hpNumL.BackgroundTransparency = 1
    hpNumL.TextColor3             = Color3.fromRGB(220, 220, 220)
    hpNumL.TextStrokeTransparency = 0.3
    hpNumL.TextStrokeColor3       = Color3.new(0, 0, 0)
    hpNumL.Font                   = Enum.Font.Gotham
    hpNumL.TextScaled             = true
    hpNumL.Text                   = "?"
    hpNumL.TextXAlignment         = Enum.TextXAlignment.Center

    local function updateHP()
        local maxHp = math.max(hum.MaxHealth, 1)
        local curHp = math.clamp(hum.Health, 0, maxHp)
        local pct   = curHp / maxHp
        local col   = getHPColor(pct)
        hpFill.Size             = UDim2.new(1, 0, pct, 0)
        hpFill.BackgroundColor3 = col
        hpNumL.Text             = math.floor(curHp) .. " HP"
        hpNumL.TextColor3       = col
        top.BackgroundColor3 = col
        bot.BackgroundColor3 = col
        lft.BackgroundColor3 = col
        rgt.BackgroundColor3 = col
    end

    updateHP()
    local hpConn = hum:GetPropertyChangedSignal("Health"):Connect(updateHP)

    local existing   = espData[p.Name] or {}
    existing.boxBB   = boxBB
    existing.nameBB  = nameBB
    existing.hpBB    = hpBB
    existing.hpNumBB = hpNumBB
    existing.hpConn  = hpConn
    espData[p.Name]  = existing
end

local function setupESP(p)
    if p == player then return end
    if p.Character then applyESP(p, p.Character) end
    local charConn = p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if espEnabled then applyESP(p, char) end
    end)
    local d = espData[p.Name] or {}
    d.charConn    = charConn
    espData[p.Name] = d
end

local function enableESP()
    espEnabled = true
    for _, p in ipairs(Players:GetPlayers()) do setupESP(p) end
end

local function disableESP()
    espEnabled = false
    for name in pairs(espData) do removeESP(name) end
end

Players.PlayerAdded:Connect(function(p)
    if espEnabled then setupESP(p) end
end)
Players.PlayerRemoving:Connect(function(p)
    removeESP(p.Name)
end)

-- ================================================
-- GUI
-- ================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "CrazyWarGangScript"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size             = UDim2.new(0, 255, 0, 460)
Frame.Position         = UDim2.new(0, 16, 0.5, -230)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.BorderSizePixel  = 0
Frame.Active           = true
Frame.Draggable        = true
Frame.ClipsDescendants = true
Frame.Parent           = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local Strip = Instance.new("Frame", Frame)
Strip.Size             = UDim2.new(1, 0, 0, 3)
Strip.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
Strip.BorderSizePixel  = 0
local sg = Instance.new("UIGradient", Strip)
sg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(220,50,50)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,120,0)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(220,50,50)),
})

local TitleBar = Instance.new("Frame", Frame)
TitleBar.Size             = UDim2.new(1, 0, 0, 34)
TitleBar.Position         = UDim2.new(0, 0, 0, 3)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
TitleBar.BorderSizePixel  = 0

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size               = UDim2.new(1,-66,1,0)
TitleLabel.Position           = UDim2.new(0,10,0,0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3         = Color3.fromRGB(240,240,240)
TitleLabel.Text               = "⚔️ Crazy War Gang"
TitleLabel.Font               = Enum.Font.GothamBold
TitleLabel.TextSize           = 11
TitleLabel.TextXAlignment     = Enum.TextXAlignment.Left

local MinimizeBtn = Instance.new("TextButton", TitleBar)
MinimizeBtn.Size             = UDim2.new(0,22,0,22)
MinimizeBtn.Position         = UDim2.new(1,-52,0.5,-11)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200,160,0)
MinimizeBtn.TextColor3       = Color3.fromRGB(255,255,255)
MinimizeBtn.Text             = "—"
MinimizeBtn.Font             = Enum.Font.GothamBold
MinimizeBtn.TextSize         = 11
MinimizeBtn.BorderSizePixel  = 0
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(1,0)

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size             = UDim2.new(0,22,0,22)
CloseBtn.Position         = UDim2.new(1,-26,0.5,-11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
CloseBtn.TextColor3       = Color3.fromRGB(255,255,255)
CloseBtn.Text             = "✕"
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.TextSize         = 11
CloseBtn.BorderSizePixel  = 0
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1,0)

local Content = Instance.new("Frame", Frame)
Content.Name                = "Content"
Content.Size                = UDim2.new(1,0,1,-40)
Content.Position            = UDim2.new(0,0,0,40)
Content.BackgroundTransparency = 1

local TabBar = Instance.new("Frame", Content)
TabBar.Size             = UDim2.new(1,-12,0,24)
TabBar.Position         = UDim2.new(0,6,0,3)
TabBar.BackgroundColor3 = Color3.fromRGB(28,28,28)
TabBar.BorderSizePixel  = 0
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0,7)

local function makeTabBtn(text, idx)
    local b = Instance.new("TextButton", TabBar)
    b.Size             = UDim2.new(0.25,-3,1,-6)
    b.Position         = UDim2.new(0.25*(idx-1),2,0,3)
    b.BackgroundColor3 = Color3.fromRGB(36,36,36)
    b.TextColor3       = Color3.fromRGB(140,140,140)
    b.Text             = text
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 8
    b.BorderSizePixel  = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    return b
end

local Tab1Btn = makeTabBtn("🍳Cook",  1)
local Tab2Btn = makeTabBtn("🌍World", 2)
local Tab3Btn = makeTabBtn("🔫Shop",  3)
local Tab4Btn = makeTabBtn("🔧Tools", 4)

local function makePage()
    local p = Instance.new("ScrollingFrame", Content)
    p.Size                  = UDim2.new(1,0,1,-32)
    p.Position              = UDim2.new(0,0,0,32)
    p.BackgroundTransparency = 1
    p.BorderSizePixel       = 0
    p.ScrollBarThickness    = 2
    p.ScrollBarImageColor3  = Color3.fromRGB(60,60,60)
    p.CanvasSize            = UDim2.new(0,0,0,500)
    p.Visible               = false
    return p
end

local Page1 = makePage() Page1.Visible = true
local Page2 = makePage()
local Page3 = makePage()
local Page4 = makePage()

local function btn(parent, text, yPos, color)
    local b = Instance.new("TextButton", parent)
    b.Size             = UDim2.new(1,-12,0,30)
    b.Position         = UDim2.new(0,6,0,yPos)
    b.BackgroundColor3 = color
    b.TextColor3       = Color3.fromRGB(255,255,255)
    b.Text             = text
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 10
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.07,Enum.EasingStyle.Quad),{
            Size=UDim2.new(1,-18,0,27),Position=UDim2.new(0,9,0,yPos+2),
        }):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.1,Enum.EasingStyle.Quad),{
            Size=UDim2.new(1,-12,0,30),Position=UDim2.new(0,6,0,yPos),
        }):Play()
    end)
    return b
end

local function lbl(parent, text, yPos, color)
    local l = Instance.new("TextLabel", parent)
    l.Size=UDim2.new(1,-12,0,14) l.Position=UDim2.new(0,6,0,yPos)
    l.BackgroundTransparency=1
    l.TextColor3=color or Color3.fromRGB(110,110,110)
    l.Text=text l.Font=Enum.Font.Gotham l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left
    return l
end

local function sep(parent, yPos)
    local s = Instance.new("Frame", parent)
    s.Size=UDim2.new(1,-12,0,1) s.Position=UDim2.new(0,6,0,yPos)
    s.BackgroundColor3=Color3.fromRGB(38,38,38) s.BorderSizePixel=0
end

local function sHdr(parent, text, yPos)
    local l = Instance.new("TextLabel", parent)
    l.Size=UDim2.new(1,-12,0,16) l.Position=UDim2.new(0,6,0,yPos)
    l.BackgroundTransparency=1
    l.TextColor3=Color3.fromRGB(190,190,190)
    l.Text=text l.Font=Enum.Font.GothamBold l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left
end

local function dotCard(parent, emoji, label, yPos, color)
    local box = Instance.new("Frame", parent)
    box.Size=UDim2.new(1,-12,0,32) box.Position=UDim2.new(0,6,0,yPos)
    box.BackgroundColor3=Color3.fromRGB(26,26,26) box.BorderSizePixel=0
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,7)

    local il = Instance.new("TextLabel", box)
    il.Size=UDim2.new(0,24,1,0) il.Position=UDim2.new(0,4,0,0)
    il.BackgroundTransparency=1 il.Text=emoji
    il.Font=Enum.Font.GothamBold il.TextSize=15

    local nl = Instance.new("TextLabel", box)
    nl.Size=UDim2.new(1,-88,1,0) nl.Position=UDim2.new(0,30,0,0)
    nl.BackgroundTransparency=1 nl.TextColor3=Color3.fromRGB(210,210,210)
    nl.Text=label nl.Font=Enum.Font.Gotham nl.TextSize=9
    nl.TextXAlignment=Enum.TextXAlignment.Left

    local barBg = Instance.new("Frame", box)
    barBg.Size=UDim2.new(0,54,0,4) barBg.Position=UDim2.new(1,-62,0.5,-2)
    barBg.BackgroundColor3=Color3.fromRGB(35,35,35) barBg.BorderSizePixel=0
    Instance.new("UICorner",barBg).CornerRadius=UDim.new(1,0)

    local barFill = Instance.new("Frame", barBg)
    barFill.Size=UDim2.new(0,0,1,0)
    barFill.BackgroundColor3=color barFill.BorderSizePixel=0
    Instance.new("UICorner",barFill).CornerRadius=UDim.new(1,0)

    local dot = Instance.new("Frame", box)
    dot.Size=UDim2.new(0,8,0,8) dot.Position=UDim2.new(1,-12,0.5,-4)
    dot.BackgroundColor3=Color3.fromRGB(44,44,44) dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

    return dot, barFill
end

-- ================================================
-- PAGE 1 — COOK
-- ================================================

local dotWater,   fillWater   = dotCard(Page1,"💧",cfg.Water,   4,  Color3.fromRGB(40,120,255))
local dotSugar,   fillSugar   = dotCard(Page1,"🍬",cfg.Sugar,   42, Color3.fromRGB(255,160,0))
local dotGelatin, fillGelatin = dotCard(Page1,"🧪",cfg.Gelatin, 80, Color3.fromRGB(180,60,220))
local dotBag,     fillBag     = dotCard(Page1,"👜",cfg.Bag,     118,Color3.fromRGB(60,180,80))

local TimerBg = Instance.new("Frame",Page1)
TimerBg.Size=UDim2.new(1,-12,0,6) TimerBg.Position=UDim2.new(0,6,0,158)
TimerBg.BackgroundColor3=Color3.fromRGB(28,28,28) TimerBg.BorderSizePixel=0
Instance.new("UICorner",TimerBg).CornerRadius=UDim.new(0,3)

local TimerFill = Instance.new("Frame",TimerBg)
TimerFill.Size=UDim2.new(0,0,1,0)
TimerFill.BackgroundColor3=Color3.fromRGB(0,200,120) TimerFill.BorderSizePixel=0
Instance.new("UICorner",TimerFill).CornerRadius=UDim.new(0,3)

local TimerText = Instance.new("TextLabel",TimerBg)
TimerText.Size=UDim2.new(1,0,1,0) TimerText.BackgroundTransparency=1
TimerText.TextColor3=Color3.fromRGB(255,255,255) TimerText.Text=""
TimerText.Font=Enum.Font.GothamBold TimerText.TextSize=7

local StatusLabel    = lbl(Page1,"Idle",         168,Color3.fromRGB(120,120,120))
local CookCountLabel = lbl(Page1,"🍬 Cooked: 0", 183,Color3.fromRGB(140,140,140))
sep(Page1,200)
local LoopBtn = btn(Page1,"🔁 Loop Cook: OFF",206,Color3.fromRGB(44,44,44))
local CookBtn = btn(Page1,"🍳 Start Cooking", 242,Color3.fromRGB(40,155,70))
sep(Page1,278)
local MyHpLabel = lbl(Page1,"❤️ HP: ?",         282,Color3.fromRGB(200,80,80))
lbl(Page1,            "🛡️ Anti-AFK: Active",    296,Color3.fromRGB(0,180,80))
sep(Page1,314)
sHdr(Page1,"🍡 Marshmallow Bags",318)
local LargeMarshmallowLabel  = lbl(Page1,"🟠 Large:  0",336,Color3.fromRGB(255,140,40))
local MediumMarshmallowLabel = lbl(Page1,"🟡 Medium: 0",352,Color3.fromRGB(220,200,40))
local SmallMarshmallowLabel  = lbl(Page1,"⚪ Small:  0",368,Color3.fromRGB(180,180,180))
Page1.CanvasSize = UDim2.new(0,0,0,390)

-- PAGE 2 — WORLD
sHdr(Page2,"📍 Lamont Bell",4)
local VehicleStatus  = lbl(Page2,"🏍️ Not detected",22,Color3.fromRGB(200,80,80))
local TeleportBtn    = btn(Page2,"🏍️ Teleport → Lamont Bell",38,Color3.fromRGB(100,50,200))
local TeleportStatus = lbl(Page2,"Ready",72,Color3.fromRGB(110,110,110))
sep(Page2,90)
sHdr(Page2,"🏍️ Teleport Ds",94)
local SellBtn    = btn(Page2,"🏍️ Teleport Ds",      112,Color3.fromRGB(180,100,0))
local SellStatus = lbl(Page2,"Must be on DirtBike",146,Color3.fromRGB(110,110,110))
sep(Page2,164)
sHdr(Page2,"🏠 Home System",168)
local HomeStatus = lbl(Page2,"Home: Not set", 186,Color3.fromRGB(200,80,80))
local SetHomeBtn = btn(Page2,"📌 Set Home",   202,Color3.fromRGB(50,100,200))
local GoHomeBtn  = btn(Page2,"🏠 Go Home",    238,Color3.fromRGB(44,44,44))
Page2.CanvasSize = UDim2.new(0,0,0,280)

-- PAGE 3 — GUN SHOP
sHdr(Page3,"🔫 Gun Shop Teleports",4)
sep(Page3,24)
lbl(Page3,"📍 GS Mid: 160.86, 4.67, -188.50",30)
local GsMidBtn    = btn(Page3,"🏍️ GS Mid",46, Color3.fromRGB(50,100,200))
local GsMidStatus = lbl(Page3,"Ready",     80, Color3.fromRGB(110,110,110))
sep(Page3,98)
lbl(Page3,"📍 GS End: -465.51, 4.80, 360.13",104)
local GsEndBtn    = btn(Page3,"🏍️ GS End",120,Color3.fromRGB(180,50,50))
local GsEndStatus = lbl(Page3,"Ready",     154,Color3.fromRGB(110,110,110))
Page3.CanvasSize = UDim2.new(0,0,0,180)

-- PAGE 4 — ESP + AUTO JAIL
sHdr(Page4,"👁️ ESP System",4)
lbl(Page4,"Box+HP+Name | Through walls | Scales dist",22,Color3.fromRGB(100,100,100))
lbl(Page4,"🟢 Full  🟡 Half  🔴 Dying",38,Color3.fromRGB(90,90,90))
local ESPBtn = btn(Page4,"👁️ ESP: OFF",56,Color3.fromRGB(44,44,44))
sep(Page4,94)
sHdr(Page4,"🚔 Auto Jail",98)
lbl(Page4,"HP < 50% → jail → home",116,Color3.fromRGB(100,100,100))
local RetreatStatus = lbl(Page4,"Auto Jail: OFF",   132,Color3.fromRGB(110,110,110))
local RetreatBtn    = btn(Page4,"🚔 Auto Jail: OFF",148,Color3.fromRGB(44,44,44))
Page4.CanvasSize = UDim2.new(0,0,0,200)

-- MINIMIZE
local FULL_H = 460
local MINI_H = 40

local function setMinimized(minimize)
    isMinimized = minimize
    TweenService:Create(Frame,TweenInfo.new(0.3,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
        Size=minimize and UDim2.new(0,255,0,MINI_H) or UDim2.new(0,255,0,FULL_H)
    }):Play()
    if minimize then
        task.delay(0.3,function() Content.Visible=false end)
        MinimizeBtn.Text="▢" MinimizeBtn.BackgroundColor3=Color3.fromRGB(0,150,70)
    else
        Content.Visible=true
        MinimizeBtn.Text="—" MinimizeBtn.BackgroundColor3=Color3.fromRGB(200,160,0)
    end
end

MinimizeBtn.MouseButton1Click:Connect(function() setMinimized(not isMinimized) end)

-- PAGE SWITCH
local TAB_ACTIVE={
    Color3.fromRGB(40,155,70),Color3.fromRGB(100,50,200),
    Color3.fromRGB(180,50,50),Color3.fromRGB(180,120,0),
}

local function setPage(n)
    currentPage=n
    Page1.Visible=n==1 Page2.Visible=n==2
    Page3.Visible=n==3 Page4.Visible=n==4
    local tabs={Tab1Btn,Tab2Btn,Tab3Btn,Tab4Btn}
    for i,t in ipairs(tabs) do
        TweenService:Create(t,TweenInfo.new(0.15),{
            BackgroundColor3=i==n and TAB_ACTIVE[i] or Color3.fromRGB(36,36,36),
            TextColor3=i==n and Color3.fromRGB(255,255,255) or Color3.fromRGB(130,130,130),
        }):Play()
    end
end

Tab1Btn.MouseButton1Click:Connect(function() setPage(1) end)
Tab2Btn.MouseButton1Click:Connect(function() setPage(2) end)
Tab3Btn.MouseButton1Click:Connect(function() setPage(3) end)
Tab4Btn.MouseButton1Click:Connect(function() setPage(4) end)
setPage(1)

CloseBtn.MouseButton1Click:Connect(function()
    autoRetreat=false disconnectHealthWatch() disableESP() releaseE() ScreenGui:Destroy()
end)

-- COOK LOGIC
local dotColors={
    idle=Color3.fromRGB(44,44,44),active=Color3.fromRGB(255,200,0),
    done=Color3.fromRGB(0,200,100),error=Color3.fromRGB(220,50,50),
}

local function setDot(d,s)
    TweenService:Create(d,TweenInfo.new(0.15),{BackgroundColor3=dotColors[s] or dotColors.idle}):Play()
end

local function resetAll()
    for _,d in ipairs({dotWater,dotSugar,dotGelatin,dotBag}) do setDot(d,"idle") end
    for _,f in ipairs({fillWater,fillSugar,fillGelatin,fillBag}) do f.Size=UDim2.new(0,0,1,0) end
    TimerFill.Size=UDim2.new(0,0,1,0) TimerText.Text=""
end

local function runTimer(seconds,color,cardFill,label)
    TimerFill.BackgroundColor3=color
    local start=tick()
    while tick()-start<seconds do
        if not isCooking then break end
        local p=math.min((tick()-start)/seconds,1)
        TimerFill.Size=UDim2.new(p,0,1,0)
        cardFill.Size=UDim2.new(p,0,1,0)
        TimerText.Text=label.." "..math.ceil(seconds-(tick()-start)).."s"
        task.wait(0.05)
    end
    TimerFill.Size=UDim2.new(0,0,1,0) TimerText.Text="" cardFill.Size=UDim2.new(1,0,1,0)
end

local function cookOnce()
    resetAll()
    local function step(toolName,dot,fill,color,label,holdTime,pressOnly)
        StatusLabel.Text="🔄 "..toolName.."..." StatusLabel.TextColor3=Color3.fromRGB(100,140,255)
        if not pressOnly then releaseE() end
        if not switchTool(toolName) then
            setDot(dot,"error") StatusLabel.Text="❌ "..toolName.." not found" isCooking=false return false
        end
        task.wait(pressOnly and 0.2 or 0.3) setDot(dot,"active")
        StatusLabel.Text=label StatusLabel.TextColor3=color
        if pressOnly then
            pressE() fill.Size=UDim2.new(1,0,1,0) setDot(dot,"done") task.wait(0.3)
        else
            task.spawn(function() holdE(holdTime) end)
            runTimer(holdTime,color,fill,label)
            if not isCooking then return false end
            if holdTime==cfg.WaterTime then releaseE() end
            setDot(dot,"done") task.wait(0.2)
        end
        return true
    end

    if not step(cfg.Water,  dotWater,  fillWater,  Color3.fromRGB(40,140,255),"💧 "..cfg.WaterTime.."s",   cfg.WaterTime,  false) then return end
    if not step(cfg.Sugar,  dotSugar,  fillSugar,  Color3.fromRGB(255,170,0), "🍬 inserting...",            0,              true)  then return end
    if not step(cfg.Gelatin,dotGelatin,fillGelatin,Color3.fromRGB(180,70,220),"🧪 "..cfg.GelatinTime.."s", cfg.GelatinTime,false) then return end
    task.wait(0.3)
    if not step(cfg.Bag,    dotBag,    fillBag,    Color3.fromRGB(60,200,80), "👜 "..cfg.BagTime.."s",      cfg.BagTime,    false) then return end
    releaseE()

    cookCount=cookCount+1
    CookCountLabel.Text="🍬 Cooked: "..cookCount
    StatusLabel.Text="✅ Batch "..cookCount.." done!" StatusLabel.TextColor3=Color3.fromRGB(0,220,120)
    task.wait(0.6)
end

local function startCooking()
    if isCooking then return end
    isCooking=true
    CookBtn.Text="⏹️ Stop Cooking" CookBtn.BackgroundColor3=Color3.fromRGB(180,40,40)
    repeat
        cookOnce()
        if isCooking and isLooping then StatusLabel.Text="🔁 Next batch..." task.wait(1.0) end
    until not isCooking or not isLooping
    if isCooking then StatusLabel.Text="✅ Done! "..cookCount.." cooked" StatusLabel.TextColor3=Color3.fromRGB(0,220,120) end
    isCooking=false
    CookBtn.Text="🍳 Start Cooking" CookBtn.BackgroundColor3=Color3.fromRGB(40,155,70)
end

local function stopCooking()
    isCooking=false releaseE() resetAll()
    StatusLabel.Text="Stopped" StatusLabel.TextColor3=Color3.fromRGB(200,80,80)
    CookBtn.Text="🍳 Start Cooking" CookBtn.BackgroundColor3=Color3.fromRGB(40,155,70)
end

-- HEARTBEAT
RunService.Heartbeat:Connect(function()
    local v=getVehicle()
    if v then
        VehicleStatus.Text="🏍️ "..v.Name.." ✅" VehicleStatus.TextColor3=Color3.fromRGB(0,210,100)
    else
        VehicleStatus.Text="🏍️ Not detected ❌" VehicleStatus.TextColor3=Color3.fromRGB(200,80,80)
    end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local pct=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
        local col=pct>0.6 and Color3.fromRGB(0,210,80) or pct>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(220,50,50)
        MyHpLabel.Text=string.format("❤️ HP: %d/%d (%.0f%%)",math.floor(hum.Health),math.floor(hum.MaxHealth),pct*100)
        MyHpLabel.TextColor3=col
    end
    local bp=player:FindFirstChild("Backpack")
    local ch=player.Character
    local large,medium,small=0,0,0
    if bp then
        for _,v in ipairs(bp:GetChildren()) do
            if v.Name=="Large Marshmallow Bag"  then large+=1  end
            if v.Name=="Medium Marshmallow Bag" then medium+=1 end
            if v.Name=="Small Marshmallow Bag"  then small+=1  end
        end
    end
    if ch then
        for _,v in ipairs(ch:GetChildren()) do
            if v.Name=="Large Marshmallow Bag"  then large+=1  end
            if v.Name=="Medium Marshmallow Bag" then medium+=1 end
            if v.Name=="Small Marshmallow Bag"  then small+=1  end
        end
    end
    LargeMarshmallowLabel.Text  ="🟠 Large:  "..large
    MediumMarshmallowLabel.Text ="🟡 Medium: "..medium
    SmallMarshmallowLabel.Text  ="⚪ Small:  "..small
end)

-- BUTTONS
CookBtn.MouseButton1Click:Connect(function()
    if isCooking then stopCooking() else task.spawn(startCooking) end
end)
LoopBtn.MouseButton1Click:Connect(function()
    isLooping=not isLooping
    LoopBtn.Text=isLooping and "🔁 Loop: ON" or "🔁 Loop Cook: OFF"
    LoopBtn.BackgroundColor3=isLooping and Color3.fromRGB(0,130,60) or Color3.fromRGB(44,44,44)
end)
TeleportBtn.MouseButton1Click:Connect(function()
    if isTeleporting then return end
    isTeleporting=true
    TeleportBtn.Text="⏳ Teleporting..." TeleportBtn.BackgroundColor3=Color3.fromRGB(55,55,55)
    TeleportStatus.Text="Teleporting..." TeleportStatus.TextColor3=Color3.fromRGB(160,100,255)
    local _,mode=teleportWithVehicle(cfg.TeleportPos)
    TeleportStatus.Text=mode=="vehicle" and "✅ Arrived!" or "✅ Done!"
    TeleportStatus.TextColor3=Color3.fromRGB(0,220,100)
    TeleportBtn.Text="🏍️ Teleport → Lamont Bell" TeleportBtn.BackgroundColor3=Color3.fromRGB(100,50,200)
    isTeleporting=false
end)
SellBtn.MouseButton1Click:Connect(function()
    SellBtn.Text="⏳ Teleporting..." SellBtn.BackgroundColor3=Color3.fromRGB(55,55,55)
    local ok,msg=teleportDs()
    SellStatus.Text=ok and "✅ Done!" or ("❌ "..(msg or "Must be on DirtBike"))
    SellStatus.TextColor3=ok and Color3.fromRGB(0,220,100) or Color3.fromRGB(220,50,50)
    SellBtn.Text="🏍️ Teleport Ds" SellBtn.BackgroundColor3=Color3.fromRGB(180,100,0)
end)
SetHomeBtn.MouseButton1Click:Connect(function()
    local char=player.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    cfg.HomePos=hrp.Position
    HomeStatus.Text=string.format("📌 %.1f, %.1f, %.1f",hrp.Position.X,hrp.Position.Y,hrp.Position.Z)
    HomeStatus.TextColor3=Color3.fromRGB(0,200,100)
    GoHomeBtn.BackgroundColor3=Color3.fromRGB(0,120,60)
end)
GoHomeBtn.MouseButton1Click:Connect(function()
    if not cfg.HomePos then HomeStatus.Text="❌ Set home first!" HomeStatus.TextColor3=Color3.fromRGB(220,50,50) return end
    teleportWithVehicle(cfg.HomePos)
end)
GsMidBtn.MouseButton1Click:Connect(function()
    GsMidBtn.Text="⏳ Teleporting..." GsMidBtn.BackgroundColor3=Color3.fromRGB(55,55,55)
    local _,mode=teleportWithVehicle(cfg.GsMidPos)
    GsMidStatus.Text=mode=="vehicle" and "✅ GS Mid!" or "✅ Done!"
    GsMidStatus.TextColor3=Color3.fromRGB(0,220,100)
    GsMidBtn.Text="🏍️ GS Mid" GsMidBtn.BackgroundColor3=Color3.fromRGB(50,100,200)
end)
GsEndBtn.MouseButton1Click:Connect(function()
    GsEndBtn.Text="⏳ Teleporting..." GsEndBtn.BackgroundColor3=Color3.fromRGB(55,55,55)
    local _,mode=teleportWithVehicle(cfg.GsEndPos)
    GsEndStatus.Text=mode=="vehicle" and "✅ GS End!" or "✅ Done!"
    GsEndStatus.TextColor3=Color3.fromRGB(0,220,100)
    GsEndBtn.Text="🏍️ GS End" GsEndBtn.BackgroundColor3=Color3.fromRGB(180,50,50)
end)
RetreatBtn.MouseButton1Click:Connect(function()
    autoRetreat=not autoRetreat
    if autoRetreat then
        RetreatBtn.Text="🚔 Auto Jail: ON" RetreatBtn.BackgroundColor3=Color3.fromRGB(180,30,30)
        RetreatStatus.Text="Watching HP (< 50%)..." RetreatStatus.TextColor3=Color3.fromRGB(220,80,80)
        connectHealthWatch()
    else
        RetreatBtn.Text="🚔 Auto Jail: OFF" RetreatBtn.BackgroundColor3=Color3.fromRGB(44,44,44)
        RetreatStatus.Text="Auto Jail: OFF" RetreatStatus.TextColor3=Color3.fromRGB(110,110,110)
        disconnectHealthWatch()
    end
end)
ESPBtn.MouseButton1Click:Connect(function()
    if espEnabled then
        disableESP()
        ESPBtn.Text="👁️ ESP: OFF" ESPBtn.BackgroundColor3=Color3.fromRGB(44,44,44)
    else
        enableESP()
        ESPBtn.Text="👁️ ESP: ON" ESPBtn.BackgroundColor3=Color3.fromRGB(180,40,40)
    end
end)
