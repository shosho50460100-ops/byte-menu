-- byte larp v1 | Fly & Third Person WIP, Independent Fonts/Themes, Fixed Navigation
-- Created by bludmonkey vr

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local cam = Workspace.CurrentCamera

local guiParent
do
    local ok, h = pcall(function() return gethui and gethui() end)
    guiParent = (ok and h) or game:GetService("CoreGui")
end
if guiParent:FindFirstChild("ByteLarpV1") then guiParent.ByteLarpV1:Destroy() end

---------------------------------------------------------------- helpers
local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- independent themes & fonts tables
local THEMES = {
    ["Purple Haze"]  = Color3.fromRGB(140, 60, 255),
    ["Toxic Green"]  = Color3.fromRGB(0, 200, 70),
    ["Ice Blue"]     = Color3.fromRGB(40, 170, 255),
    ["Pink Neon"]    = Color3.fromRGB(255, 40, 160),
    ["Rogue Red"]    = Color3.fromRGB(255, 30, 70),
    ["Midnight Dark"]= Color3.fromRGB(50, 50, 70)
}

local FONTS = {
    ["Code Font"]    = Enum.Font.Code,
    ["Gotham Bold"]  = Enum.Font.GothamBold,
    ["Sci-Fi"]       = Enum.Font.SciFi,
    ["Arcade"]       = Enum.Font.Arcade,
    ["Antique"]      = Enum.Font.Antique
}

local Config = {
    SpeedEnabled = false, SpeedMult = 1.5,
    JumpEnabled = false, JumpMult = 1.5,
    FOV = 70, AutoSpoof3s = false, AutoSpoof1s = false,
    TpBypass = true, -- Default ON
    TpBypassSoft = true, GunDelay = 0,
    StaffDetect = true, -- Default ON
    StaffRank = 100,
    TpGlide = true, TpGlideSpeed = 25, TpInside = true, TpYOffset = 0,
    ESPEnabled = false, FullbrightEnabled = false,
    ClickVolume = 0.6, ClickId = "6895079853",
    ThemeName = "Purple Haze", FontName = "Code Font",
    MusicId = "1837879082", MusicVolume = 0.5, MusicPlaying = false
}

local activeColor = THEMES[Config.ThemeName] or THEMES["Purple Haze"]
local activeFont = FONTS[Config.FontName] or Enum.Font.Code
local baseBg = Color3.fromRGB(20, 12, 35)
local cardBg = Color3.fromRGB(38, 16, 68)

local clickSound = make("Sound", {
    Name = "MonkeyClick", SoundId = "rbxassetid://" .. Config.ClickId,
    Volume = Config.ClickVolume, PlaybackSpeed = 1, Looped = false,
}, SoundService)

local function playClick()
    pcall(function()
        clickSound.PlaybackSpeed = 0.96 + math.random() * 0.08
        clickSound.TimePosition = 0
        clickSound:Play()
    end)
end

---------------------------------------------------------------- background music player instance
local bgMusic = make("Sound", {
    Name = "ByteMusic", SoundId = "rbxassetid://" .. Config.MusicId,
    Volume = Config.MusicVolume, Looped = true, PlaybackSpeed = 1
}, SoundService)

local function updateMusicState()
    pcall(function()
        bgMusic.SoundId = "rbxassetid://" .. Config.MusicId
        bgMusic.Volume = Config.MusicVolume
        if Config.MusicPlaying then
            if not bgMusic.IsPlaying then bgMusic:Play() end
        else
            bgMusic:Stop()
        end
    end)
end

---------------------------------------------------------------- AUTO NAME SPOOFER
local nameList = {
    "diddy", "sigma", "aura", "666", "dumbass", "stupid", "dump", "larp", "nexus", 
    "soulzzz", "gooby", "gubby", "kreek", "get hacked", "monkeymod lolz", "monkeymod"
}
local nameIndex = 1
local spoof3sOn = Config.AutoSpoof3s
local spoof1sOn = Config.AutoSpoof1s
local spoof3sThread = nil
local spoof1sThread = nil

local function fireNameSpoof(newName)
    local mtn = ReplicatedStorage:FindFirstChild("MTN")
    local remotes = mtn and mtn:FindFirstChild("Remotes")
    local action = remotes and remotes:FindFirstChild("Action")
    if action then
        pcall(function() action:FireServer("name", newName) end)
    end
end

local function startSpoof3s()
    if spoof3sThread then task.cancel(spoof3sThread) end
    spoof3sOn = true
    spoof3sThread = task.spawn(function()
        while spoof3sOn do
            fireNameSpoof(nameList[nameIndex])
            nameIndex = nameIndex % #nameList + 1
            task.wait(3)
        end
    end)
end

local function stopSpoof3s()
    spoof3sOn = false
    if spoof3sThread then task.cancel(spoof3sThread) spoof3sThread = nil end
end

local function startSpoof1s()
    if spoof1sThread then task.cancel(spoof1sThread) end
    spoof1sOn = true
    spoof1sThread = task.spawn(function()
        while spoof1sOn do
            fireNameSpoof(nameList[nameIndex])
            nameIndex = nameIndex % #nameList + 1
            task.wait(1)
        end
    end)
end

local function stopSpoof1s()
    spoof1sOn = false
    if spoof1sThread then task.cancel(spoof1sThread) spoof1sThread = nil end
end

---------------------------------------------------------------- UI BUILDER
local gui = make("ScreenGui", {Name = "ByteLarpV1", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, guiParent)

local mainFrame = make("Frame", {
    Size = UDim2.fromOffset(420, 560),
    Position = UDim2.new(0.5, -210, 0.5, -280),
    BackgroundColor3 = baseBg,
    BorderSizePixel = 0,
}, gui)

local mainStroke = make("UIStroke", {Thickness = 2, Color = activeColor, Transparency = 0.2}, mainFrame)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, mainFrame)

-- Top Header
local header = make("Frame", {
    Size = UDim2.new(1, -16, 0, 50),
    Position = UDim2.fromOffset(8, 8),
    BackgroundColor3 = cardBg,
    BorderSizePixel = 0
}, mainFrame)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, header)
local headerStroke = make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.4}, header)

local titleLabel = make("TextLabel", {
    Size = UDim2.new(0, 220, 0, 24), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
    Text = "byte larp v1", Font = activeFont, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left
}, header)

local subTitleLabel = make("TextLabel", {
    Size = UDim2.new(0, 220, 0, 18), Position = UDim2.fromOffset(10, 26), BackgroundTransparency = 1,
    Text = "made by bludmonkey vr 🐵", Font = activeFont, TextSize = 10, TextColor3 = Color3.fromRGB(200, 180, 220), TextXAlignment = Enum.TextXAlignment.Left
}, header)

-- FPS Box
local fpsBox = make("Frame", {
    Size = UDim2.fromOffset(75, 34), Position = UDim2.new(1, -135, 0.5, -17),
    BackgroundColor3 = baseBg, BorderSizePixel = 0
}, header)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, fpsBox)
local fpsBoxStroke = make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.5}, fpsBox)

local fpsText = make("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "FPS: 60",
    Font = activeFont, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center
}, fpsBox)

task.spawn(function()
    local lastUpdate = tick()
    local frames = 0
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        if tick() - lastUpdate >= 1 then
            fpsText.Text = "FPS: " .. tostring(frames)
            frames = 0
            lastUpdate = tick()
        end
    end)
end)

local exitBtn = make("TextButton", {
    Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -12, 0.5, -17), AnchorPoint = Vector2.new(1, 0),
    BackgroundColor3 = baseBg, Text = "🚪", TextSize = 14, BorderSizePixel = 0, AutoButtonColor = false
}, header)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, exitBtn)
local exitBtnStroke = make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.5}, exitBtn)
exitBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Categories Bar (Top)
local catContainer = make("ScrollingFrame", {
    Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 66),
    BackgroundTransparency = 1, CanvasSize = UDim2.new(3.0, 0, 0, 0), ScrollBarThickness = 0, BorderSizePixel = 0
}, mainFrame)
make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, catContainer)

-- Content Frame
local contentFrame = make("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -170), Position = UDim2.fromOffset(8, 108),
    BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 4,
    ScrollBarImageColor3 = activeColor
}, mainFrame)
make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, contentFrame)

-- Bottom Navigation
local navBar = make("Frame", {
    Size = UDim2.new(1, -16, 0, 48), Position = UDim2.new(0, 8, 1, -56),
    BackgroundColor3 = cardBg, BorderSizePixel = 0, ZIndex = 10
}, mainFrame)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, navBar)
local navStroke = make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.4}, navBar)

local prevPageBtn = make("TextButton", {
    Size = UDim2.fromOffset(48, 36), Position = UDim2.fromOffset(6, 6),
    BackgroundColor3 = baseBg, Text = "<", Font = activeFont, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 20
}, navBar)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, prevPageBtn)
local prevStroke = make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.5}, prevPageBtn)

local homeBtn = make("TextButton", {
    Size = UDim2.new(1, -120, 0, 36), Position = UDim2.fromOffset(60, 6),
    BackgroundColor3 = baseBg, Text = "🏠 Home", Font = activeFont, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 20
}, navBar)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, homeBtn)
local homeStroke = make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.5}, homeBtn)

local nextPageBtn = make("TextButton", {
    Size = UDim2.fromOffset(48, 36), Position = UDim2.new(1, -54, 0.5, -18),
    BackgroundColor3 = baseBg, Text = ">", Font = activeFont, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 20
}, navBar)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, nextPageBtn)
local nextStroke = make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.5}, nextPageBtn)

---------------------------------------------------------------- Staff Detect Popup
local STAFF_LIST = {
    ["veliaxwx"] = true,
    ["zombiemasters"] = true,
    ["analytica"] = true
}

local function showStaffPopup(staffName)
    pcall(function()
        local popup = make("Frame", {
            Size = UDim2.fromOffset(320, 90),
            Position = UDim2.new(0.5, -160, 0, -120),
            BackgroundColor3 = Color3.fromRGB(35, 10, 15),
            BorderSizePixel = 0,
            ZIndex = 999
        }, gui)
        make("UICorner", {CornerRadius = UDim.new(0, 10)}, popup)
        make("UIStroke", {Thickness = 2, Color = Color3.fromRGB(255, 40, 40)}, popup)

        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 8), BackgroundTransparency = 1,
            Text = "⚠️ STAFF JOINED SERVER! ⚠️", Font = activeFont, TextSize = 13,
            TextColor3 = Color3.fromRGB(255, 80, 80), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 1000
        }, popup)

        make("TextLabel", {
            Size = UDim2.new(1, -20, 0, 42), Position = UDim2.fromOffset(10, 38), BackgroundTransparency = 1,
            Text = "Staff member '" .. staffName .. "' has joined your server!", Font = activeFont, TextSize = 11,
            TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 1000
        }, popup)

        TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
            Position = UDim2.new(0.5, -160, 0, 20)
        }):Play()

        task.delay(6, function()
            if popup and popup.Parent then
                TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
                    Position = UDim2.new(0.5, -160, 0, -120)
                }):Play()
                task.delay(0.4, function() popup:Destroy() end)
            end
        end)
    end)
end

Players.PlayerAdded:Connect(function(p)
    if Config.StaffDetect and STAFF_LIST[p.Name:lower()] then
        showStaffPopup(p.Name)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= lp and Config.StaffDetect and STAFF_LIST[p.Name:lower()] then
        showStaffPopup(p.Name)
    end
end

---------------------------------------------------------------- Data Structure & Handlers
local cfgOrig = {}
local mult = {Speed = Config.SpeedMult, Jump = Config.JumpMult}
local on = {Speed = Config.SpeedEnabled, Jump = Config.JumpEnabled}

local function ensureCfg()
    if next(cfgOrig) then return end
    for _, t in ipairs(getgc(true)) do
        if type(t) == "table" then
            local ok, hit = pcall(function()
                local s, sp, j = rawget(t, "Speed"), rawget(t, "SprintSpeed"), rawget(t, "JumpSpeed")
                return type(s) == "number" and type(sp) == "number" and type(j) == "number" and sp > s and j > s
            end)
            if ok and hit then
                cfgOrig[t] = {Speed = rawget(t, "Speed"), SprintSpeed = rawget(t, "SprintSpeed"), JumpSpeed = rawget(t, "JumpSpeed")}
            end
        end
    end
end

local function applyCfg()
    local sm = on.Speed and mult.Speed or 1
    local jm = on.Jump and mult.Jump or 1
    for t, o in pairs(cfgOrig) do
        pcall(function()
            if setreadonly then setreadonly(t, false) end
            rawset(t, "Speed", o.Speed * sm)
            rawset(t, "SprintSpeed", o.SprintSpeed * sm)
            rawset(t, "JumpSpeed", o.JumpSpeed * jm)
        end)
    end
end

local function restoreCfg()
    for t, o in pairs(cfgOrig) do
        pcall(function()
            if setreadonly then setreadonly(t, false) end
            rawset(t, "Speed", o.Speed)
            rawset(t, "SprintSpeed", o.SprintSpeed)
            rawset(t, "JumpSpeed", o.JumpSpeed)
        end)
    end
end

local updateThemeAndFont, renderPage

local categoriesData = {
    ["movement"] = {
        {name = "Speed Enabled", desc = "Enable custom speed multiplier.", type = "toggle", state = function() return Config.SpeedEnabled end, cb = function(v) on.Speed = v Config.SpeedEnabled = v ensureCfg() if v then applyCfg() else restoreCfg() end end},
        {name = "Speed Multiplier", desc = "Adjust movement speed scale.", type = "input", val = tostring(Config.SpeedMult), cb = function(val) local n = tonumber(val) if n then mult.Speed = n Config.SpeedMult = n if on.Speed then applyCfg() end end end},
        {name = "Jump Enabled", desc = "Enable custom jump multiplier.", type = "toggle", state = function() return Config.JumpEnabled end, cb = function(v) on.Jump = v Config.JumpEnabled = v ensureCfg() if v then applyCfg() else restoreCfg() end end},
        {name = "Jump Multiplier", desc = "Adjust jump power scale.", type = "input", val = tostring(Config.JumpMult), cb = function(val) local n = tonumber(val) if n then mult.Jump = n Config.JumpMult = n if on.Jump then applyCfg() end end end},
        {name = "Fly Enabled", desc = "Toggle character flight mode.", type = "wip"},
        {name = "Fly Speed", desc = "Set flight velocity magnitude.", type = "wip"}
    },
    ["player"] = {
        {name = "Third Person", desc = "Enable third person camera view.", type = "wip"},
        {name = "Third Person Dist", desc = "Set zoom distance.", type = "wip"},
        {name = "Field Of View", desc = "Adjust camera FOV.", type = "input", val = tostring(Config.FOV), cb = function(val) local n = tonumber(val) if n then Config.FOV = n cam.FieldOfView = n end end},
        {name = "TP Glide", desc = "Smooth sliding teleport motion.", type = "wip"},
        {name = "TP Glide Speed", desc = "Glide movement speed configuration.", type = "wip"},
        {name = "TP Inside", desc = "Teleport inside targets.", type = "wip"}
    },
    ["cheats"] = {
        {name = "Tag Gun", desc = "Enable tag gun remote firing.", type = "wip"},
        {name = "Tag Gun Remote", desc = "Use alternative remote path.", type = "wip"},
        {name = "Follow Gun", desc = "Lock onto targeted players.", type = "wip"},
        {name = "Tag Aura", desc = "Automatically tag nearby players.", type = "wip"},
        {name = "Aura Range", desc = "Radius for tag aura.", type = "wip"},
        {name = "Gun Delay", desc = "Delay between remote calls.", type = "wip"}
    },
    ["utility"] = {
        {name = "Fullbright", desc = "Remove ambient shadows and darkness.", type = "toggle", state = function() return Config.FullbrightEnabled end, cb = function(v) Config.FullbrightEnabled = v Lighting.Brightness = v and 2 or 1 Lighting.ClockTime = v and 14 or 12 end},
        {name = "ESP Enabled", desc = "Render player ESP highlights.", type = "wip"},
        {name = "TP Bypass", desc = "Bypass teleport checks.", type = "toggle", state = function() return Config.TpBypass end, cb = function(v) Config.TpBypass = v end},
        {name = "TP Bypass Soft", desc = "Soft teleport bypass mode.", type = "toggle", state = function() return Config.TpBypassSoft end, cb = function(v) Config.TpBypassSoft = v end},
        {name = "Staff Detect", desc = "Detect staff members in server.", type = "toggle", state = function() return Config.StaffDetect end, cb = function(v) Config.StaffDetect = v end},
        {name = "Reset Character", desc = "Respawn yourself instantly.", type = "button", cb = function() local h = getHum() if h then h.Health = 0 end end}
    },
    ["settings"] = {
        {name = "Save Config", desc = "Manually save settings to disk.", type = "button", cb = function()
            local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
            if ok and writefile then pcall(function() writefile("MonkeyMod_Config.json", encoded) end) end
        end},
        {name = "Animated Border", desc = "Enable glowing animated borders.", type = "toggle", state = function() return Config.AnimatedBorder end, cb = function(v) Config.AnimatedBorder = v end},
        {name = "Click Volume", desc = "SFX click volume level.", type = "input", val = tostring(Config.ClickVolume), cb = function(val) local n = tonumber(val) if n then Config.ClickVolume = n clickSound.Volume = n end end},
        {name = "Staff Rank", desc = "Minimum rank threshold.", type = "input", val = tostring(Config.StaffRank), cb = function(val) local n = tonumber(val) if n then Config.StaffRank = n end end},
        {name = "Click Sound ID", desc = "Audio asset ID for clicks.", type = "input", val = tostring(Config.ClickId), cb = function(val) Config.ClickId = val clickSound.SoundId = "rbxassetid://" .. val end},
        {name = "Staff Alert System", desc = "Active staff detection notifications.", type = "toggle", state = function() return Config.StaffDetect end, cb = function(v) Config.StaffDetect = v end}
    },
    ["spoofers"] = {
        {name = "Auto Spoof (3s)", desc = "Cycle names every 3 seconds.", type = "toggle", state = function() return spoof3sOn end, cb = function(s)
            spoof3sOn = s Config.AutoSpoof3s = s
            if s then if spoof1sOn then stopSpoof1s() Config.AutoSpoof1s = false end startSpoof3s() else stopSpoof3s() end
        end},
        {name = "Auto Spoof (1s)", desc = "Cycle names every 1 second.", type = "toggle", state = function() return spoof1sOn end, cb = function(s)
            spoof1sOn = s Config.AutoSpoof1s = s
            if s then if spoof3sOn then stopSpoof3s() Config.AutoSpoof3s = false end startSpoof1s() else stopSpoof1s() end
        end},
        {name = "TP Y Offset", desc = "Vertical teleport offset.", type = "input", val = tostring(Config.TpYOffset), cb = function(val) local n = tonumber(val) if n then Config.TpYOffset = n end end},
        {name = "Tag Delay", desc = "Interval between tag all requests.", type = "wip"},
        {name = "Tag All Enabled", desc = "Tag every player in the server.", type = "wip"},
        {name = "Name Spoof Bypass", desc = "Alternative remote routing.", type = "wip"}
    },
    ["themes"] = {
        {name = "Purple Haze Theme", desc = "Set color theme to Purple Haze.", type = "button", cb = function() Config.ThemeName = "Purple Haze" updateThemeAndFont() end},
        {name = "Toxic Green Theme", desc = "Set color theme to Toxic Green.", type = "button", cb = function() Config.ThemeName = "Toxic Green" updateThemeAndFont() end},
        {name = "Ice Blue Theme", desc = "Set color theme to Ice Blue.", type = "button", cb = function() Config.ThemeName = "Ice Blue" updateThemeAndFont() end},
        {name = "Pink Neon Theme", desc = "Set color theme to Pink Neon.", type = "button", cb = function() Config.ThemeName = "Pink Neon" updateThemeAndFont() end},
        {name = "Rogue Red Theme", desc = "Set color theme to Rogue Red.", type = "button", cb = function() Config.ThemeName = "Rogue Red" updateThemeAndFont() end},
        {name = "Midnight Dark Theme", desc = "Set color theme to Midnight Dark.", type = "button", cb = function() Config.ThemeName = "Midnight Dark" updateThemeAndFont() end}
    },
    ["fonts"] = {
        {name = "Code Font", desc = "Set UI font style to Code.", type = "button", cb = function() Config.FontName = "Code Font" updateThemeAndFont() end},
        {name = "Gotham Font", desc = "Set UI font style to Gotham Bold.", type = "button", cb = function() Config.FontName = "Gotham Bold" updateThemeAndFont() end},
        {name = "Sci-Fi Font", desc = "Set UI font style to Sci-Fi.", type = "button", cb = function() Config.FontName = "Sci-Fi" updateThemeAndFont() end},
        {name = "Arcade Font", desc = "Set UI font style to Arcade.", type = "button", cb = function() Config.FontName = "Arcade" updateThemeAndFont() end},
        {name = "Antique Font", desc = "Set UI font style to Antique.", type = "button", cb = function() Config.FontName = "Antique" updateThemeAndFont() end}
    },
    ["music"] = {
        {name = "Play / Pause Music", desc = "Toggle background music stream.", type = "toggle", state = function() return Config.MusicPlaying end, cb = function(v) Config.MusicPlaying = v updateMusicState() end},
        {name = "Music ID", desc = "Audio track asset ID.", type = "input", val = tostring(Config.MusicId), cb = function(val) Config.MusicId = val updateMusicState() end},
        {name = "Music Volume", desc = "Adjust audio output level.", type = "input", val = tostring(Config.MusicVolume), cb = function(val) local n = tonumber(val) if n then Config.MusicVolume = n updateMusicState() end end},
        {name = "Stop Music", desc = "Halts audio playback completely.", type = "button", cb = function() Config.MusicPlaying = false updateMusicState() end},
        {name = "Loop Status", desc = "Background audio loop enabled.", type = "toggle", state = function() return true end, cb = function() end},
        {name = "Stream Quality", desc = "High fidelity audio mode.", type = "wip"}
    },
    ["credits"] = {
        {name = "Main Creator", desc = "Made by bludmonkey vr 🐵", type = "button", cb = function() end},
        {name = "Menu Version", desc = "byte larp v1 - Powered by original script core", type = "button", cb = function() end},
        {name = "UI Framework", desc = "Designed with custom neon styling", type = "button", cb = function() end},
        {name = "Anti-Cheat Module", desc = "Integrated background scanner active", type = "button", cb = function() end},
        {name = "Persistence System", desc = "JSON configuration handler enabled", type = "button", cb = function() end},
        {name = "Disclaimer", desc = "Always use alt accounts when exploiting.", type = "button", cb = function() end}
    }
}

updateThemeAndFont = function()
    activeColor = THEMES[Config.ThemeName] or THEMES["Purple Haze"]
    activeFont = FONTS[Config.FontName] or Enum.Font.Code

    mainFrame.BackgroundColor3 = baseBg
    header.BackgroundColor3 = cardBg
    navBar.BackgroundColor3 = cardBg
    fpsBox.BackgroundColor3 = baseBg
    exitBtn.BackgroundColor3 = baseBg
    prevPageBtn.BackgroundColor3 = baseBg
    homeBtn.BackgroundColor3 = baseBg
    nextPageBtn.BackgroundColor3 = baseBg

    mainStroke.Color = activeColor
    headerStroke.Color = activeColor
    fpsBoxStroke.Color = activeColor
    exitBtnStroke.Color = activeColor
    navStroke.Color = activeColor
    prevStroke.Color = activeColor
    homeStroke.Color = activeColor
    nextStroke.Color = activeColor
    contentFrame.ScrollBarImageColor3 = activeColor

    titleLabel.Font = activeFont
    subTitleLabel.Font = activeFont
    fpsText.Font = activeFont
    prevPageBtn.Font = activeFont
    homeBtn.Font = activeFont
    nextPageBtn.Font = activeFont

    for _, btn in ipairs(catContainer:GetChildren()) do
        if btn:IsA("TextButton") then
            btn.BackgroundColor3 = cardBg
            btn.Font = activeFont
            local s = btn:FindFirstChildOfClass("UIStroke")
            if s then s.Color = activeColor end
        end
    end

    renderPage()
end

local currentCategory = "movement"
local currentPage = 1
local ITEMS_PER_PAGE = 6

renderPage = function()
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local items = categoriesData[currentCategory] or {}
    local totalPages = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))
    if currentPage > totalPages then currentPage = totalPages end

    local startIndex = (currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIndex = math.min(startIndex + ITEMS_PER_PAGE - 1, #items)

    for i = startIndex, endIndex do
        local modData = items[i]
        
        local card = make("Frame", {
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = modData.type == "wip" and Color3.fromRGB(45, 20, 25) or cardBg,
            BorderSizePixel = 0
        }, contentFrame)
        make("UICorner", {CornerRadius = UDim.new(0, 8)}, card)
        make("UIStroke", {Thickness = 1, Color = modData.type == "wip" and Color3.fromRGB(200, 60, 60) or activeColor, Transparency = 0.5}, card)

        make("TextLabel", {
            Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1,
            Text = modData.type == "wip" and (modData.name .. " [WIP]") or modData.name,
            Font = activeFont, TextSize = 13,
            TextColor3 = modData.type == "wip" and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Center
        }, card)

        make("TextLabel", {
            Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 26), BackgroundTransparency = 1,
            Text = modData.type == "wip" and "Work in Progress - Currently Unavailable" or modData.desc,
            Font = activeFont, TextSize = 10, TextColor3 = Color3.fromRGB(200, 180, 220), TextXAlignment = Enum.TextXAlignment.Center
        }, card)

        if modData.type == "toggle" then
            local activeState = modData.state and modData.state() or false
            card.BackgroundColor3 = activeState and activeColor or cardBg
            
            local toggleBtn = make("TextButton", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ""
            }, card)
            
            toggleBtn.MouseButton1Click:Connect(function()
                playClick()
                activeState = not activeState
                card.BackgroundColor3 = activeState and activeColor or cardBg
                if modData.cb then modData.cb(activeState) end
            end)
        elseif modData.type == "input" then
            local textBox = make("TextBox", {
                Size = UDim2.fromOffset(90, 24), Position = UDim2.new(1, -100, 0.5, -12),
                BackgroundColor3 = baseBg, Text = modData.val or "",
                Font = activeFont, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
                ClearTextOnFocus = false, BorderSizePixel = 0
            }, card)
            make("UICorner", {CornerRadius = UDim.new(0, 4)}, textBox)
            make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.5}, textBox)

            textBox.FocusLost:Connect(function()
                if modData.cb then modData.cb(textBox.Text) end
            end)
        elseif modData.type == "button" then
            local actionBtn = make("TextButton", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ""
            }, card)

            actionBtn.MouseButton1Click:Connect(function()
                playClick()
                if modData.cb then modData.cb() end
                TweenService:Create(card, TweenInfo.new(0.1), {BackgroundColor3 = activeColor}):Play()
                task.delay(0.15, function()
                    TweenService:Create(card, TweenInfo.new(0.1), {BackgroundColor3 = cardBg}):Play()
                end)
            end)
        elseif modData.type == "wip" then
            make("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = "🔒 LOCKED", Font = activeFont, TextSize = 11,
                TextColor3 = Color3.fromRGB(255, 100, 100), TextXAlignment = Enum.TextXAlignment.Right,
                Position = UDim2.fromOffset(-15, 0)
            }, card)
        end
    end
end

-- Render Category Buttons on top
local categoriesList = {"movement", "player", "cheats", "utility", "settings", "spoofers", "themes", "fonts", "music", "credits"}
for _, catName in ipairs(categoriesList) do
    local catBtn = make("TextButton", {
        Size = UDim2.fromOffset(90, 32), BackgroundColor3 = cardBg,
        Text = catName:upper(), Font = activeFont, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, AutoButtonColor = false
    }, catContainer)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, catBtn)
    make("UIStroke", {Thickness = 1, Color = activeColor, Transparency = 0.5}, catBtn)

    catBtn.MouseButton1Click:Connect(function()
        playClick()
        currentCategory = catName
        currentPage = 1
        renderPage()
    end)
end
catContainer.CanvasSize = UDim2.new(0, #categoriesList * 96, 0, 0)

-- Fully Fixed Page Navigation Buttons
prevPageBtn.MouseButton1Click:Connect(function()
    playClick()
    local items = categoriesData[currentCategory] or {}
    local totalPages = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))
    currentPage = currentPage - 1
    if currentPage < 1 then currentPage = totalPages end
    renderPage()
end)

nextPageBtn.MouseButton1Click:Connect(function()
    playClick()
    local items = categoriesData[currentCategory] or {}
    local totalPages = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))
    currentPage = currentPage + 1
    if currentPage > totalPages then currentPage = 1 end
    renderPage()
end)

homeBtn.MouseButton1Click:Connect(function()
    playClick()
    currentPage = 1
    renderPage()
end)

renderPage()

---------------------------------------------------------------- Robust TP Bypass Integration
local lastValidCF = nil
RunService.Stepped:Connect(function()
    if Config.TpBypass then
        local root = getRoot()
        if root then
            if lastValidCF and (root.Position - lastValidCF.Position).Magnitude > 45 then
                pcall(function()
                    root.CFrame = lastValidCF
                end)
            else
                lastValidCF = root.CFrame
            end
        end
    else
        lastValidCF = nil
    end
end)
