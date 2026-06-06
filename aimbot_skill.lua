local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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

-- ================= GUI =================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local ToggleBtn = Instance.new("TextButton")
local CloseBtn = Instance.new("TextButton")

ScreenGui.Name = "AimbotSkillGui"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -50)
MainFrame.Size = UDim2.new(0, 200, 0, 100)
MainFrame.Active = true
MainFrame.Draggable = true

Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "Pinat Aimbot Skill"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14

ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Parent = MainFrame
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ToggleBtn.Position = UDim2.new(0.1, 0, 0.4, 0)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 30)
ToggleBtn.Font = Enum.Font.SourceSans
ToggleBtn.Text = "Aimbot: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 18

CloseBtn.Name = "CloseBtn"
CloseBtn.Parent = MainFrame
CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
CloseBtn.Position = UDim2.new(0.85, 0, 0, 0)
CloseBtn.Size = UDim2.new(0.15, 0, 0, 25)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 14

ToggleBtn.MouseButton1Click:Connect(function()
    SilentAim_Enabled = not SilentAim_Enabled
    if SilentAim_Enabled then
        ToggleBtn.Text = "Aimbot: ON"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        startRender()
    else
        ToggleBtn.Text = "Aimbot: OFF"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        stopRender()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    SilentAim_Enabled = false
    stopRender()
    clearConnections()
    ScreenGui:Destroy()
end)
