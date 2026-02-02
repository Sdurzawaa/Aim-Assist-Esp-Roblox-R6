--[[
    ═══════════════════════════════════════════════════════════
    CAMERA ASSIST + ESP FRAMEWORK - MODERN EDITION
    Version: 2.3
    Author: Enhanced & Optimized
    
    Purpose: Educational framework with modern tabbed UI
    License: MIT
    
    NEW FEATURES:
    - Modern tabbed interface (Combat | Visual | Settings)
    - Separate combat controls for aim assist
    - Dedicated ESP/Visual tab
    - Improved color scheme
    - Better organization
    - Press RightShift to toggle UI
    ═══════════════════════════════════════════════════════════
]]

-- ============================================================
-- SERVICES & DEPENDENCIES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ============================================================
-- CORE REFERENCES
-- ============================================================
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- CONFIGURATION SYSTEM
-- ============================================================
local Config = {
    -- System Settings
    Version = "5.0",
    Name = "Combat Assist Pro",
    
    -- Camera Settings
    Smoothness = 0.35,
    FOVRadius = 120,
    ShowFOV = true,
    
    -- Target Filtering
    IgnoreDead = true,
    IgnoreTeam = true,
    CheckWalls = true,
    
    -- Aim Mode Settings
    AimMode = "Priority Part",
    TargetPart = "Head",
    
    -- Priority Part Settings
    PriorityParts = {
        "Head",
        "UpperTorso",
        "Torso",
        "HumanoidRootPart",
        "LowerTorso"
    },
    
    -- ESP Master Toggle
    ESPEnabled = true,
    
    -- ESP Individual Toggles
    ESPBoxEnabled = true,
    ESPNameEnabled = true,
    ESPHighlightEnabled = true,
    ESPHealthBar = true,
    ESPDistance = true,
    ESPTracers = false,
    
    -- ESP Colors
    FriendColor = Color3.fromRGB(0, 255, 0),
    EnemyColor = Color3.fromRGB(255, 0, 0),
    UseTeamColor = true,
    ESPTransparency = 0.5,
    BoxTransparency = 0.7,
    
    -- Visual Settings
    FOVColor = Color3.fromRGB(120, 160, 255),
    FOVThickness = 2.5,
    FOVTransparency = 0.3,
    TracerColor = Color3.fromRGB(255, 255, 255),
    TracerThickness = 1.5,
    
    -- Modern UI Theme
    Theme = {
        -- Dark mode colors
        Background = Color3.fromRGB(20, 20, 25),
        Surface = Color3.fromRGB(28, 28, 35),
        SurfaceLight = Color3.fromRGB(35, 35, 42),
        
        -- Accent colors
        Primary = Color3.fromRGB(88, 101, 242),
        PrimaryHover = Color3.fromRGB(71, 82, 196),
        Success = Color3.fromRGB(67, 181, 129),
        Danger = Color3.fromRGB(237, 66, 69),
        Warning = Color3.fromRGB(250, 166, 26),
        
        -- Text colors
        Text = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(180, 185, 200),
        TextMuted = Color3.fromRGB(120, 125, 140),
        
        -- Border & Shadow
        Border = Color3.fromRGB(45, 47, 55),
        BorderLight = Color3.fromRGB(60, 62, 70),
        Shadow = Color3.fromRGB(0, 0, 0),
        
        -- Tab colors
        TabActive = Color3.fromRGB(88, 101, 242),
        TabInactive = Color3.fromRGB(45, 47, 55),
    },
    
    -- System State
    Active = false,
    UIVisible = true,
    CurrentTab = "Combat",
    
    -- Auto Mouse Lock Settings
    AutoMouseLock = true,
    ManualMouseLock = false,
}

-- ============================================================
-- STATE MANAGEMENT
-- ============================================================
local State = {
    Connections = {},
    CurrentTarget = nil,
    FOVCircle = nil,
    TargetIndicator = nil,
    Tracers = {},
    LastUpdate = tick(),
    OpenDropdowns = {},
    Performance = {
        FPS = 60,
        TargetCount = 0,
    },
    -- Mouse State
    IsInGame = false,
    IsInLobby = true,
    MouseLocked = false,
    LastGameStateCheck = 0,
    -- ESP State
    ESPObjects = {},
    ESPUpdateQueue = {},
    LastESPUpdate = 0,
}

-- ============================================================
-- ESP HOLDER
-- ============================================================
local ESPHolder = Instance.new("Folder", game.CoreGui)
ESPHolder.Name = "ESP_Modern"

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local Utils = {}

function Utils.CreateCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

function Utils.CreateStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Config.Theme.Border
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

function Utils.TweenProperty(instance, property, value, duration)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {[property] = value}
    )
    tween:Play()
    return tween
end

function Utils.IsAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

function Utils.IsVisible(targetPosition, targetCharacter)
    if not Config.CheckWalls then return true end
    
    local cameraPosition = Camera.CFrame.Position
    local direction = (targetPosition - cameraPosition)
    local distance = direction.Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
    raycastParams.IgnoreWater = true
    
    local raycastResult = workspace:Raycast(cameraPosition, direction.Unit * distance, raycastParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        if hitPart and hitPart.Parent then
            if hitPart:IsDescendantOf(targetCharacter) then
                return true
            end
            return false
        end
        return false
    end
    
    return true
end

function Utils.GetPriorityPart(player)
    if not player.Character then return nil end
    
    for _, partName in ipairs(Config.PriorityParts) do
        local part = player.Character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                return part
            end
        end
    end
    
    return player.Character:FindFirstChild("HumanoidRootPart") or 
           player.Character:FindFirstChild("Head")
end

function Utils.GetClosestPart(player)
    if not player.Character then return nil end
    
    local closestPart = nil
    local closestDistance = math.huge
    local cameraPosition = Camera.CFrame.Position
    
    local bodyParts = {
        "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
        "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg",
        "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot",
        "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
    }
    
    for _, partName in ipairs(bodyParts) do
        local part = player.Character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local distance = (part.Position - cameraPosition).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestPart = part
            end
        end
    end
    
    return closestPart or player.Character:FindFirstChild("Head")
end

function Utils.GetSpecificPart(player)
    if not player.Character then return nil end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then 
        return player.Character:FindFirstChild(Config.TargetPart) or 
               player.Character:FindFirstChild("Head")
    end
    
    local hipHeight = humanoid.HipHeight
    local targetPart = player.Character:FindFirstChild(Config.TargetPart)
    
    if hipHeight < 1.5 then
        local upperTorso = player.Character:FindFirstChild("UpperTorso")
        local torso = player.Character:FindFirstChild("Torso")
        
        if upperTorso then
            return upperTorso
        elseif torso then
            return torso
        end
    end
    
    return targetPart or player.Character:FindFirstChild("Head")
end

function Utils.GetPartFromPlayer(player)
    if not player.Character then return nil end
    
    if Config.AimMode == "Priority Part" then
        return Utils.GetPriorityPart(player)
    elseif Config.AimMode == "Closest Part" then
        return Utils.GetClosestPart(player)
    else
        return Utils.GetSpecificPart(player)
    end
end

function Utils.GetDistance(player)
    if not player.Character then return 0 end
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return 0 end
    
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return 0 end
    
    return math.floor((rootPart.Position - localRoot.Position).Magnitude)
end

-- ============================================================
-- SMART MOUSE LOCK MANAGER
-- ============================================================
local MouseManager = {}

function MouseManager.DetectGameState()
    local character = LocalPlayer.Character
    
    if not character then
        State.IsInLobby = true
        State.IsInGame = false
        return
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    local canMove = humanoid and humanoid.WalkSpeed > 0
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local hasGameUI = false
    
    if playerGui then
        hasGameUI = playerGui:FindFirstChild("MainGui") or 
                    playerGui:FindFirstChild("GameUI") or
                    playerGui:FindFirstChild("HUD") or
                    playerGui:FindFirstChild("Hotbar")
    end
    
    if humanoid and rootPart and canMove then
        State.IsInGame = true
        State.IsInLobby = false
    else
        State.IsInGame = false
        State.IsInLobby = true
    end
    
    if Camera.CameraType == Enum.CameraType.Custom and humanoid and rootPart then
        if (Camera.CFrame.Position - rootPart.Position).Magnitude < 2 then
            State.IsInGame = true
            State.IsInLobby = false
        end
    end
end

function MouseManager.UpdateMouseLock()
    if Config.ManualMouseLock then
        return
    end
    
    if not Config.AutoMouseLock then
        return
    end
    
    if State.IsInGame and not State.MouseLocked then
        MouseManager.LockMouse()
    elseif State.IsInLobby and State.MouseLocked then
        MouseManager.UnlockMouse()
    end
end

function MouseManager.LockMouse()
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    State.MouseLocked = true
end

function MouseManager.UnlockMouse()
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    State.MouseLocked = false
end

function MouseManager.ToggleManualMouseLock()
    Config.ManualMouseLock = not Config.ManualMouseLock
    
    if Config.ManualMouseLock then
        State.MouseLocked = not State.MouseLocked
        if State.MouseLocked then
            MouseManager.LockMouse()
        else
            MouseManager.UnlockMouse()
        end
    else
        MouseManager.UpdateMouseLock()
    end
end

-- ============================================================
-- ESP SYSTEM
-- ============================================================
local ESPSystem = {}

function ESPSystem.GetESPColor(player)
    if Config.UseTeamColor then
        return player.TeamColor.Color
    else
        if player.Team == LocalPlayer.Team then
            return Config.FriendColor
        else
            return Config.EnemyColor
        end
    end
end

function ESPSystem.CreateESP(player)
    if player == LocalPlayer then return end
    if State.ESPObjects[player.Name] then return end
    
    local espData = {
        Player = player,
        Holder = Instance.new("Folder"),
        Box = nil,
        NameTag = nil,
        Highlight = nil,
        HealthBar = nil,
        Tracer = nil,
        UpdateConnection = nil
    }
    
    espData.Holder.Name = player.Name .. "_ESP"
    espData.Holder.Parent = ESPHolder
    
    -- Create Box
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Box"
    box.Size = Vector3.new(4, 5, 1)
    box.Color3 = ESPSystem.GetESPColor(player)
    box.Transparency = Config.BoxTransparency
    box.ZIndex = 1
    box.AlwaysOnTop = true
    box.Visible = false
    box.Parent = espData.Holder
    espData.Box = box
    
    -- Create NameTag
    local nameTag = Instance.new("BillboardGui")
    nameTag.Name = "NameTag"
    nameTag.Size = UDim2.new(0, 200, 0, 50)
    nameTag.AlwaysOnTop = true
    nameTag.StudsOffset = Vector3.new(0, 3, 0)
    nameTag.Enabled = false
    nameTag.Parent = espData.Holder
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = ESPSystem.GetESPColor(player)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Text = player.Name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = nameTag
    
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "DistanceLabel"
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Position = UDim2.new(0, 0, 0, 20)
    distanceLabel.Size = UDim2.new(1, 0, 0, 16)
    distanceLabel.TextSize = 12
    distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distanceLabel.TextStrokeTransparency = 0.5
    distanceLabel.Text = "0m"
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Parent = nameTag
    
    espData.NameTag = nameTag
    
    -- Create Health Bar (Side)
    local healthBarGui = Instance.new("BillboardGui")
    healthBarGui.Name = "HealthBarSide"
    healthBarGui.Size = UDim2.new(0, 4, 0, 60)
    healthBarGui.AlwaysOnTop = true
    healthBarGui.StudsOffset = Vector3.new(-2.5, 0, 0)
    healthBarGui.Enabled = false
    healthBarGui.Parent = espData.Holder
    
    local healthBG = Instance.new("Frame")
    healthBG.Name = "HealthBG"
    healthBG.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    healthBG.BorderSizePixel = 0
    healthBG.Size = UDim2.new(1, 0, 1, 0)
    healthBG.Parent = healthBarGui
    
    Utils.CreateCorner(healthBG, 2)
    Utils.CreateStroke(healthBG, Color3.fromRGB(255, 255, 255), 1)
    
    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthFill.BorderSizePixel = 0
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.Position = UDim2.new(0, 0, 1, 0)
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.Parent = healthBG
    
    Utils.CreateCorner(healthFill, 2)
    
    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.BackgroundTransparency = 1
    healthText.Position = UDim2.new(0, -20, 1, 5)
    healthText.Size = UDim2.new(0, 50, 0, 14)
    healthText.TextSize = 10
    healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthText.TextStrokeTransparency = 0.5
    healthText.Text = "100"
    healthText.Font = Enum.Font.GothamBold
    healthText.Parent = healthBarGui
    
    espData.HealthBar = healthBarGui
    
    -- Create Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "Highlight"
    highlight.FillColor = ESPSystem.GetESPColor(player)
    highlight.FillTransparency = Config.ESPTransparency
    highlight.OutlineTransparency = 0.5
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    highlight.Parent = espData.Holder
    espData.Highlight = highlight
    
    -- Create Tracer (Line)
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Config.TracerColor
    tracer.Thickness = Config.TracerThickness
    tracer.Transparency = 0.7
    espData.Tracer = tracer
    
    State.ESPObjects[player.Name] = espData
    
    ESPSystem.UpdateESP(player)
end

function ESPSystem.UpdateESP(player)
    local espData = State.ESPObjects[player.Name]
    if not espData then return end
    
    if not Config.ESPEnabled then
        ESPSystem.HideESP(player)
        return
    end
    
    local shouldShow = Utils.IsAlive(player) and 
                       (not Config.IgnoreTeam or player.Team ~= LocalPlayer.Team)
    
    if not shouldShow then
        ESPSystem.HideESP(player)
        return
    end
    
    local character = player.Character
    if not character then
        ESPSystem.HideESP(player)
        return
    end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not rootPart then
        ESPSystem.HideESP(player)
        return
    end
    
    local color = ESPSystem.GetESPColor(player)
    
    -- Update Box
    if espData.Box and Config.ESPBoxEnabled then
        espData.Box.Adornee = character
        espData.Box.Color3 = color
        espData.Box.Visible = true
    elseif espData.Box then
        espData.Box.Visible = false
    end
    
    -- Update NameTag
    if espData.NameTag and (Config.ESPNameEnabled or Config.ESPDistance) and head then
        espData.NameTag.Adornee = head
        espData.NameTag.Enabled = true
        
        if espData.NameTag:FindFirstChild("NameLabel") then
            espData.NameTag.NameLabel.TextColor3 = color
            espData.NameTag.NameLabel.Visible = Config.ESPNameEnabled
        end
        
        if espData.NameTag:FindFirstChild("DistanceLabel") then
            local distance = Utils.GetDistance(player)
            espData.NameTag.DistanceLabel.Text = distance .. "m"
            espData.NameTag.DistanceLabel.Visible = Config.ESPDistance
        end
    elseif espData.NameTag then
        espData.NameTag.Enabled = false
    end
    
    -- Update Health Bar
    if espData.HealthBar and Config.ESPHealthBar and humanoid and rootPart then
        espData.HealthBar.Adornee = rootPart
        espData.HealthBar.Enabled = true
        
        local health = math.floor(humanoid.Health)
        local maxHealth = math.floor(humanoid.MaxHealth)
        local healthPercent = health / maxHealth
        
        local healthBG = espData.HealthBar:FindFirstChild("HealthBG")
        if healthBG then
            local healthFill = healthBG:FindFirstChild("HealthFill")
            if healthFill then
                healthFill.Size = UDim2.new(1, 0, healthPercent, 0)
                
                if healthPercent > 0.6 then
                    healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                elseif healthPercent > 0.3 then
                    healthFill.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
                else
                    healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                end
            end
        end
        
        local healthText = espData.HealthBar:FindFirstChild("HealthText")
        if healthText then
            healthText.Text = tostring(health)
        end
    elseif espData.HealthBar then
        espData.HealthBar.Enabled = false
    end
    
    -- Update Highlight
    if espData.Highlight and Config.ESPHighlightEnabled then
        espData.Highlight.Adornee = character
        espData.Highlight.FillColor = color
        espData.Highlight.FillTransparency = Config.ESPTransparency
        espData.Highlight.Enabled = true
    elseif espData.Highlight then
        espData.Highlight.Enabled = false
    end
    
    -- Update Tracer
    if espData.Tracer and Config.ESPTracers and rootPart then
        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        
        if onScreen then
            local viewportSize = Camera.ViewportSize
            espData.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
            espData.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            espData.Tracer.Color = color
            espData.Tracer.Visible = true
        else
            espData.Tracer.Visible = false
        end
    elseif espData.Tracer then
        espData.Tracer.Visible = false
    end
end

function ESPSystem.HideESP(player)
    local espData = State.ESPObjects[player.Name]
    if not espData then return end
    
    if espData.Box then
        espData.Box.Visible = false
    end
    if espData.NameTag then
        espData.NameTag.Enabled = false
    end
    if espData.HealthBar then
        espData.HealthBar.Enabled = false
    end
    if espData.Highlight then
        espData.Highlight.Enabled = false
    end
    if espData.Tracer then
        espData.Tracer.Visible = false
    end
end

function ESPSystem.RemoveESP(player)
    local espData = State.ESPObjects[player.Name]
    if not espData then return end
    
    if espData.UpdateConnection then
        espData.UpdateConnection:Disconnect()
    end
    
    if espData.Holder then
        espData.Holder:Destroy()
    end
    
    if espData.Tracer then
        espData.Tracer:Remove()
    end
    
    State.ESPObjects[player.Name] = nil
end

function ESPSystem.RefreshAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ESPSystem.UpdateESP(player)
        end
    end
end

-- ============================================================
-- DRAWING SYSTEM
-- ============================================================
local DrawingManager = {}

function DrawingManager.CreateFOVCircle()
    if State.FOVCircle then
        State.FOVCircle:Remove()
    end
    
    local circle = Drawing.new("Circle")
    circle.Radius = Config.FOVRadius
    circle.Thickness = Config.FOVThickness
    circle.Color = Config.FOVColor
    circle.Transparency = Config.FOVTransparency
    circle.Filled = false
    circle.NumSides = 64
    circle.Visible = true
    circle.Position = Camera.ViewportSize / 2
    
    State.FOVCircle = circle
    return circle
end

function DrawingManager.CreateTargetIndicator()
    if State.TargetIndicator then
        State.TargetIndicator:Remove()
    end
    
    local indicator = Drawing.new("Circle")
    indicator.Radius = 8
    indicator.Thickness = 2
    indicator.Color = Config.Theme.Success
    indicator.Transparency = 1
    indicator.Filled = false
    indicator.NumSides = 32
    indicator.Visible = false
    
    State.TargetIndicator = indicator
    return indicator
end

function DrawingManager.UpdateFOV()
    if not State.FOVCircle then 
        if Config.Active then
            DrawingManager.CreateFOVCircle()
        else
            return
        end
    end
    
    local viewportCenter = Camera.ViewportSize / 2
    State.FOVCircle.Position = viewportCenter
    State.FOVCircle.Visible = Config.ShowFOV and Config.Active
    State.FOVCircle.Radius = Config.FOVRadius
    State.FOVCircle.Color = Config.FOVColor
end

function DrawingManager.UpdateTargetIndicator(screenPosition)
    if not State.TargetIndicator then return end
    
    if screenPosition then
        State.TargetIndicator.Position = screenPosition
        State.TargetIndicator.Visible = true
        
        local pulseSize = 8 + math.sin(tick() * 5) * 2
        State.TargetIndicator.Radius = pulseSize
    else
        State.TargetIndicator.Visible = false
    end
end

function DrawingManager.Cleanup()
    if State.FOVCircle then
        State.FOVCircle:Remove()
        State.FOVCircle = nil
    end
    if State.TargetIndicator then
        State.TargetIndicator:Remove()
        State.TargetIndicator = nil
    end
end

-- ============================================================
-- TARGET SYSTEM
-- ============================================================
local TargetSystem = {}

function TargetSystem.GetClosestTarget()
    local closestTarget = nil
    local closestDistance = math.huge
    local viewportCenter = Camera.ViewportSize / 2

    State.Performance.TargetCount = 0

    for _, player in ipairs(Players:GetPlayers()) do
        local valid = true

        if player == LocalPlayer then
            valid = false
        elseif not Utils.IsAlive(player) and Config.IgnoreDead then
            valid = false
        elseif player.Team == LocalPlayer.Team and Config.IgnoreTeam then
            valid = false
        end

        if valid then
            local targetPart = Utils.GetPartFromPlayer(player)
            if not targetPart then
                valid = false
            end

            if valid then
                State.Performance.TargetCount = State.Performance.TargetCount + 1

                local screenPosition, onScreen =
                    Camera:WorldToViewportPoint(targetPart.Position)

                if onScreen then
                    local screenPos2D = Vector2.new(screenPosition.X, screenPosition.Y)
                    local distanceFromCenter =
                        (screenPos2D - viewportCenter).Magnitude

                    if distanceFromCenter <= Config.FOVRadius then
                        if Utils.IsVisible(targetPart.Position, player.Character) then
                            if distanceFromCenter < closestDistance then
                                closestDistance = distanceFromCenter
                                closestTarget = {
                                    Part = targetPart,
                                    Player = player,
                                    ScreenPosition = screenPos2D,
                                    Distance = distanceFromCenter
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    return closestTarget
end

function TargetSystem.AimAtTarget(target)
    if not target or not target.Part then return end
    
    local targetPosition = target.Part.Position
    local cameraPosition = Camera.CFrame.Position
    local direction = (targetPosition - cameraPosition).Unit
    
    local currentLook = Camera.CFrame.LookVector
    local newLook = currentLook:Lerp(direction, Config.Smoothness)
    
    Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + newLook)
end

-- ============================================================
-- MODERN GUI SYSTEM WITH TABS
-- ============================================================
local GUI = {}

function GUI.Create()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CombatAssist_Modern"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game.CoreGui
    
    GUI.ScreenGui = screenGui
    GUI.CreateMainWindow()
    
    return screenGui
end

function GUI.CreateMainWindow()
    -- Main Container
    local container = Instance.new("Frame")
    container.Name = "MainWindow"
    container.Size = UDim2.new(0, 520, 0, 650)
    container.Position = UDim2.new(0.5, -260, 0.5, -325)
    container.BackgroundColor3 = Config.Theme.Background
    container.BorderSizePixel = 0
    container.Active = true
    container.Draggable = true
    container.Parent = GUI.ScreenGui
    
    Utils.CreateCorner(container, 16)
    
    -- Shadow effect
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.ZIndex = 0
    shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    shadow.ImageColor3 = Config.Theme.Shadow
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 10, 10)
    shadow.Parent = container
    
    GUI.Container = container
    
    GUI.CreateHeader(container)
    GUI.CreateTabBar(container)
    GUI.CreateTabContents(container)
end

function GUI.CreateHeader(parent)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 70)
    header.BackgroundColor3 = Config.Theme.Surface
    header.BorderSizePixel = 0
    header.Parent = parent
    
    Utils.CreateCorner(header, 16)
    
    -- Decorative accent line
    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(1, 0, 0, 3)
    accentLine.Position = UDim2.new(0, 0, 1, -3)
    accentLine.BackgroundColor3 = Config.Theme.Primary
    accentLine.BorderSizePixel = 0
    accentLine.Parent = header
    
    -- Logo/Icon
    local icon = Instance.new("Frame")
    icon.Size = UDim2.new(0, 40, 0, 40)
    icon.Position = UDim2.new(0, 20, 0, 15)
    icon.BackgroundColor3 = Config.Theme.Primary
    icon.BorderSizePixel = 0
    icon.Parent = header
    
    Utils.CreateCorner(icon, 10)
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "🎯"
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 20
    iconLabel.TextColor3 = Config.Theme.Text
    iconLabel.Parent = icon
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -180, 0, 28)
    title.Position = UDim2.new(0, 70, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = Config.Name
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Config.Theme.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    -- Version badge
    local versionBadge = Instance.new("Frame")
    versionBadge.Size = UDim2.new(0, 60, 0, 22)
    versionBadge.Position = UDim2.new(0, 70, 0, 40)
    versionBadge.BackgroundColor3 = Config.Theme.Primary
    versionBadge.BorderSizePixel = 0
    versionBadge.Parent = header
    
    Utils.CreateCorner(versionBadge, 6)
    
    local versionText = Instance.new("TextLabel")
    versionText.Size = UDim2.new(1, 0, 1, 0)
    versionText.BackgroundTransparency = 1
    versionText.Text = "v" .. Config.Version
    versionText.Font = Enum.Font.GothamBold
    versionText.TextSize = 11
    versionText.TextColor3 = Config.Theme.Text
    versionText.Parent = versionBadge
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -60, 0, 15)
    closeButton.BackgroundColor3 = Config.Theme.Danger
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.TextColor3 = Config.Theme.Text
    closeButton.AutoButtonColor = false
    closeButton.Parent = header
    
    Utils.CreateCorner(closeButton, 10)
    
    closeButton.MouseEnter:Connect(function()
        Utils.TweenProperty(closeButton, "BackgroundColor3", Config.Theme.Danger:Lerp(Color3.new(1, 1, 1), 0.2), 0.15)
    end)
    
    closeButton.MouseLeave:Connect(function()
        Utils.TweenProperty(closeButton, "BackgroundColor3", Config.Theme.Danger, 0.15)
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        GUI.Destroy()
    end)
end

function GUI.CreateTabBar(parent)
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, 0, 0, 50)
    tabBar.Position = UDim2.new(0, 0, 0, 70)
    tabBar.BackgroundColor3 = Config.Theme.Surface
    tabBar.BorderSizePixel = 0
    tabBar.Parent = parent
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabBar
    
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingTop = UDim.new(0, 8)
    tabPadding.PaddingLeft = UDim.new(0, 15)
    tabPadding.PaddingRight = UDim.new(0, 15)
    tabPadding.Parent = tabBar
    
    GUI.TabBar = tabBar
    GUI.Tabs = {}
    
    -- Create tabs
    GUI.CreateTab(tabBar, "Combat", "⚔️", 1, true)
    GUI.CreateTab(tabBar, "Visual", "👁️", 2, false)
    GUI.CreateTab(tabBar, "Settings", "⚙️", 3, false)
end

function GUI.CreateTab(parent, name, icon, order, active)
    local tab = Instance.new("TextButton")
    tab.Name = name .. "Tab"
    tab.Size = UDim2.new(0, 150, 0, 36)
    tab.BackgroundColor3 = active and Config.Theme.Primary or Config.Theme.TabInactive
    tab.BorderSizePixel = 0
    tab.Text = ""
    tab.AutoButtonColor = false
    tab.LayoutOrder = order
    tab.Parent = parent
    
    Utils.CreateCorner(tab, 8)
    
    -- Tab content
    local tabContent = Instance.new("Frame")
    tabContent.Size = UDim2.new(1, 0, 1, 0)
    tabContent.BackgroundTransparency = 1
    tabContent.Parent = tab
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.Parent = tabContent
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 20, 0, 20)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.TextColor3 = Config.Theme.Text
    iconLabel.Parent = tabContent
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0, 80, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Config.Theme.Text
    nameLabel.Parent = tabContent
    
    tab.MouseEnter:Connect(function()
        if Config.CurrentTab ~= name then
            Utils.TweenProperty(tab, "BackgroundColor3", Config.Theme.BorderLight, 0.15)
        end
    end)
    
    tab.MouseLeave:Connect(function()
        if Config.CurrentTab ~= name then
            Utils.TweenProperty(tab, "BackgroundColor3", Config.Theme.TabInactive, 0.15)
        end
    end)
    
    tab.MouseButton1Click:Connect(function()
        GUI.SwitchTab(name)
    end)
    
    GUI.Tabs[name] = tab
end

function GUI.SwitchTab(tabName)
    Config.CurrentTab = tabName
    
    -- Update tab colors
    for name, tab in pairs(GUI.Tabs) do
        if name == tabName then
            Utils.TweenProperty(tab, "BackgroundColor3", Config.Theme.Primary, 0.2)
        else
            Utils.TweenProperty(tab, "BackgroundColor3", Config.Theme.TabInactive, 0.2)
        end
    end
    
    -- Update content visibility
    if GUI.TabContents then
        for name, content in pairs(GUI.TabContents) do
            content.Visible = (name == tabName)
        end
    end
end

function GUI.CreateTabContents(parent)
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, 0, 1, -120)
    contentContainer.Position = UDim2.new(0, 0, 0, 120)
    contentContainer.BackgroundTransparency = 1
    contentContainer.BorderSizePixel = 0
    contentContainer.Parent = parent
    
    GUI.TabContents = {}
    
    -- Create content for each tab
    GUI.TabContents.Combat = GUI.CreateCombatContent(contentContainer)
    GUI.TabContents.Visual = GUI.CreateVisualContent(contentContainer)
    GUI.TabContents.Settings = GUI.CreateSettingsContent(contentContainer)
    
    -- Show only active tab
    GUI.SwitchTab(Config.CurrentTab)
end

function GUI.CreateCombatContent(parent)
    local content = Instance.new("ScrollingFrame")
    content.Name = "CombatContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.ScrollBarImageColor3 = Config.Theme.Primary
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = true
    content.Parent = parent
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 15)
    padding.PaddingBottom = UDim.new(0, 15)
    padding.PaddingLeft = UDim.new(0, 20)
    padding.PaddingRight = UDim.new(0, 20)
    padding.Parent = content
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content
    
    -- Activation Section
    local activationSection = GUI.CreateModernSection(content, "Combat Activation", 1)
    
    local activateButton = Instance.new("TextButton")
    activateButton.Size = UDim2.new(1, 0, 0, 50)
    activateButton.BackgroundColor3 = Config.Active and Config.Theme.Danger or Config.Theme.Success
    activateButton.BorderSizePixel = 0
    activateButton.Text = ""
    activateButton.AutoButtonColor = false
    activateButton.LayoutOrder = 1
    activateButton.Parent = activationSection
    
    Utils.CreateCorner(activateButton, 12)
    
    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    buttonLayout.Padding = UDim.new(0, 4)
    buttonLayout.Parent = activateButton
    
    local buttonIcon = Instance.new("TextLabel")
    buttonIcon.Size = UDim2.new(0, 30, 0, 30)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Text = Config.Active and "⏸" or "▶"
    buttonIcon.Font = Enum.Font.GothamBold
    buttonIcon.TextSize = 20
    buttonIcon.TextColor3 = Config.Theme.Text
    buttonIcon.Parent = activateButton
    
    local buttonText = Instance.new("TextLabel")
    buttonText.Size = UDim2.new(0, 300, 0, 20)
    buttonText.BackgroundTransparency = 1
    buttonText.Text = Config.Active and "DEACTIVATE AIM ASSIST" or "ACTIVATE AIM ASSIST"
    buttonText.Font = Enum.Font.GothamBold
    buttonText.TextSize = 15
    buttonText.TextColor3 = Config.Theme.Text
    buttonText.Parent = activateButton
    
    activateButton.MouseButton1Click:Connect(function()
        Config.Active = not Config.Active
        
        if Config.Active then
            buttonText.Text = "DEACTIVATE AIM ASSIST"
            buttonIcon.Text = "⏸"
            Utils.TweenProperty(activateButton, "BackgroundColor3", Config.Theme.Danger, 0.3)
            DrawingManager.CreateFOVCircle()
            DrawingManager.CreateTargetIndicator()
        else
            buttonText.Text = "ACTIVATE AIM ASSIST"
            buttonIcon.Text = "▶"
            Utils.TweenProperty(activateButton, "BackgroundColor3", Config.Theme.Success, 0.3)
            DrawingManager.Cleanup()
            State.CurrentTarget = nil
        end
    end)
    
    -- Aim Settings Section
    local aimSection = GUI.CreateModernSection(content, "Aim Settings", 2)
    
    GUI.CreateModernSlider(aimSection, "Smoothness", "🎯", 0.05, 1.0, Config.Smoothness, function(value)
        Config.Smoothness = value
    end, 1)
    
    GUI.CreateModernSlider(aimSection, "FOV Radius", "⭕", 50, 300, Config.FOVRadius, function(value)
        Config.FOVRadius = value
        if State.FOVCircle then
            State.FOVCircle.Radius = value
        end
    end, 2)
    
    GUI.CreateModernToggle(aimSection, "Show FOV Circle", "👁️", Config.ShowFOV, function(value)
        Config.ShowFOV = value
        if State.FOVCircle then
            State.FOVCircle.Visible = value and Config.Active
        end
    end, 3)
    
    -- Target Mode Section
    local targetSection = GUI.CreateModernSection(content, "Target Mode", 3)
    
    GUI.CreateModernDropdown(targetSection, "Aim Mode", "🎮",
        {"Priority Part", "Specific Part", "Closest Part"},
        Config.AimMode,
        function(value)
            Config.AimMode = value
        end,
    1)
    
    GUI.CreateModernDropdown(targetSection, "Target Part", "🎯",
        {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
        Config.TargetPart,
        function(value)
            Config.TargetPart = value
        end,
    2)
    
    -- Filters Section
    local filtersSection = GUI.CreateModernSection(content, "Target Filters", 4)
    
    GUI.CreateModernToggle(filtersSection, "Ignore Team", "👥", Config.IgnoreTeam, function(value)
        Config.IgnoreTeam = value
    end, 1)
    
    GUI.CreateModernToggle(filtersSection, "Wall Check", "🧱", Config.CheckWalls, function(value)
        Config.CheckWalls = value
    end, 2)
    
    GUI.CreateModernToggle(filtersSection, "Ignore Dead", "💀", Config.IgnoreDead, function(value)
        Config.IgnoreDead = value
    end, 3)
    
    return content
end

function GUI.CreateVisualContent(parent)
    local content = Instance.new("ScrollingFrame")
    content.Name = "VisualContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.ScrollBarImageColor3 = Config.Theme.Primary
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = false
    content.Parent = parent
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 15)
    padding.PaddingBottom = UDim.new(0, 15)
    padding.PaddingLeft = UDim.new(0, 20)
    padding.PaddingRight = UDim.new(0, 20)
    padding.Parent = content
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content
    
    -- ESP Master Control
    local masterSection = GUI.CreateModernSection(content, "ESP Master Control", 1)
    
    local espMasterButton = Instance.new("TextButton")
    espMasterButton.Size = UDim2.new(1, 0, 0, 50)
    espMasterButton.BackgroundColor3 = Config.ESPEnabled and Config.Theme.Success or Config.Theme.Danger
    espMasterButton.BorderSizePixel = 0
    espMasterButton.Text = ""
    espMasterButton.AutoButtonColor = false
    espMasterButton.LayoutOrder = 1
    espMasterButton.Parent = masterSection
    
    Utils.CreateCorner(espMasterButton, 12)
    
    local espButtonLayout = Instance.new("UIListLayout")
    espButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    espButtonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    espButtonLayout.Padding = UDim.new(0, 4)
    espButtonLayout.Parent = espMasterButton
    
    local espButtonIcon = Instance.new("TextLabel")
    espButtonIcon.Size = UDim2.new(0, 30, 0, 30)
    espButtonIcon.BackgroundTransparency = 1
    espButtonIcon.Text = Config.ESPEnabled and "👁️" or "🚫"
    espButtonIcon.Font = Enum.Font.GothamBold
    espButtonIcon.TextSize = 20
    espButtonIcon.TextColor3 = Config.Theme.Text
    espButtonIcon.Parent = espMasterButton
    
    local espButtonText = Instance.new("TextLabel")
    espButtonText.Size = UDim2.new(0, 300, 0, 20)
    espButtonText.BackgroundTransparency = 1
    espButtonText.Text = Config.ESPEnabled and "ESP ENABLED" or "ESP DISABLED"
    espButtonText.Font = Enum.Font.GothamBold
    espButtonText.TextSize = 15
    espButtonText.TextColor3 = Config.Theme.Text
    espButtonText.Parent = espMasterButton
    
    espMasterButton.MouseButton1Click:Connect(function()
        Config.ESPEnabled = not Config.ESPEnabled
        
        if Config.ESPEnabled then
            espButtonText.Text = "ESP ENABLED"
            espButtonIcon.Text = "👁️"
            Utils.TweenProperty(espMasterButton, "BackgroundColor3", Config.Theme.Success, 0.3)
        else
            espButtonText.Text = "ESP DISABLED"
            espButtonIcon.Text = "🚫"
            Utils.TweenProperty(espMasterButton, "BackgroundColor3", Config.Theme.Danger, 0.3)
        end
        
        ESPSystem.RefreshAllESP()
    end)
    
    -- ESP Features Section
    local featuresSection = GUI.CreateModernSection(content, "ESP Features", 2)
    
    GUI.CreateModernToggle(featuresSection, "Boxes", "📦", Config.ESPBoxEnabled, function(value)
        Config.ESPBoxEnabled = value
        ESPSystem.RefreshAllESP()
    end, 1)
    
    GUI.CreateModernToggle(featuresSection, "Names", "📝", Config.ESPNameEnabled, function(value)
        Config.ESPNameEnabled = value
        ESPSystem.RefreshAllESP()
    end, 2)
    
    GUI.CreateModernToggle(featuresSection, "Health Bar", "❤️", Config.ESPHealthBar, function(value)
        Config.ESPHealthBar = value
        ESPSystem.RefreshAllESP()
    end, 3)
    
    GUI.CreateModernToggle(featuresSection, "Highlights", "✨", Config.ESPHighlightEnabled, function(value)
        Config.ESPHighlightEnabled = value
        ESPSystem.RefreshAllESP()
    end, 4)
    
    GUI.CreateModernToggle(featuresSection, "Distance", "📏", Config.ESPDistance, function(value)
        Config.ESPDistance = value
        ESPSystem.RefreshAllESP()
    end, 5)
    
    GUI.CreateModernToggle(featuresSection, "Tracers", "📍", Config.ESPTracers, function(value)
        Config.ESPTracers = value
        ESPSystem.RefreshAllESP()
    end, 6)
    
    -- ESP Appearance Section
    local appearanceSection = GUI.CreateModernSection(content, "ESP Appearance", 3)
    
    GUI.CreateModernToggle(appearanceSection, "Use Team Colors", "🎨", Config.UseTeamColor, function(value)
        Config.UseTeamColor = value
        ESPSystem.RefreshAllESP()
    end, 1)
    
    GUI.CreateModernSlider(appearanceSection, "Highlight Transparency", "💫", 0, 1, Config.ESPTransparency, function(value)
        Config.ESPTransparency = value
        ESPSystem.RefreshAllESP()
    end, 2)
    
    GUI.CreateModernSlider(appearanceSection, "Box Transparency", "📦", 0, 1, Config.BoxTransparency, function(value)
        Config.BoxTransparency = value
        ESPSystem.RefreshAllESP()
    end, 3)
    
    return content
end

function GUI.CreateSettingsContent(parent)
    local content = Instance.new("ScrollingFrame")
    content.Name = "SettingsContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.ScrollBarImageColor3 = Config.Theme.Primary
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = false
    content.Parent = parent
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 15)
    padding.PaddingBottom = UDim.new(0, 15)
    padding.PaddingLeft = UDim.new(0, 20)
    padding.PaddingRight = UDim.new(0, 20)
    padding.Parent = content
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content
    
    -- Mouse Settings Section
    local mouseSection = GUI.CreateModernSection(content, "Mouse Settings", 1)
    
    GUI.CreateModernToggle(mouseSection, "Auto Mouse Lock", "🖱️", Config.AutoMouseLock, function(value)
        Config.AutoMouseLock = value
        if value then
            Config.ManualMouseLock = false
            MouseManager.UpdateMouseLock()
        end
    end, 1)
    
    -- Info box
    local infoBox = Instance.new("Frame")
    infoBox.Size = UDim2.new(1, 0, 0, 70)
    infoBox.BackgroundColor3 = Config.Theme.SurfaceLight
    infoBox.BorderSizePixel = 0
    infoBox.LayoutOrder = 2
    infoBox.Parent = mouseSection
    
    Utils.CreateCorner(infoBox, 8)
    Utils.CreateStroke(infoBox, Config.Theme.BorderLight, 1)
    
    local infoPadding = Instance.new("UIPadding")
    infoPadding.PaddingTop = UDim.new(0, 10)
    infoPadding.PaddingBottom = UDim.new(0, 10)
    infoPadding.PaddingLeft = UDim.new(0, 12)
    infoPadding.PaddingRight = UDim.new(0, 12)
    infoPadding.Parent = infoBox
    
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, 0, 1, 0)
    infoText.BackgroundTransparency = 1
    infoText.Text = "ℹ️ Auto Mode:\n• Mouse locks when in-game\n• Mouse unlocks in lobby"
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 11
    infoText.TextColor3 = Config.Theme.TextSecondary
    infoText.TextWrapped = true
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.Parent = infoBox
    
    -- Manual mouse button
    local mouseButton = Instance.new("TextButton")
    mouseButton.Size = UDim2.new(1, 0, 0, 45)
    mouseButton.BackgroundColor3 = Config.Theme.Primary
    mouseButton.BorderSizePixel = 0
    mouseButton.Text = ""
    mouseButton.AutoButtonColor = false
    mouseButton.LayoutOrder = 3
    mouseButton.Parent = mouseSection
    
    Utils.CreateCorner(mouseButton, 10)
    
    local mouseButtonText = Instance.new("TextLabel")
    mouseButtonText.Size = UDim2.new(1, 0, 1, 0)
    mouseButtonText.BackgroundTransparency = 1
    mouseButtonText.Text = "🖱️ TOGGLE MOUSE LOCK (MANUAL)"
    mouseButtonText.Font = Enum.Font.GothamBold
    mouseButtonText.TextSize = 13
    mouseButtonText.TextColor3 = Config.Theme.Text
    mouseButtonText.Parent = mouseButton
    
    mouseButton.MouseButton1Click:Connect(function()
        MouseManager.ToggleManualMouseLock()
    end)
    
    -- Performance Section
    local perfSection = GUI.CreateModernSection(content, "Performance & Status", 2)
    
    local perfFrame = Instance.new("Frame")
    perfFrame.Size = UDim2.new(1, 0, 0, 140)
    perfFrame.BackgroundColor3 = Config.Theme.SurfaceLight
    perfFrame.BorderSizePixel = 0
    perfFrame.LayoutOrder = 1
    perfFrame.Parent = perfSection
    
    Utils.CreateCorner(perfFrame, 10)
    Utils.CreateStroke(perfFrame, Config.Theme.BorderLight, 1)
    
    local perfPadding = Instance.new("UIPadding")
    perfPadding.PaddingTop = UDim.new(0, 12)
    perfPadding.PaddingBottom = UDim.new(0, 12)
    perfPadding.PaddingLeft = UDim.new(0, 15)
    perfPadding.PaddingRight = UDim.new(0, 15)
    perfPadding.Parent = perfFrame
    
    local perfLayout = Instance.new("UIListLayout")
    perfLayout.Padding = UDim.new(0, 8)
    perfLayout.SortOrder = Enum.SortOrder.LayoutOrder
    perfLayout.Parent = perfFrame
    
    GUI.PerformanceLabels = {}
    
    -- Create performance stat rows
    local stats = {
        {name = "FPS", icon = "📊", text = "FPS: 60"},
        {name = "Targets", icon = "🎯", text = "Targets: 0"},
        {name = "ESP", icon = "👁️", text = "ESP Objects: 0"},
        {name = "Mouse", icon = "🖱️", text = "Mouse: UNLOCKED"},
        {name = "GameState", icon = "🎮", text = "State: LOBBY"}
    }
    
    for i, stat in ipairs(stats) do
        local statRow = Instance.new("Frame")
        statRow.Size = UDim2.new(1, 0, 0, 22)
        statRow.BackgroundTransparency = 1
        statRow.LayoutOrder = i
        statRow.Parent = perfFrame
        
        local statIcon = Instance.new("TextLabel")
        statIcon.Size = UDim2.new(0, 20, 1, 0)
        statIcon.BackgroundTransparency = 1
        statIcon.Text = stat.icon
        statIcon.Font = Enum.Font.GothamBold
        statIcon.TextSize = 14
        statIcon.TextXAlignment = Enum.TextXAlignment.Left
        statIcon.Parent = statRow
        
        local statLabel = Instance.new("TextLabel")
        statLabel.Name = stat.name
        statLabel.Size = UDim2.new(1, -25, 1, 0)
        statLabel.Position = UDim2.new(0, 25, 0, 0)
        statLabel.BackgroundTransparency = 1
        statLabel.Text = stat.text
        statLabel.Font = Enum.Font.GothamMedium
        statLabel.TextSize = 12
        statLabel.TextColor3 = Config.Theme.TextSecondary
        statLabel.TextXAlignment = Enum.TextXAlignment.Left
        statLabel.Parent = statRow
        
        GUI.PerformanceLabels[stat.name] = statLabel
    end
    
    -- Info Section
    local infoSection = GUI.CreateModernSection(content, "Information", 3)
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, 0, 0, 80)
    infoFrame.BackgroundColor3 = Config.Theme.SurfaceLight
    infoFrame.BorderSizePixel = 0
    infoFrame.LayoutOrder = 1
    infoFrame.Parent = infoSection
    
    Utils.CreateCorner(infoFrame, 10)
    Utils.CreateStroke(infoFrame, Config.Theme.Warning, 1.5)
    
    local infoFramePadding = Instance.new("UIPadding")
    infoFramePadding.PaddingTop = UDim.new(0, 12)
    infoFramePadding.PaddingBottom = UDim.new(0, 12)
    infoFramePadding.PaddingLeft = UDim.new(0, 15)
    infoFramePadding.PaddingRight = UDim.new(0, 15)
    infoFramePadding.Parent = infoFrame
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 1, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "⚠️ Educational Use Only\n\n💡 Press RightShift to toggle UI\n🎯 Optimized for smooth performance"
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = Config.Theme.TextSecondary
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.Parent = infoFrame
    
    return content
end

-- Modern UI Component Creators
function GUI.CreateModernSection(parent, title, order)
    local section = Instance.new("Frame")
    section.Name = title .. "Section"
    section.Size = UDim2.new(1, 0, 0, 0)
    section.BackgroundColor3 = Config.Theme.Surface
    section.BorderSizePixel = 0
    section.LayoutOrder = order
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = parent
    
    Utils.CreateCorner(section, 12)
    Utils.CreateStroke(section, Config.Theme.BorderLight, 1)
    
    local sectionPadding = Instance.new("UIPadding")
    sectionPadding.PaddingTop = UDim.new(0, 15)
    sectionPadding.PaddingBottom = UDim.new(0, 15)
    sectionPadding.PaddingLeft = UDim.new(0, 15)
    sectionPadding.PaddingRight = UDim.new(0, 15)
    sectionPadding.Parent = section
    
    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.Padding = UDim.new(0, 10)
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Parent = section
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 24)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Config.Theme.Primary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.LayoutOrder = 0
    titleLabel.Parent = section
    
    return section
end

function GUI.CreateModernToggle(parent, label, icon, defaultValue, callback, layoutOrder)
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(1, 0, 0, 40)
    toggle.BackgroundColor3 = Config.Theme.SurfaceLight
    toggle.BorderSizePixel = 0
    toggle.LayoutOrder = layoutOrder
    toggle.Parent = parent
    
    Utils.CreateCorner(toggle, 8)
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 30, 1, 0)
    iconLabel.Position = UDim2.new(0, 10, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.Parent = toggle
    
    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(1, -110, 1, 0)
    labelText.Position = UDim2.new(0, 45, 0, 0)
    labelText.BackgroundTransparency = 1
    labelText.Text = label
    labelText.Font = Enum.Font.GothamMedium
    labelText.TextSize = 13
    labelText.TextColor3 = Config.Theme.Text
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Parent = toggle
    
    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 50, 0, 26)
    switch.Position = UDim2.new(1, -60, 0.5, -13)
    switch.BackgroundColor3 = defaultValue and Config.Theme.Success or Config.Theme.Border
    switch.BorderSizePixel = 0
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = toggle
    
    Utils.CreateCorner(switch, 13)
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = defaultValue and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Config.Theme.Text
    knob.BorderSizePixel = 0
    knob.Parent = switch
    
    Utils.CreateCorner(knob, 10)
    
    local state = defaultValue
    
    switch.MouseButton1Click:Connect(function()
        state = not state
        callback(state)
        
        Utils.TweenProperty(switch, "BackgroundColor3", 
            state and Config.Theme.Success or Config.Theme.Border, 0.2)
        Utils.TweenProperty(knob, "Position", 
            state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10), 0.2)
    end)
    
    return toggle
end

function GUI.CreateModernSlider(parent, label, icon, min, max, default, callback, layoutOrder)
    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 55)
    slider.BackgroundColor3 = Config.Theme.SurfaceLight
    slider.BorderSizePixel = 0
    slider.LayoutOrder = layoutOrder
    slider.Parent = parent
    
    Utils.CreateCorner(slider, 8)
    
    local sliderPadding = Instance.new("UIPadding")
    sliderPadding.PaddingTop = UDim.new(0, 8)
    sliderPadding.PaddingBottom = UDim.new(0, 8)
    sliderPadding.PaddingLeft = UDim.new(0, 12)
    sliderPadding.PaddingRight = UDim.new(0, 12)
    sliderPadding.Parent = slider
    
    local topRow = Instance.new("Frame")
    topRow.Size = UDim2.new(1, 0, 0, 20)
    topRow.BackgroundTransparency = 1
    topRow.Parent = slider
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 20, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 14
    iconLabel.Parent = topRow
    
    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(0.6, 0, 1, 0)
    labelText.Position = UDim2.new(0, 25, 0, 0)
    labelText.BackgroundTransparency = 1
    labelText.Text = label
    labelText.Font = Enum.Font.GothamMedium
    labelText.TextSize = 13
    labelText.TextColor3 = Config.Theme.Text
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Parent = topRow
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.4, -25, 1, 0)
    valueLabel.Position = UDim2.new(0.6, 25, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = string.format("%.2f", default)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 13
    valueLabel.TextColor3 = Config.Theme.Primary
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = topRow
    
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 1, -12)
    track.BackgroundColor3 = Config.Theme.Border
    track.BorderSizePixel = 0
    track.Parent = slider
    
    Utils.CreateCorner(track, 4)
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Config.Theme.Primary
    fill.BorderSizePixel = 0
    fill.Parent = track
    
    Utils.CreateCorner(fill, 4)
    
    local handle = Instance.new("Frame")
    handle.Size = UDim2.new(0, 18, 0, 18)
    handle.Position = UDim2.new((default - min) / (max - min), -9, 0.5, -9)
    handle.BackgroundColor3 = Config.Theme.Primary
    handle.BorderSizePixel = 0
    handle.Parent = track
    
    Utils.CreateCorner(handle, 9)
    Utils.CreateStroke(handle, Config.Theme.Text, 2)
    
    local dragging = false
    local currentValue = default
    
    local function updateValue(input)
        local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        currentValue = min + (max - min) * relativeX
        
        valueLabel.Text = string.format("%.2f", currentValue)
        fill.Size = UDim2.new(relativeX, 0, 1, 0)
        handle.Position = UDim2.new(relativeX, -9, 0.5, -9)
        
        callback(currentValue)
    end
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input)
        end
    end)
    
    return slider
end

function GUI.CreateModernDropdown(parent, label, icon, options, default, callback, layoutOrder)
    local dropdown = Instance.new("Frame")
    dropdown.Size = UDim2.new(1, 0, 0, 40)
    dropdown.BackgroundColor3 = Config.Theme.SurfaceLight
    dropdown.BorderSizePixel = 0
    dropdown.LayoutOrder = layoutOrder
    dropdown.Parent = parent
    
    Utils.CreateCorner(dropdown, 8)
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 30, 1, 0)
    iconLabel.Position = UDim2.new(0, 10, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.Parent = dropdown
    
    local labelText = Instance.new("TextLabel")
    labelText.Size = UDim2.new(0.4, 0, 1, 0)
    labelText.Position = UDim2.new(0, 45, 0, 0)
    labelText.BackgroundTransparency = 1
    labelText.Text = label
    labelText.Font = Enum.Font.GothamMedium
    labelText.TextSize = 13
    labelText.TextColor3 = Config.Theme.Text
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.Parent = dropdown
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.55, -10, 0, 28)
    button.Position = UDim2.new(0.45, 5, 0.5, -14)
    button.BackgroundColor3 = Config.Theme.Background
    button.BorderSizePixel = 0
    button.Text = default .. " ▼"
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 12
    button.TextColor3 = Config.Theme.Text
    button.AutoButtonColor = false
    button.Parent = dropdown
    
    Utils.CreateCorner(button, 6)
    Utils.CreateStroke(button, Config.Theme.BorderLight, 1)
    
    local optionsFrame = Instance.new("Frame")
    optionsFrame.Name = "Options_" .. label
    optionsFrame.Size = UDim2.new(0, 220, 0, #options * 34)
    optionsFrame.BackgroundColor3 = Config.Theme.Surface
    optionsFrame.BorderSizePixel = 0
    optionsFrame.Visible = false
    optionsFrame.ZIndex = 1000
    optionsFrame.Parent = GUI.ScreenGui
    
    Utils.CreateCorner(optionsFrame, 8)
    Utils.CreateStroke(optionsFrame, Config.Theme.Primary, 2)
    
    local optionsPadding = Instance.new("UIPadding")
    optionsPadding.PaddingTop = UDim.new(0, 4)
    optionsPadding.PaddingBottom = UDim.new(0, 4)
    optionsPadding.Parent = optionsFrame
    
    local optionsLayout = Instance.new("UIListLayout")
    optionsLayout.Padding = UDim.new(0, 2)
    optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optionsLayout.Parent = optionsFrame
    
    local currentValue = default
    
    local function updatePosition()
        local buttonPos = button.AbsolutePosition
        local buttonSize = button.AbsoluteSize
        optionsFrame.Position = UDim2.new(0, buttonPos.X, 0, buttonPos.Y + buttonSize.Y + 5)
        optionsFrame.Size = UDim2.new(0, buttonSize.X, 0, #options * 34 + 8)
    end
    
    for i, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, -8, 0, 32)
        optionButton.Position = UDim2.new(0, 4, 0, 0)
        optionButton.BackgroundColor3 = option == currentValue and Config.Theme.Primary or Config.Theme.SurfaceLight
        optionButton.BorderSizePixel = 0
        optionButton.Text = option
        optionButton.Font = Enum.Font.GothamMedium
        optionButton.TextSize = 12
        optionButton.TextColor3 = Config.Theme.Text
        optionButton.AutoButtonColor = false
        optionButton.LayoutOrder = i
        optionButton.ZIndex = 1001
        optionButton.Parent = optionsFrame
        
        Utils.CreateCorner(optionButton, 6)
        
        optionButton.MouseEnter:Connect(function()
            if option ~= currentValue then
                Utils.TweenProperty(optionButton, "BackgroundColor3", Config.Theme.Background, 0.15)
            end
        end)
        
        optionButton.MouseLeave:Connect(function()
            if option ~= currentValue then
                Utils.TweenProperty(optionButton, "BackgroundColor3", Config.Theme.SurfaceLight, 0.15)
            end
        end)
        
        optionButton.MouseButton1Click:Connect(function()
            for _, child in ipairs(optionsFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = Config.Theme.SurfaceLight
                end
            end
            
            currentValue = option
            button.Text = option .. " ▼"
            optionButton.BackgroundColor3 = Config.Theme.Primary
            optionsFrame.Visible = false
            
            callback(option)
        end)
    end
    
    button.MouseButton1Click:Connect(function()
        optionsFrame.Visible = not optionsFrame.Visible
        if optionsFrame.Visible then
            updatePosition()
        end
        button.Text = currentValue .. (optionsFrame.Visible and " ▲" or " ▼")
    end)
    
    return dropdown
end

function GUI.UpdatePerformance()
    if not GUI.PerformanceLabels then return end
    
    local fps = math.floor(1 / (tick() - State.LastUpdate))
    State.Performance.FPS = fps
    State.LastUpdate = tick()
    
    GUI.PerformanceLabels.FPS.Text = "FPS: " .. fps
    GUI.PerformanceLabels.Targets.Text = "Targets: " .. State.Performance.TargetCount
    
    local espCount = 0
    for _ in pairs(State.ESPObjects) do
        espCount = espCount + 1
    end
    GUI.PerformanceLabels.ESP.Text = "ESP Objects: " .. espCount
    
    GUI.PerformanceLabels.Mouse.Text = "Mouse: " .. (State.MouseLocked and "LOCKED" or "UNLOCKED")
    GUI.PerformanceLabels.Mouse.TextColor3 = State.MouseLocked and Config.Theme.Danger or Config.Theme.Success
    
    GUI.PerformanceLabels.GameState.Text = "State: " .. (State.IsInGame and "IN-GAME" or "LOBBY")
    GUI.PerformanceLabels.GameState.TextColor3 = State.IsInGame and Config.Theme.Success or Config.Theme.Primary
end

function GUI.ToggleVisibility()
    Config.UIVisible = not Config.UIVisible
    
    if GUI.Container then
        local targetPosition
        if Config.UIVisible then
            targetPosition = UDim2.new(0.5, -260, 0.5, -325)
        else
            targetPosition = UDim2.new(0.5, -260, 1.5, 0)
        end
        
        local tween = TweenService:Create(
            GUI.Container,
            TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Position = targetPosition}
        )
        tween:Play()
    end
end

function GUI.Destroy()
    for _, connection in ipairs(State.Connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        ESPSystem.RemoveESP(player)
    end
    
    DrawingManager.Cleanup()
    MouseManager.UnlockMouse()
    
    if GUI.ScreenGui then
        GUI.ScreenGui:Destroy()
    end
    
    if ESPHolder then
        ESPHolder:Destroy()
    end
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local MainLoop = {}

function MainLoop.Initialize()
    GUI.Create()
    
    MouseManager.UnlockMouse()
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            task.spawn(function()
                ESPSystem.CreateESP(player)
            end)
        end
    end
    
    local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        task.wait(0.5)
        ESPSystem.CreateESP(player)
    end)
    
    local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        ESPSystem.RemoveESP(player)
    end)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            player.CharacterAdded:Connect(function()
                task.wait(0.5)
                ESPSystem.UpdateESP(player)
            end)
        end
    end
    
    table.insert(State.Connections, playerAddedConnection)
    table.insert(State.Connections, playerRemovingConnection)
    
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
            GUI.ToggleVisibility()
        end
    end)
    
    table.insert(State.Connections, inputConnection)
    
    local renderConnection = RunService.RenderStepped:Connect(function()
        if not Config.Active then return end
        
        DrawingManager.UpdateFOV()
        
        local target = TargetSystem.GetClosestTarget()
        State.CurrentTarget = target
        
        if target then
            TargetSystem.AimAtTarget(target)
            DrawingManager.UpdateTargetIndicator(target.ScreenPosition)
        else
            DrawingManager.UpdateTargetIndicator(nil)
        end
    end)
    
    table.insert(State.Connections, renderConnection)
    
    local gameStateConnection = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - State.LastGameStateCheck >= 0.5 then
            State.LastGameStateCheck = now
            MouseManager.DetectGameState()
            MouseManager.UpdateMouseLock()
        end
    end)
    
    table.insert(State.Connections, gameStateConnection)
    
    local espConnection = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - State.LastESPUpdate >= 0.1 then
            State.LastESPUpdate = now
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function()
                        ESPSystem.UpdateESP(player)
                    end)
                end
            end
        end
    end)
    
    table.insert(State.Connections, espConnection)
    
    local perfConnection = RunService.Heartbeat:Connect(function()
        GUI.UpdatePerformance()
    end)
    
    table.insert(State.Connections, perfConnection)
    
    LocalPlayer.NameDisplayDistance = 0
    
    print("═══════════════════════════════════════════════════════════")
    print("  MODERN UI INITIALIZED")
    print("  Version: " .. Config.Version)
    print("  ")
    print("  Features:")
    print("  ✓ Modern tabbed interface")
    print("  ✓ Combat tab for aim assist")
    print("  ✓ Visual tab for ESP settings")
    print("  ✓ Settings tab for configuration")
    print("  ✓ Auto mouse lock detection")
    print("  ✓ Optimized performance")
    print("  ")
    print("  Controls:")
    print("  • RightShift: Toggle UI")
    print("═══════════════════════════════════════════════════════════")
end

-- ============================================================
-- STARTUP
-- ============================================================
MainLoop.Initialize()
