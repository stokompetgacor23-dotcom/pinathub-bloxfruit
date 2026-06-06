local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local SilentAim_Enabled = false
local PredictionEnabled = true
local PredictionAmount = 0.1
local maxRange = 1000

local renderConnection = nil
local currentTool = nil
local PlayersPosition = nil
local Selectedplayer = nil
local characterConnections = {}

-- ================= HRP =================
local function getHRP(model)
    return model and model:FindFirstChild("HumanoidRootPart")
end

-- ================= CLEAR =================
local function clearConnections()
    for _, c in ipairs(characterConnections) do
        pcall(function() c:Disconnect() end)
    end
    characterConnections = {}
end

-- ================= TEAM CHECK =================
local function isEnemy(plr)
    if not plr or plr == player then return false end
    if not player.Team or not plr.Team then return true end
    return player.Team ~= plr.Team
end

-- ================= PREDICTION =================
local function getPredictedPosition(hrp)
    if not hrp then return nil end
    local hum = hrp.Parent:FindFirstChildWhichIsA("Humanoid")
    if not hum or not PredictionEnabled or hum.WalkSpeed < 5 then
        return hrp.Position
    end
    return hrp.Position + (hrp.Velocity * PredictionAmount)
end

-- ================= CLOSEST PLAYER =================
local function getClosestPlayer(lpHRP)
    local closest, dist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) and plr.Character then
            local hum = plr.Character:FindFirstChildWhichIsA("Humanoid")
            local hrp = getHRP(plr.Character)
            if hum and hum.Health > 0 and hrp then
                local d = (hrp.Position - lpHRP.Position).Magnitude
                if d < dist and d <= maxRange then
                    dist = d
                    closest = plr
                end
            end
        end
    end
    return closest
end

-- ================= SKILL READY =================
local function isSkillReadyForTool(toolName)
    if not toolName then return false end
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end

    local skills = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Skills")
    if not skills then return false end

    local tool = skills:FindFirstChild(toolName)
    if not tool then return false end

    for _, key in ipairs({"Z","X","C","V"}) do
        local skill = tool:FindFirstChild(key)
        if skill and skill:FindFirstChild("Cooldown") then
            if skill.Cooldown.Size.X.Scale == 1 then
                return true
            end
        end
    end
    return false
end

-- ================= RENDER LOOP =================
local function startRender()
    if renderConnection then return end

    renderConnection = RunService.RenderStepped:Connect(function()
        if not SilentAim_Enabled then return end

        local char = player.Character
        local hrp = char and getHRP(char)
        if not hrp then return end

        local target = Selectedplayer or getClosestPlayer(hrp)
        if not (target and target.Character) then
            PlayersPosition = nil
            return
        end

        local thrp = getHRP(target.Character)
        if not thrp then return end

        PlayersPosition = getPredictedPosition(thrp)

        if currentTool and isSkillReadyForTool(currentTool.Name) then
            local look = (Vector3.new(
                PlayersPosition.X,
                hrp.Position.Y,
                PlayersPosition.Z
            ) - hrp.Position).Unit

            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look)
        end
    end)
end

local function stopRender()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
end

-- ================= TOOL TRACK =================
local function onCharacterAdded(char)
    clearConnections()
    table.insert(characterConnections,
        char.ChildAdded:Connect(function(obj)
            if obj:IsA("Tool") then
                currentTool = obj
            end
        end)
    )
    -- Check for existing tool
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then
            currentTool = obj
        end
    end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

-- ================= METAMETHOD =================
local oldNamecall
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)

    oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if (method == "FireServer" or method == "InvokeServer")
            and SilentAim_Enabled
            and PlayersPosition
            and typeof(args[1]) == "Vector3" then

            args[1] = PlayersPosition
            return oldNamecall(self, unpack(args))
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end)

-- ================= MODERN GUI =================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local UIStroke = Instance.new("UIStroke")
local TitleBar = Instance.new("Frame")
local TitleBarCorner = Instance.new("UICorner")
local Title = Instance.new("TextLabel")
local CloseBtn = Instance.new("TextButton")
local ContentFrame = Instance.new("Frame")
local ToggleBtn = Instance.new("TextButton")
local ToggleBtnCorner = Instance.new("UICorner")
local ToggleIndicator = Instance.new("Frame")
local ToggleIndicatorCorner = Instance.new("UICorner")

ScreenGui.Name = "AimbotSkillGuiModern"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -60)
MainFrame.Size = UDim2.new(0, 220, 0, 120)
MainFrame.BorderSizePixel = 0

UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

UIStroke.Color = Color3.fromRGB(40, 40, 40)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

TitleBar.Name = "TitleBar"
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BorderSizePixel = 0

TitleBarCorner.CornerRadius = UDim.new(0, 10)
TitleBarCorner.Parent = TitleBar

-- Patch to hide bottom corners of title bar
local TitleBarBottomMask = Instance.new("Frame")
TitleBarBottomMask.Name = "BottomMask"
TitleBarBottomMask.Parent = TitleBar
TitleBarBottomMask.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBarBottomMask.BorderSizePixel = 0
TitleBarBottomMask.Position = UDim2.new(0, 0, 1, -5)
TitleBarBottomMask.Size = UDim2.new(1, 0, 0, 5)

Title.Name = "Title"
Title.Parent = TitleBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "Aimbot Skill"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

CloseBtn.Name = "CloseBtn"
CloseBtn.Parent = TitleBar
CloseBtn.BackgroundTransparency = 1
CloseBtn.Position = UDim2.new(1, -35, 0, 0)
CloseBtn.Size = UDim2.new(0, 35, 1, 0)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
CloseBtn.TextSize = 20

ContentFrame.Name = "Content"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundTransparency = 1
ContentFrame.Position = UDim2.new(0, 0, 0, 35)
ContentFrame.Size = UDim2.new(1, 0, 1, -35)

ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Parent = ContentFrame
ToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ToggleBtn.Position = UDim2.new(0.5, -90, 0.5, -20)
ToggleBtn.Size = UDim2.new(0, 180, 0, 40)
ToggleBtn.AutoButtonColor = false
ToggleBtn.Font = Enum.Font.Gotham
ToggleBtn.Text = "Silent Aim"
ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
ToggleBtn.TextSize = 14
ToggleBtn.TextXAlignment = Enum.TextXAlignment.Left
ToggleBtn.ClipsDescendants = true

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 15)
padding.Parent = ToggleBtn

ToggleBtnCorner.CornerRadius = UDim.new(0, 8)
ToggleBtnCorner.Parent = ToggleBtn

ToggleIndicator.Name = "Indicator"
ToggleIndicator.Parent = ToggleBtn
ToggleIndicator.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
ToggleIndicator.Position = UDim2.new(1, -45, 0.5, -10)
ToggleIndicator.Size = UDim2.new(0, 30, 0, 20)

ToggleIndicatorCorner.CornerRadius = UDim.new(1, 0)
ToggleIndicatorCorner.Parent = ToggleIndicator

local Switch = Instance.new("Frame")
Switch.Name = "Switch"
Switch.Parent = ToggleIndicator
Switch.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Switch.Position = UDim2.new(0, 2, 0.5, -8)
Switch.Size = UDim2.new(0, 16, 0, 16)

local SwitchCorner = Instance.new("UICorner")
SwitchCorner.CornerRadius = UDim.new(1, 0)
SwitchCorner.Parent = Switch

-- ================= DRAGGING =================
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- ================= LOGIC =================
local function setToggle(state)
    SilentAim_Enabled = state
    local color = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(50, 50, 50)
    local switchPos = state and UDim2.new(0, 12, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)

    TweenService:Create(ToggleIndicator, TweenInfo.new(0.3), {BackgroundColor3 = color}):Play()
    TweenService:Create(Switch, TweenInfo.new(0.3), {Position = switchPos}):Play()

    if state then
        startRender()
    else
        stopRender()
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    setToggle(not SilentAim_Enabled)
end)

CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 50, 50)}):Play()
end)

CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play()
end)

CloseBtn.MouseButton1Click:Connect(function()
    SilentAim_Enabled = false
    stopRender()
    clearConnections()
    ScreenGui:Destroy()
end)
