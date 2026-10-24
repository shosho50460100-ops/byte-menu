-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Initialize Luraph globals if they do not exist.
loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()
getfenv().PP_SCRAMBLE_NUM = function(...) return ... end
getfenv().PP_SCRAMBLE_STR = function(...) return ... end
getfenv().PP_SCRAMBLE_RE_NUM = function(...) return ... end

local ByteMenu = {}

-- Services.
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local lightingService = game:GetService("Lighting")
local teleportService = game:GetService("TeleportService")
local httpService = game:GetService("HttpService")

-- Constants.
-- Replace with your uploaded asset id (e.g. "rbxassetid://123456789").
local BACKGROUND_IMAGE_ASSET = "rbxassetid://0"

local THEMES = {
	{ name = "Shield", accent = Color3.fromRGB(216, 0, 255), gradientA = Color3.fromRGB(10, 0, 14), gradientB = Color3.fromRGB(60, 0, 80) },
	{ name = "Blue", accent = Color3.fromRGB(70, 130, 220), gradientA = Color3.fromRGB(14, 20, 34), gradientB = Color3.fromRGB(30, 45, 80) },
	{ name = "Red", accent = Color3.fromRGB(220, 70, 90), gradientA = Color3.fromRGB(30, 12, 16), gradientB = Color3.fromRGB(80, 25, 35) },
	{ name = "Green", accent = Color3.fromRGB(80, 200, 130), gradientA = Color3.fromRGB(12, 24, 18), gradientB = Color3.fromRGB(25, 70, 45) },
}
local FONTS = {
	{ name = "Gotham Bold", font = Enum.Font.GothamBold },
	{ name = "Gotham", font = Enum.Font.Gotham },
	{ name = "Source Sans", font = Enum.Font.SourceSansBold },
	{ name = "Code", font = Enum.Font.Code },
}
local THEME_PANEL = Color3.fromRGB(26, 35, 53)
local THEME_ROW = Color3.fromRGB(31, 41, 62)
local THEME_TEXT = Color3.fromRGB(235, 240, 250)
local THEME_SUBTEXT = Color3.fromRGB(140, 150, 175)
local ESP_COLOR = Color3.fromRGB(255, 60, 60)
local FLY_SPEED = 60
local CLASS_SEARCH_TIMEOUT = 30
local ROOT_CATEGORIES_PER_PAGE = 4
local CATEGORY_ITEMS_PER_PAGE = 4
local LOADING_DURATION = 5
local LOADING_PHASES = {
	"Initializing Byte...",
	"Loading Modules...",
	"Bypassing Anti-Cheats...",
	"Finalizing...",
}

-- State.
ByteMenu.menuOpen = true
ByteMenu.menuToggleKey = Enum.KeyCode.RightShift
ByteMenu.espEnabled = false
ByteMenu.tracersEnabled = false
ByteMenu.espDistanceEnabled = false
ByteMenu.espHealthBarEnabled = false
ByteMenu.chamsEnabled = false
ByteMenu.fullbrightEnabled = false
ByteMenu.removeFogEnabled = false
ByteMenu.customFovEnabled = false
ByteMenu.customFovValue = 90
ByteMenu.teamColorEspEnabled = false
ByteMenu.boxStyleIndex = 1
ByteMenu.tracerOriginIndex = 1
ByteMenu.flyEnabled = false
ByteMenu.infiniteJumpEnabled = false
ByteMenu.speedBoostEnabled = false
ByteMenu.speedBoostMultiplier = 2
ByteMenu.objectNoclipEnabled = false
ByteMenu.superJumpEnabled = false
ByteMenu.superJumpHeight = 20
ByteMenu.lowGravityEnabled = false
ByteMenu.gravityScalePercent = 50
ByteMenu.freecamEnabled = false
ByteMenu.freecamPosition = nil
ByteMenu.antiAfkEnabled = false
ByteMenu.savedPosition = nil
ByteMenu.spawnPosition = nil
ByteMenu.lastSafePosition = nil
ByteMenu.antiVoidEnabled = false
ByteMenu.antiVoidHeight = -250
ByteMenu.fpsUnlockEnabled = false
ByteMenu.originalFpsCap = nil
ByteMenu.godModeEnabled = false
ByteMenu.regenHealthEnabled = false
ByteMenu.regenRate = 10
ByteMenu.themeIndex = 1
ByteMenu.fontIndex = 1
ByteMenu.controllerClass = nil
ByteMenu.capsuleMotorClass = nil
ByteMenu.controllerInstance = nil
ByteMenu.originalControllerStep = nil
ByteMenu.originalMotorStep = nil
ByteMenu.pendingSuperJumpBoost = false
ByteMenu.flyPosition = nil
ByteMenu.isFlyingNow = false
ByteMenu.connections = {}

local localPlayer = playersService.LocalPlayer
local currentCamera = workspace.CurrentCamera
local espBoxes = {}
local chamHighlights = {}
local viewMode = "root"
local rootPageIndex = 1
local activeCategoryIndex = nil
local categoryPageIndex = 1
local searchText = ""

---Identify the movement Controller class table by its method shape.
---@param candidate table
---@return boolean
local function isControllerClassShape(candidate)
	return rawget(candidate, "__index") == candidate
		and typeof(rawget(candidate, "step")) == "function"
		and typeof(rawget(candidate, "new")) == "function"
		and typeof(rawget(candidate, "look")) == "function"
		and typeof(rawget(candidate, "correct")) == "function"
		and typeof(rawget(candidate, "destroy")) == "function"
end

---Identify the CapsuleMotor class table by its method shape.
---@param candidate table
---@return boolean
local function isCapsuleMotorClassShape(candidate)
	return rawget(candidate, "__index") == candidate
		and typeof(rawget(candidate, "step")) == "function"
		and typeof(rawget(candidate, "correct")) == "function"
		and typeof(rawget(candidate, "destroy")) == "function"
		and typeof(rawget(candidate, "isClear")) == "function"
		and typeof(rawget(candidate, "floor")) == "function"
		and typeof(rawget(candidate, "placeFromEye")) == "function"
end

---Single GC pass that looks for both class tables at once.
---@return table?, table?
local function scanForClasses()
	local foundController, foundMotor
	for _, object in ipairs(getgc(true)) do
		if typeof(object) ~= "table" then continue end
		if not foundController then
			local success, matches = pcall(isControllerClassShape, object)
			if success and matches then foundController = object end
		end
		if not foundMotor then
			local success, matches = pcall(isCapsuleMotorClassShape, object)
			if success and matches then foundMotor = object end
		end
		if foundController and foundMotor then break end
	end
	return foundController, foundMotor
end

---Poll the GC until both classes exist.
---@return table?, table?
local function waitForClasses()
	local startClock = os.clock()
	while os.clock() - startClock < CLASS_SEARCH_TIMEOUT do
		local controller, motor = scanForClasses()
		if controller and motor then
			return controller, motor
		end
		task.wait(0.5)
	end
end

---Compute the free-fly delta based on camera direction and fly keys.
---@param deltaTime number
local function computeFlyDelta(deltaTime)
	local lookVector = currentCamera.CFrame.LookVector
	local rightVector = currentCamera.CFrame.RightVector
	local moveDirection = Vector3.zero

	if userInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += lookVector end
	if userInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= lookVector end
	if userInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= rightVector end
	if userInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += rightVector end
	if userInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection += Vector3.new(0, 1, 0) end
	if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection -= Vector3.new(0, 1, 0) end

	if moveDirection.Magnitude > 0 then
		moveDirection = moveDirection.Unit
	end

	return moveDirection * FLY_SPEED * deltaTime
end

---Drive fly by correcting the motor's authoritative position, still running
---the real step (for replication/attributes), then re-forcing our CFrame.
---@param controllerSelf table
---@param deltaTime number
local function updateManualFly(controllerSelf, deltaTime)
	if not ByteMenu.isFlyingNow then
		ByteMenu.flyPosition = controllerSelf.root.Position
		ByteMenu.isFlyingNow = true
	end

	ByteMenu.flyPosition = ByteMenu.flyPosition + computeFlyDelta(deltaTime)
	local yawCFrame = CFrame.Angles(0, controllerSelf.yaw, 0)

	pcall(function() controllerSelf:correct(CFrame.new(ByteMenu.flyPosition)) end)
	ByteMenu.originalControllerStep(controllerSelf, deltaTime, false, true)

	controllerSelf.root.AssemblyLinearVelocity = Vector3.zero
	controllerSelf.root.CFrame = CFrame.new(ByteMenu.flyPosition) * yawCFrame

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(ByteMenu.flyPosition + Vector3.new(0, 1, 0) * controllerSelf.eye) * yawCFrame * CFrame.Angles(controllerSelf.pitch, 0, 0)
	camera.Focus = camera.CFrame * CFrame.new(0, 0, -10)
end

---Stop manual fly and resync the motor so it doesn't rubber-band.
---@param controllerSelf table
local function stopManualFly(controllerSelf)
	if not ByteMenu.isFlyingNow then return end
	pcall(function() controllerSelf:correct(controllerSelf.root.CFrame) end)
	ByteMenu.flyPosition = nil
	ByteMenu.isFlyingNow = false
end

---Drive freecam: still runs the real step so character/replication stay
---alive, but overrides the camera with an independently translated view.
---@param controllerSelf table
---@param deltaTime number
---@param blocked boolean
---@param noInput boolean
local function updateFreecam(controllerSelf, deltaTime, blocked, noInput)
	ByteMenu.originalControllerStep(controllerSelf, deltaTime, blocked, noInput)

	if not ByteMenu.freecamPosition then
		ByteMenu.freecamPosition = workspace.CurrentCamera.CFrame.Position
	end

	local lookCFrame = CFrame.Angles(0, controllerSelf.yaw, 0) * CFrame.Angles(controllerSelf.pitch, 0, 0)
	local moveDirection = Vector3.zero
	if userInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += lookCFrame.LookVector end
	if userInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= lookCFrame.LookVector end
	if userInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= lookCFrame.RightVector end
	if userInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += lookCFrame.RightVector end
	if userInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection += Vector3.new(0, 1, 0) end
	if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection -= Vector3.new(0, 1, 0) end
	if moveDirection.Magnitude > 0 then
		moveDirection = moveDirection.Unit
	end

	ByteMenu.freecamPosition = ByteMenu.freecamPosition + moveDirection * FLY_SPEED * deltaTime

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(ByteMenu.freecamPosition) * lookCFrame
	camera.Focus = camera.CFrame * CFrame.new(0, 0, -10)

	return camera.CFrame
end

---Hook Controller.step: fly/freecam take over the camera, low gravity
---softens falls by comparing position before/after the real step, super
---jump consumes a pending boost flag set by the motor hook.
local function hookControllerStep()
	local controllerClass = ByteMenu.controllerClass
	if not controllerClass or isfunctionhooked(controllerClass.step) then
		return
	end

	ByteMenu.originalControllerStep = hookfunction(controllerClass.step, newcclosure(function(controllerSelf, deltaTime, blocked, noInput)
		ByteMenu.controllerInstance = controllerSelf

		if ByteMenu.flyEnabled then
			updateManualFly(controllerSelf, deltaTime)
			return workspace.CurrentCamera.CFrame
		end
		stopManualFly(controllerSelf)

		if ByteMenu.freecamEnabled then
			return updateFreecam(controllerSelf, deltaTime, blocked, noInput)
		elseif ByteMenu.freecamPosition then
			ByteMenu.freecamPosition = nil
		end

		local cameraCFrame

		if ByteMenu.lowGravityEnabled and controllerSelf.motor and not controllerSelf.motor.grounded then
			local beforeY = controllerSelf.root.Position.Y
			cameraCFrame = ByteMenu.originalControllerStep(controllerSelf, deltaTime, blocked, noInput)
			local afterY = controllerSelf.root.Position.Y
			local fallDistance = beforeY - afterY
			if fallDistance > 0 then
				local reducedFall = fallDistance * (ByteMenu.gravityScalePercent / 100)
				local correctedPosition = Vector3.new(controllerSelf.root.Position.X, beforeY - reducedFall, controllerSelf.root.Position.Z)
				pcall(function() controllerSelf:correct(CFrame.new(correctedPosition)) end)
			end
		else
			cameraCFrame = ByteMenu.originalControllerStep(controllerSelf, deltaTime, blocked, noInput)
		end

		if ByteMenu.pendingSuperJumpBoost then
			ByteMenu.pendingSuperJumpBoost = false
			local boostedPosition = controllerSelf.root.Position + Vector3.new(0, ByteMenu.superJumpHeight, 0)
			pcall(function() controllerSelf:correct(CFrame.new(boostedPosition)) end)
		end

		if ByteMenu.speedBoostEnabled then
			for _ = 1, ByteMenu.speedBoostMultiplier do
				cameraCFrame = ByteMenu.originalControllerStep(controllerSelf, deltaTime, blocked, noInput)
			end
		end

		return cameraCFrame
	end))
end

---Hook CapsuleMotor.step: force grounded on real jump requests (infinite
---jump/fly), and flag a pending boost for super jump handled in Controller.
local function hookCapsuleMotorStep()
	local capsuleMotorClass = ByteMenu.capsuleMotorClass
	if not capsuleMotorClass or isfunctionhooked(capsuleMotorClass.step) then
		return
	end

	ByteMenu.originalMotorStep = hookfunction(capsuleMotorClass.step, newcclosure(function(motorSelf, deltaTime, moveVector, jumpRequested, crouch)
		if ByteMenu.flyEnabled then
			motorSelf.grounded = true
		end
		if ByteMenu.infiniteJumpEnabled and jumpRequested then
			motorSelf.grounded = true
		end
		if ByteMenu.superJumpEnabled and jumpRequested and motorSelf.grounded then
			ByteMenu.pendingSuperJumpBoost = true
		end
		return ByteMenu.originalMotorStep(motorSelf, deltaTime, moveVector, jumpRequested, crouch)
	end))
end

---Teleport the local character to a target player, resyncing the motor.
---@param targetPlayer Instance
local function teleportToPlayer(targetPlayer)
	local localCharacter = localPlayer.Character
	local targetCharacter = targetPlayer.Character
	if not (localCharacter and targetCharacter) then return end

	local localHrp = localCharacter:FindFirstChild("HumanoidRootPart")
	local targetHrp = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not (localHrp and targetHrp) then return end

	local destination = targetHrp.Position + targetHrp.CFrame.LookVector * -3 + Vector3.new(0, 2, 0)

	if ByteMenu.controllerInstance then
		local success = pcall(function()
			ByteMenu.controllerInstance:correct(CFrame.new(destination))
		end)
		if success then return end
	end

	localHrp.CFrame = CFrame.new(destination)
end

---Toggle CanCollide on every BasePart of a character. The map floor/walls
---are enforced by the motor's own raycasts, not CanCollide.
---@param character Instance
local function applyObjectNoclip(character)
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = not ByteMenu.objectNoclipEnabled
		end
	end
end

---Keep newly added character parts in sync with noclip state.
---@param character Instance
local function watchCharacterForNoclip(character)
	applyObjectNoclip(character)
	table.insert(ByteMenu.connections, character.DescendantAdded:Connect(function(descendant)
		if ByteMenu.objectNoclipEnabled and descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end))
end

-- Saved lighting/fog state so toggles can be reverted cleanly.
local savedLightingState = nil
local savedFogState = nil

---Flip fullbright on/off, restoring the original Lighting values afterward.
local function applyFullbright()
	if ByteMenu.fullbrightEnabled then
		if not savedLightingState then
			savedLightingState = {
				Brightness = lightingService.Brightness,
				ClockTime = lightingService.ClockTime,
				GlobalShadows = lightingService.GlobalShadows,
				Ambient = lightingService.Ambient,
				OutdoorAmbient = lightingService.OutdoorAmbient,
			}
		end
		lightingService.Brightness = 2
		lightingService.ClockTime = 14
		lightingService.GlobalShadows = false
		lightingService.Ambient = Color3.new(1, 1, 1)
		lightingService.OutdoorAmbient = Color3.new(1, 1, 1)
	elseif savedLightingState then
		lightingService.Brightness = savedLightingState.Brightness
		lightingService.ClockTime = savedLightingState.ClockTime
		lightingService.GlobalShadows = savedLightingState.GlobalShadows
		lightingService.Ambient = savedLightingState.Ambient
		lightingService.OutdoorAmbient = savedLightingState.OutdoorAmbient
		savedLightingState = nil
	end
end

---Flip fog removal on/off, restoring the original fog distances afterward.
local function applyRemoveFog()
	if ByteMenu.removeFogEnabled then
		if not savedFogState then
			savedFogState = { FogStart = lightingService.FogStart, FogEnd = lightingService.FogEnd }
		end
		lightingService.FogStart = 0
		lightingService.FogEnd = 1000000
	elseif savedFogState then
		lightingService.FogStart = savedFogState.FogStart
		lightingService.FogEnd = savedFogState.FogEnd
		savedFogState = nil
	end
end

---Flip the FPS cap between unlocked and the original value.
local function applyFpsUnlock()
	if ByteMenu.fpsUnlockEnabled then
		local success, cap = pcall(getfpscap)
		if success then ByteMenu.originalFpsCap = cap end
		pcall(setfpscap, 2000)
	else
		pcall(setfpscap, ByteMenu.originalFpsCap or 60)
	end
end

---Apply a see-through Highlight to a player's character for chams.
---@param character Instance
---@param player Instance
local function applyChamsToCharacter(character, player)
	if chamHighlights[player] then return end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = ESP_COLOR
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	chamHighlights[player] = highlight
end

---Remove a player's chams highlight if present.
---@param player Instance
local function removeChamsFromPlayer(player)
	local highlight = chamHighlights[player]
	if highlight then
		highlight:Destroy()
		chamHighlights[player] = nil
	end
end

---Sync every player's chams highlight with the current toggle state.
local function refreshChams()
	for _, player in ipairs(playersService:GetPlayers()) do
		if player == localPlayer then continue end
		if ByteMenu.chamsEnabled and player.Character then
			applyChamsToCharacter(player.Character, player)
		else
			removeChamsFromPlayer(player)
		end
	end
end

---Destroy every drawing object used by ESP/tracers for every player.
local function clearEsp()
	for _, objects in pairs(espBoxes) do
		objects.box:Remove()
		for _, line in ipairs(objects.corners) do line:Remove() end
		objects.name:Remove()
		objects.distanceText:Remove()
		objects.tracer:Remove()
		objects.healthBack:Remove()
		objects.healthFill:Remove()
	end
	table.clear(espBoxes)
end

---Create (or fetch cached) drawing objects for a player.
---@param player Instance
local function getEspObjects(player)
	if espBoxes[player] then
		return espBoxes[player]
	end

	local box = Drawing.new("Square")
	box.Thickness = 1
	box.Color = ESP_COLOR
	box.Filled = false
	box.Visible = false

	local corners = {}
	for i = 1, 4 do
		local line = Drawing.new("Line")
		line.Thickness = 2
		line.Color = ESP_COLOR
		line.Visible = false
		corners[i] = line
	end

	local name = Drawing.new("Text")
	name.Size = 16
	name.Center = true
	name.Color = ESP_COLOR
	name.Outline = true
	name.Visible = false

	local distanceText = Drawing.new("Text")
	distanceText.Size = 13
	distanceText.Center = true
	distanceText.Color = THEME_TEXT
	distanceText.Outline = true
	distanceText.Visible = false

	local tracer = Drawing.new("Line")
	tracer.Thickness = 1
	tracer.Color = ESP_COLOR
	tracer.Visible = false

	local healthBack = Drawing.new("Square")
	healthBack.Filled = true
	healthBack.Color = Color3.fromRGB(20, 20, 20)
	healthBack.Visible = false

	local healthFill = Drawing.new("Square")
	healthFill.Filled = true
	healthFill.Color = Color3.fromRGB(80, 220, 100)
	healthFill.Visible = false

	espBoxes[player] = {
		box = box,
		corners = corners,
		name = name,
		distanceText = distanceText,
		tracer = tracer,
		healthBack = healthBack,
		healthFill = healthFill,
	}
	return espBoxes[player]
end

---Hide every drawing object for a cached player entry.
---@param objects table
local function hideEspObjects(objects)
	objects.box.Visible = false
	for _, line in ipairs(objects.corners) do line.Visible = false end
	objects.name.Visible = false
	objects.distanceText.Visible = false
	objects.tracer.Visible = false
	objects.healthBack.Visible = false
	objects.healthFill.Visible = false
end

---Update every ESP box, corner set, distance text, health bar, and tracer.
local function updateEsp()
	local viewportSize = currentCamera.ViewportSize
	local mousePosition = userInputService:GetMouseLocation()

	for _, player in ipairs(playersService:GetPlayers()) do
		if player == localPlayer then continue end

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local shouldShow = (ByteMenu.espEnabled or ByteMenu.tracersEnabled) and hrp and humanoid and humanoid.Health > 0

		if not shouldShow then
			local cached = espBoxes[player]
			if cached then hideEspObjects(cached) end
			continue
		end

		local objects = getEspObjects(player)
		local screenPos, onScreen = currentCamera:WorldToViewportPoint(hrp.Position)

		if not onScreen then
			hideEspObjects(objects)
			continue
		end

		local distance = (currentCamera.CFrame.Position - hrp.Position).Magnitude
		local height = math.clamp(4000 / distance, 10, 200)
		local width = height * 0.6
		local screenPoint = Vector2.new(screenPos.X, screenPos.Y)
		local topLeft = Vector2.new(screenPoint.X - width / 2, screenPoint.Y - height / 2)

		local espColor = ESP_COLOR
		if ByteMenu.teamColorEspEnabled and player.Team then
			espColor = player.Team.TeamColor.Color
		end

		if ByteMenu.espEnabled and ByteMenu.boxStyleIndex == 1 then
			objects.box.Size = Vector2.new(width, height)
			objects.box.Position = topLeft
			objects.box.Color = espColor
			objects.box.Visible = true
			for _, line in ipairs(objects.corners) do line.Visible = false end
		elseif ByteMenu.espEnabled then
			objects.box.Visible = false
			local cornerLength = math.min(width, height) * 0.25
			local corners = objects.corners
			corners[1].From = topLeft
			corners[1].To = topLeft + Vector2.new(cornerLength, 0)
			corners[2].From = topLeft
			corners[2].To = topLeft + Vector2.new(0, cornerLength)
			corners[3].From = topLeft + Vector2.new(width, height)
			corners[3].To = topLeft + Vector2.new(width - cornerLength, height)
			corners[4].From = topLeft + Vector2.new(width, height)
			corners[4].To = topLeft + Vector2.new(width, height - cornerLength)
			for _, line in ipairs(corners) do
				line.Color = espColor
				line.Visible = true
			end
		else
			objects.box.Visible = false
			for _, line in ipairs(objects.corners) do line.Visible = false end
		end

		objects.name.Position = Vector2.new(screenPoint.X, topLeft.Y - 16)
		objects.name.Text = player.Name
		objects.name.Color = espColor
		objects.name.Visible = ByteMenu.espEnabled

		objects.distanceText.Position = Vector2.new(screenPoint.X, topLeft.Y + height + 4)
		objects.distanceText.Text = string.format("%d studs", distance)
		objects.distanceText.Visible = ByteMenu.espEnabled and ByteMenu.espDistanceEnabled

		if ByteMenu.espEnabled and ByteMenu.espHealthBarEnabled then
			local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			objects.healthBack.Size = Vector2.new(4, height)
			objects.healthBack.Position = Vector2.new(topLeft.X - 8, topLeft.Y)
			objects.healthBack.Visible = true

			objects.healthFill.Size = Vector2.new(4, height * healthPercent)
			objects.healthFill.Position = Vector2.new(topLeft.X - 8, topLeft.Y + height * (1 - healthPercent))
			objects.healthFill.Color = Color3.fromRGB(255 * (1 - healthPercent), 220 * healthPercent, 60)
			objects.healthFill.Visible = true
		else
			objects.healthBack.Visible = false
			objects.healthFill.Visible = false
		end

		local tracerOrigin
		if ByteMenu.tracerOriginIndex == 1 then
			tracerOrigin = Vector2.new(viewportSize.X / 2, viewportSize.Y)
		elseif ByteMenu.tracerOriginIndex == 2 then
			tracerOrigin = Vector2.new(viewportSize.X / 2, 0)
		else
			tracerOrigin = Vector2.new(mousePosition.X, mousePosition.Y)
		end
		objects.tracer.From = tracerOrigin
		objects.tracer.To = screenPoint
		objects.tracer.Color = espColor
		objects.tracer.Visible = ByteMenu.tracersEnabled
	end
end

---Find and teleport into a random available public server.
local function performServerHop()
	local success, errorMessage = pcall(function()
		local response = request({
			Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
			Method = "GET",
		})
		assert(response.Success, "request failed")
		local data = httpService:JSONDecode(response.Body)
		local candidates = {}
		for _, server in ipairs(data.data) do
			if server.id ~= game.JobId and server.playing < server.maxPlayers then
				table.insert(candidates, server.id)
			end
		end
		assert(#candidates > 0, "no available servers")
		local targetServerId = candidates[math.random(1, #candidates)]
		teleportService:TeleportToPlaceInstance(game.PlaceId, targetServerId, localPlayer)
	end)
	if not success then
		warn("Byte: server hop failed - " .. tostring(errorMessage))
	end
end

-- Dispatch table for simple one-shot action rows.
local actionHandlers = {}

actionHandlers.savePosition = function()
	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		ByteMenu.savedPosition = hrp.Position
	end
end

actionHandlers.loadPosition = function()
	if not ByteMenu.savedPosition then return end
	if ByteMenu.controllerInstance then
		pcall(function() ByteMenu.controllerInstance:correct(CFrame.new(ByteMenu.savedPosition)) end)
	else
		local character = localPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.CFrame = CFrame.new(ByteMenu.savedPosition) end
	end
end

actionHandlers.teleportToSpawn = function()
	if not ByteMenu.spawnPosition then return end
	if ByteMenu.controllerInstance then
		pcall(function() ByteMenu.controllerInstance:correct(CFrame.new(ByteMenu.spawnPosition)) end)
	else
		local character = localPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.CFrame = CFrame.new(ByteMenu.spawnPosition) end
	end
end

actionHandlers.rejoin = function()
	pcall(function() teleportService:Teleport(game.PlaceId, localPlayer) end)
end

actionHandlers.serverHop = performServerHop

actionHandlers.copyPlaceId = function()
	pcall(function() setclipboard(tostring(game.PlaceId)) end)
end

actionHandlers.fullHeal = function()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Health = humanoid.MaxHealth end
end

---Listen for the next key press and use it as the new menu toggle keybind.
---@param nameLabel Instance
---@param baseLabel string
local function beginRebindMenuKey(nameLabel, baseLabel)
	nameLabel.Text = "Press any key..."
	local rebindConnection
	rebindConnection = userInputService.InputBegan:Connect(function(input)
		if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
			ByteMenu.menuToggleKey = input.KeyCode
			nameLabel.Text = baseLabel .. " (" .. input.KeyCode.Name .. ")"
			rebindConnection:Disconnect()
		end
	end)
	table.insert(ByteMenu.connections, rebindConnection)
end

-- Category data drives the paged menu layout.
local categories = {
	{
		name = "Utilities",
		items = {
			{ type = "action", label = "Rejoin Server", action = "rejoin" },
			{ type = "action", label = "Server Hop", action = "serverHop" },
			{ type = "action", label = "Copy Place Id", action = "copyPlaceId" },
			{ type = "toggle", label = "FPS Unlock", key = "fpsUnlockEnabled" },
			{ type = "rebind", label = "Menu Keybind" },
		},
	},
	{ name = "VRRig", items = {} },
	{
		name = "Movement",
		items = {
			{ type = "toggle", label = "Infinite Jump", key = "infiniteJumpEnabled" },
			{ type = "toggle", label = "Fly", key = "flyEnabled" },
			{ type = "toggle", label = "Speed Boost", key = "speedBoostEnabled" },
			{ type = "stepper", label = "Speed Multiplier", key = "speedBoostMultiplier", min = 1, max = 6, step = 1 },
			{ type = "toggle", label = "Object Noclip", key = "objectNoclipEnabled" },
			{ type = "toggle", label = "Super Jump", key = "superJumpEnabled" },
			{ type = "stepper", label = "Super Jump Height", key = "superJumpHeight", min = 10, max = 60, step = 5 },
			{ type = "toggle", label = "Low Gravity", key = "lowGravityEnabled" },
			{ type = "stepper", label = "Gravity Scale %", key = "gravityScalePercent", min = 10, max = 100, step = 10 },
			{ type = "toggle", label = "Freecam", key = "freecamEnabled" },
			{ type = "toggle", label = "Anti-AFK", key = "antiAfkEnabled" },
		},
	},
	{
		name = "Visuals",
		items = {
			{ type = "toggle", label = "Player ESP", key = "espEnabled" },
			{ type = "toggle", label = "ESP Tracers", key = "tracersEnabled" },
			{ type = "toggle", label = "ESP Distance", key = "espDistanceEnabled" },
			{ type = "toggle", label = "ESP Health Bar", key = "espHealthBarEnabled" },
			{ type = "toggle", label = "Chams", key = "chamsEnabled" },
			{ type = "toggle", label = "Fullbright", key = "fullbrightEnabled" },
			{ type = "toggle", label = "Remove Fog", key = "removeFogEnabled" },
			{ type = "toggle", label = "Custom FOV", key = "customFovEnabled" },
			{ type = "stepper", label = "FOV Value", key = "customFovValue", min = 60, max = 120, step = 5 },
			{ type = "toggle", label = "Team Color ESP", key = "teamColorEspEnabled" },
			{ type = "stepper", label = "Box Style", key = "boxStyleIndex", min = 1, max = 2, step = 1 },
			{ type = "stepper", label = "Tracer Origin", key = "tracerOriginIndex", min = 1, max = 3, step = 1 },
		},
	},
	{ name = "Players", dynamic = true },
	{
		name = "Teleports",
		items = {
			{ type = "action", label = "Save Position", action = "savePosition" },
			{ type = "action", label = "Load Position", action = "loadPosition" },
			{ type = "action", label = "Teleport To Spawn", action = "teleportToSpawn" },
			{ type = "toggle", label = "Anti Void", key = "antiVoidEnabled" },
			{ type = "stepper", label = "Void Height", key = "antiVoidHeight", min = -1000, max = -100, step = 50 },
		},
	},
	{
		name = "Settings",
		items = {
			{ type = "theme", label = "Theme" },
			{ type = "fontpick", label = "Font" },
		},
	},
	{
		name = "Overpowered",
		items = {
			{ type = "toggle", label = "God Mode", key = "godModeEnabled" },
			{ type = "toggle", label = "Health Regen", key = "regenHealthEnabled" },
			{ type = "stepper", label = "Regen Rate", key = "regenRate", min = 5, max = 50, step = 5 },
			{ type = "action", label = "Full Heal", action = "fullHeal" },
		},
	},
}

---Return the currently selected theme/font tables.
local function currentTheme()
	return THEMES[ByteMenu.themeIndex]
end
local function currentFontEntry()
	return FONTS[ByteMenu.fontIndex]
end

-- Build the loading screen first; the main menu is built hidden beneath it.
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "ByteLoading"
loadingGui.ResetOnSpawn = false
loadingGui.Parent = gethui()

local loadingBackground = Instance.new("Frame")
loadingBackground.Size = UDim2.new(1, 0, 1, 0)
loadingBackground.BackgroundColor3 = Color3.fromRGB(6, 4, 10)
loadingBackground.Parent = loadingGui

local loadingGradient = Instance.new("UIGradient")
loadingGradient.Color = ColorSequence.new(currentTheme().gradientA, currentTheme().gradientB)
loadingGradient.Rotation = 0
loadingGradient.Parent = loadingBackground

-- Centered shield glow image behind all loading screen text.
local loadingShieldImage = Instance.new("ImageLabel")
loadingShieldImage.Size = UDim2.new(0, 420, 0, 420)
loadingShieldImage.AnchorPoint = Vector2.new(0.5, 0.5)
loadingShieldImage.Position = UDim2.new(0.5, 0, 0.5, -20)
loadingShieldImage.BackgroundTransparency = 1
loadingShieldImage.Image = BACKGROUND_IMAGE_ASSET
loadingShieldImage.ImageTransparency = 0.1
loadingShieldImage.ScaleType = Enum.ScaleType.Fit
loadingShieldImage.ZIndex = 0
loadingShieldImage.Parent = loadingBackground

local loadingTitle = Instance.new("TextLabel")
loadingTitle.Size = UDim2.new(1, 0, 0, 60)
loadingTitle.Position = UDim2.new(0, 0, 0.35, 0)
loadingTitle.BackgroundTransparency = 1
loadingTitle.Text = "BYTE"
loadingTitle.Font = Enum.Font.GothamBold
loadingTitle.TextSize = 54
loadingTitle.TextColor3 = THEME_TEXT
loadingTitle.ZIndex = 2
loadingTitle.Parent = loadingBackground

local loadingStatus = Instance.new("TextLabel")
loadingStatus.Size = UDim2.new(1, 0, 0, 24)
loadingStatus.Position = UDim2.new(0, 0, 0.35, 70)
loadingStatus.BackgroundTransparency = 1
loadingStatus.Text = LOADING_PHASES[1]
loadingStatus.Font = Enum.Font.Gotham
loadingStatus.TextSize = 16
loadingStatus.TextColor3 = THEME_SUBTEXT
loadingStatus.ZIndex = 2
loadingStatus.Parent = loadingBackground

local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.new(0, 320, 0, 10)
progressTrack.Position = UDim2.new(0.5, -160, 0.35, 110)
progressTrack.BackgroundColor3 = THEME_PANEL
progressTrack.ZIndex = 2
progressTrack.Parent = loadingBackground
local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(1, 0)
progressCorner.Parent = progressTrack

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = currentTheme().accent
progressFill.ZIndex = 2
progressFill.Parent = progressTrack
local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local bypassedBanner = Instance.new("TextLabel")
bypassedBanner.Size = UDim2.new(1, 0, 0, 40)
bypassedBanner.Position = UDim2.new(0, 0, 0.35, 140)
bypassedBanner.BackgroundTransparency = 1
bypassedBanner.Text = "✓ ANTIS BYPASSED"
bypassedBanner.Font = Enum.Font.GothamBold
bypassedBanner.TextSize = 28
bypassedBanner.TextColor3 = Color3.fromRGB(90, 220, 110)
bypassedBanner.TextTransparency = 1
bypassedBanner.ZIndex = 2
bypassedBanner.Parent = loadingBackground

local creditsLabel = Instance.new("TextLabel")
creditsLabel.Size = UDim2.new(1, 0, 0, 20)
creditsLabel.Position = UDim2.new(0, 0, 1, -40)
creditsLabel.BackgroundTransparency = 1
creditsLabel.Text = "Credits to @bludmonkeyvr"
creditsLabel.Font = Enum.Font.Gotham
creditsLabel.TextSize = 14
creditsLabel.TextColor3 = THEME_SUBTEXT
creditsLabel.ZIndex = 2
creditsLabel.Parent = loadingBackground

-- Build the mod menu UI (kept hidden until loading finishes).
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ByteModMenu"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = gethui()

local disconnectButton = Instance.new("TextButton")
disconnectButton.Size = UDim2.new(0, 150, 0, 34)
disconnectButton.Position = UDim2.new(0.5, -75, 0, 10)
disconnectButton.BackgroundColor3 = currentTheme().accent
disconnectButton.Text = "DISCONNECT"
disconnectButton.Font = currentFontEntry().font
disconnectButton.TextSize = 14
disconnectButton.TextColor3 = THEME_TEXT
disconnectButton.Parent = screenGui
local disconnectCorner = Instance.new("UICorner")
disconnectCorner.CornerRadius = UDim.new(1, 0)
disconnectCorner.Parent = disconnectButton

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 360, 0, 520)
mainFrame.Position = UDim2.new(0.5, -180, 0, 50)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 6, 14)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new(currentTheme().gradientA, currentTheme().gradientB)
mainGradient.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = currentTheme().accent
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.4
mainStroke.Parent = mainFrame

-- Faint, oversized shield watermark behind the menu content.
local menuShieldImage = Instance.new("ImageLabel")
menuShieldImage.Size = UDim2.new(0, 500, 0, 500)
menuShieldImage.AnchorPoint = Vector2.new(0.5, 0.5)
menuShieldImage.Position = UDim2.new(0.5, 0, 0.5, 0)
menuShieldImage.BackgroundTransparency = 1
menuShieldImage.Image = BACKGROUND_IMAGE_ASSET
menuShieldImage.ImageTransparency = 0.88
menuShieldImage.ScaleType = Enum.ScaleType.Fit
menuShieldImage.ZIndex = 0
menuShieldImage.Parent = mainFrame

-- Floating pill that always stays visible to toggle the menu open/closed.
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 46, 0, 46)
toggleButton.Position = UDim2.new(0, 20, 0, 20)
toggleButton.BackgroundColor3 = currentTheme().accent
toggleButton.Text = "B"
toggleButton.Font = currentFontEntry().font
toggleButton.TextSize = 20
toggleButton.TextColor3 = THEME_TEXT
toggleButton.Active = true
toggleButton.Draggable = true
toggleButton.Visible = false
toggleButton.Parent = screenGui
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = toggleButton

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 44)
titleLabel.Position = UDim2.new(0, 0, 0, 12)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Byte MENU"
titleLabel.Font = currentFontEntry().font
titleLabel.TextSize = 26
titleLabel.TextColor3 = THEME_TEXT
titleLabel.ZIndex = 2
titleLabel.Parent = mainFrame

local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, -40, 0, 20)
statsRow.Position = UDim2.new(0, 20, 0, 58)
statsRow.BackgroundTransparency = 1
statsRow.ZIndex = 2
statsRow.Parent = mainFrame

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0.5, 0, 1, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Text = "FPS : 0"
fpsLabel.Font = Enum.Font.Gotham
fpsLabel.TextSize = 13
fpsLabel.TextColor3 = THEME_SUBTEXT
fpsLabel.ZIndex = 2
fpsLabel.Parent = statsRow

local pageLabel = Instance.new("TextLabel")
pageLabel.Size = UDim2.new(0.5, 0, 1, 0)
pageLabel.Position = UDim2.new(0.5, 0, 0, 0)
pageLabel.BackgroundTransparency = 1
pageLabel.TextXAlignment = Enum.TextXAlignment.Right
pageLabel.Text = "page 1/1"
pageLabel.Font = Enum.Font.Gotham
pageLabel.TextSize = 13
pageLabel.TextColor3 = THEME_SUBTEXT
pageLabel.ZIndex = 2
pageLabel.Parent = statsRow

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -40, 0, 34)
searchBox.Position = UDim2.new(0, 20, 0, 86)
searchBox.BackgroundColor3 = THEME_PANEL
searchBox.PlaceholderText = "search..."
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.TextColor3 = THEME_TEXT
searchBox.PlaceholderColor3 = THEME_SUBTEXT
searchBox.ClearTextOnFocus = false
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ZIndex = 2
searchBox.Parent = mainFrame
local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 8)
searchCorner.Parent = searchBox
local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 10)
searchPadding.Parent = searchBox

local rowsContainer = Instance.new("Frame")
rowsContainer.Size = UDim2.new(1, -40, 1, -180)
rowsContainer.Position = UDim2.new(0, 20, 0, 130)
rowsContainer.BackgroundTransparency = 1
rowsContainer.ZIndex = 2
rowsContainer.Parent = mainFrame
local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding = UDim.new(0, 10)
rowsLayout.Parent = rowsContainer

local leftArrowButton = Instance.new("TextButton")
leftArrowButton.Size = UDim2.new(0, 36, 0, 60)
leftArrowButton.Position = UDim2.new(0, -46, 0.5, -30)
leftArrowButton.BackgroundColor3 = THEME_PANEL
leftArrowButton.Text = "<"
leftArrowButton.Font = Enum.Font.GothamBold
leftArrowButton.TextSize = 20
leftArrowButton.TextColor3 = THEME_TEXT
leftArrowButton.Parent = mainFrame
local leftArrowCorner = Instance.new("UICorner")
leftArrowCorner.CornerRadius = UDim.new(0, 10)
leftArrowCorner.Parent = leftArrowButton

local rightArrowButton = Instance.new("TextButton")
rightArrowButton.Size = UDim2.new(0, 36, 0, 60)
rightArrowButton.Position = UDim2.new(1, 10, 0.5, -30)
rightArrowButton.BackgroundColor3 = THEME_PANEL
rightArrowButton.Text = ">"
rightArrowButton.Font = Enum.Font.GothamBold
rightArrowButton.TextSize = 20
rightArrowButton.TextColor3 = THEME_TEXT
rightArrowButton.Parent = mainFrame
local rightArrowCorner = Instance.new("UICorner")
rightArrowCorner.CornerRadius = UDim.new(0, 10)
rightArrowCorner.Parent = rightArrowButton

local nextPageButton = Instance.new("TextButton")
nextPageButton.Size = UDim2.new(1, -40, 0, 36)
nextPageButton.Position = UDim2.new(0, 20, 1, -46)
nextPageButton.BackgroundColor3 = THEME_PANEL
nextPageButton.Text = "NEXT PAGE >"
nextPageButton.Font = Enum.Font.GothamBold
nextPageButton.TextSize = 14
nextPageButton.TextColor3 = THEME_TEXT
nextPageButton.ZIndex = 2
nextPageButton.Parent = mainFrame
local nextPageCorner = Instance.new("UICorner")
nextPageCorner.CornerRadius = UDim.new(0, 8)
nextPageCorner.Parent = nextPageButton

---Apply the current theme/font to every persistent (non-row) UI element.
local function applyThemeGlobal()
	local theme = currentTheme()
	local fontEntry = currentFontEntry()

	disconnectButton.BackgroundColor3 = theme.accent
	toggleButton.BackgroundColor3 = theme.accent
	mainGradient.Color = ColorSequence.new(theme.gradientA, theme.gradientB)
	loadingGradient.Color = ColorSequence.new(theme.gradientA, theme.gradientB)
	mainStroke.Color = theme.accent
	progressFill.BackgroundColor3 = theme.accent

	titleLabel.Font = fontEntry.font
	disconnectButton.Font = fontEntry.font
	toggleButton.Font = fontEntry.font
end

-- Continuously rotate the background gradient for an animated look.
table.insert(ByteMenu.connections, runService.RenderStepped:Connect(function()
	local rotation = (tick() * 20) % 360
	mainGradient.Rotation = rotation
	loadingGradient.Rotation = rotation
end))

---Clear every row inside the rows container (keeps the layout object).
local function clearRows()
	for _, child in ipairs(rowsContainer:GetChildren()) do
		if child:IsA("UIListLayout") then continue end
		child:Destroy()
	end
end

---Create a clickable category row with a chevron.
---@param categoryName string
---@param order number
---@param onClick function
local function createCategoryRow(categoryName, order, onClick)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.LayoutOrder = order
	row.BackgroundColor3 = THEME_ROW
	row.Text = ""
	row.AutoButtonColor = false
	row.Parent = rowsContainer
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -40, 1, 0)
	nameLabel.Position = UDim2.new(0, 16, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = categoryName
	nameLabel.Font = currentFontEntry().font
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = THEME_TEXT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local chevronLabel = Instance.new("TextLabel")
	chevronLabel.Size = UDim2.new(0, 24, 1, 0)
	chevronLabel.Position = UDim2.new(1, -34, 0, 0)
	chevronLabel.BackgroundTransparency = 1
	chevronLabel.Text = ">"
	chevronLabel.Font = Enum.Font.GothamBold
	chevronLabel.TextSize = 16
	chevronLabel.TextColor3 = THEME_SUBTEXT
	chevronLabel.Parent = row

	row.MouseButton1Click:Connect(onClick)
	return row
end

-- Keys that require the movement classes to be hooked before they can work.
local MOVEMENT_REQUIRES_CONTROLLER = {
	flyEnabled = true,
	infiniteJumpEnabled = true,
	speedBoostEnabled = true,
	superJumpEnabled = true,
	lowGravityEnabled = true,
	freecamEnabled = true,
}

-- Extra work to run immediately after a given toggle flips.
local toggleSideEffects = {
	espEnabled = function() if not ByteMenu.espEnabled and not ByteMenu.tracersEnabled then clearEsp() end end,
	tracersEnabled = function() if not ByteMenu.tracersEnabled and not ByteMenu.espEnabled then clearEsp() end end,
	objectNoclipEnabled = function() applyObjectNoclip(localPlayer.Character) end,
	fullbrightEnabled = applyFullbright,
	removeFogEnabled = applyRemoveFog,
	fpsUnlockEnabled = applyFpsUnlock,
}

---Create a toggle row for a feature inside a category page.
---@param itemLabel string
---@param order number
---@param stateKey string
local function createToggleRow(itemLabel, order, stateKey)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.LayoutOrder = order
	row.BackgroundColor3 = THEME_ROW
	row.Text = ""
	row.AutoButtonColor = false
	row.Parent = rowsContainer
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -70, 1, 0)
	nameLabel.Position = UDim2.new(0, 16, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemLabel
	nameLabel.Font = currentFontEntry().font
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = THEME_TEXT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local stateLabel = Instance.new("TextLabel")
	stateLabel.Size = UDim2.new(0, 50, 1, 0)
	stateLabel.Position = UDim2.new(1, -62, 0, 0)
	stateLabel.BackgroundTransparency = 1
	stateLabel.Font = Enum.Font.GothamBold
	stateLabel.TextSize = 13
	stateLabel.Parent = row

	local function refreshVisual()
		local isOn = ByteMenu[stateKey]
		stateLabel.Text = isOn and "ON" or "OFF"
		stateLabel.TextColor3 = isOn and Color3.fromRGB(90, 220, 110) or THEME_SUBTEXT
	end
	refreshVisual()

	row.MouseButton1Click:Connect(function()
		if MOVEMENT_REQUIRES_CONTROLLER[stateKey] and not (ByteMenu.controllerClass and ByteMenu.capsuleMotorClass) then
			warn("Byte: movement classes not found yet, try again once spawned.")
			return
		end

		ByteMenu[stateKey] = not ByteMenu[stateKey]
		local sideEffect = toggleSideEffects[stateKey]
		if sideEffect then sideEffect() end
		refreshVisual()
	end)

	return row
end

-- Forward declared so steppers/pickers can trigger a re-render after a change.
local renderCurrentPage

---Create a generic -/+ stepper row used for numeric settings.
---@param itemLabel string
---@param order number
---@param getText function
---@param onDecrease function
---@param onIncrease function
local function createStepperRowGeneric(itemLabel, order, getText, onDecrease, onIncrease)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.LayoutOrder = order
	row.BackgroundColor3 = THEME_ROW
	row.Parent = rowsContainer
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -140, 1, 0)
	nameLabel.Position = UDim2.new(0, 16, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemLabel
	nameLabel.Font = currentFontEntry().font
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = THEME_TEXT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local decreaseButton = Instance.new("TextButton")
	decreaseButton.Size = UDim2.new(0, 30, 0, 30)
	decreaseButton.Position = UDim2.new(1, -118, 0.5, -15)
	decreaseButton.BackgroundColor3 = THEME_PANEL
	decreaseButton.Text = "-"
	decreaseButton.Font = Enum.Font.GothamBold
	decreaseButton.TextSize = 18
	decreaseButton.TextColor3 = THEME_TEXT
	decreaseButton.Parent = row
	local decreaseCorner = Instance.new("UICorner")
	decreaseCorner.CornerRadius = UDim.new(0, 8)
	decreaseCorner.Parent = decreaseButton

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0, 70, 1, 0)
	valueLabel.Position = UDim2.new(1, -82, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = THEME_TEXT
	valueLabel.Text = getText()
	valueLabel.Parent = row

	local increaseButton = Instance.new("TextButton")
	increaseButton.Size = UDim2.new(0, 30, 0, 30)
	increaseButton.Position = UDim2.new(1, -36, 0.5, -15)
	increaseButton.BackgroundColor3 = THEME_PANEL
	increaseButton.Text = "+"
	increaseButton.Font = Enum.Font.GothamBold
	increaseButton.TextSize = 18
	increaseButton.TextColor3 = THEME_TEXT
	increaseButton.Parent = row
	local increaseCorner = Instance.new("UICorner")
	increaseCorner.CornerRadius = UDim.new(0, 8)
	increaseCorner.Parent = increaseButton

	decreaseButton.MouseButton1Click:Connect(function()
		onDecrease()
		valueLabel.Text = getText()
	end)
	increaseButton.MouseButton1Click:Connect(function()
		onIncrease()
		valueLabel.Text = getText()
	end)

	return row
end

---Create a numeric stepper row bound to a ByteMenu state key.
---@param itemLabel string
---@param order number
local function createStepperRow(itemLabel, order, stateKey, minValue, maxValue, step)
	createStepperRowGeneric(itemLabel, order, function()
		return tostring(ByteMenu[stateKey])
	end, function()
		ByteMenu[stateKey] = math.clamp(ByteMenu[stateKey] - step, minValue, maxValue)
	end, function()
		ByteMenu[stateKey] = math.clamp(ByteMenu[stateKey] + step, minValue, maxValue)
	end)
end

---Create the Theme picker row; applies instantly and re-renders the page.
---@param order number
local function createThemePickerRow(order)
	createStepperRowGeneric("Theme", order, function()
		return currentTheme().name
	end, function()
		ByteMenu.themeIndex = ((ByteMenu.themeIndex - 2) % #THEMES) + 1
		applyThemeGlobal()
		renderCurrentPage()
	end, function()
		ByteMenu.themeIndex = (ByteMenu.themeIndex % #THEMES) + 1
		applyThemeGlobal()
		renderCurrentPage()
	end)
end

---Create the Font picker row; applies instantly and re-renders the page.
---@param order number
local function createFontPickerRow(order)
	createStepperRowGeneric("Font", order, function()
		return currentFontEntry().name
	end, function()
		ByteMenu.fontIndex = ((ByteMenu.fontIndex - 2) % #FONTS) + 1
		applyThemeGlobal()
		renderCurrentPage()
	end, function()
		ByteMenu.fontIndex = (ByteMenu.fontIndex % #FONTS) + 1
		applyThemeGlobal()
		renderCurrentPage()
	end)
end

---Create a generic one-shot action row (Rejoin, Save Position, etc).
---@param itemLabel string
---@param order number
---@param onClick function
local function createActionRow(itemLabel, order, onClick)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.LayoutOrder = order
	row.BackgroundColor3 = THEME_ROW
	row.Text = ""
	row.AutoButtonColor = false
	row.Parent = rowsContainer
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -70, 1, 0)
	nameLabel.Position = UDim2.new(0, 16, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemLabel
	nameLabel.Font = currentFontEntry().font
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = THEME_TEXT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Size = UDim2.new(0, 50, 1, 0)
	actionLabel.Position = UDim2.new(1, -62, 0, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = "GO"
	actionLabel.Font = Enum.Font.GothamBold
	actionLabel.TextSize = 13
	actionLabel.TextColor3 = currentTheme().accent
	actionLabel.Parent = row

	row.MouseButton1Click:Connect(function()
		onClick(nameLabel)
	end)

	return row
end

---Create a row that teleports to the given player when clicked.
---@param targetPlayer Instance
---@param order number
local function createPlayerTeleportRow(targetPlayer, order)
	createActionRow(targetPlayer.Name, order, function()
		teleportToPlayer(targetPlayer)
	end)
end

---Create a static placeholder row for empty categories.
---@param order number
local function createPlaceholderRow(order)
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.LayoutOrder = order
	row.BackgroundColor3 = THEME_ROW
	row.Text = "Coming soon"
	row.Font = Enum.Font.Gotham
	row.TextSize = 14
	row.TextColor3 = THEME_SUBTEXT
	row.Parent = rowsContainer
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row
	return row
end

---Slice a list into the given 1-based page using a fixed page size.
---@param list table
---@param pageIndex number
---@param pageSize number
local function paginate(list, pageIndex, pageSize)
	local result = {}
	local startIndex = (pageIndex - 1) * pageSize + 1
	for i = startIndex, math.min(startIndex + pageSize - 1, #list) do
		table.insert(result, list[i])
	end
	return result
end

---Render whichever page is currently active (root category list or an
---opened category's items). Arrows/Next Page only ever affect this view.
renderCurrentPage = function()
	clearRows()

	if viewMode == "root" then
		local filtered = {}
		for index, category in ipairs(categories) do
			if searchText == "" or string.find(string.lower(category.name), string.lower(searchText), 1, true) then
				table.insert(filtered, { index = index, category = category })
			end
		end

		local totalPages = math.max(1, math.ceil(#filtered / ROOT_CATEGORIES_PER_PAGE))
		rootPageIndex = math.clamp(rootPageIndex, 1, totalPages)
		pageLabel.Text = "page " .. rootPageIndex .. "/" .. totalPages

		local pageEntries = paginate(filtered, rootPageIndex, ROOT_CATEGORIES_PER_PAGE)
		for order, entry in ipairs(pageEntries) do
			createCategoryRow(entry.category.name, order, function()
				viewMode = "category"
				activeCategoryIndex = entry.index
				categoryPageIndex = 1
				renderCurrentPage()
			end)
		end
		return
	end

	local category = categories[activeCategoryIndex]
	createCategoryRow("< Back", 0, function()
		viewMode = "root"
		renderCurrentPage()
	end)

	if category.dynamic then
		local targets = {}
		for _, targetPlayer in ipairs(playersService:GetPlayers()) do
			if targetPlayer ~= localPlayer then
				table.insert(targets, targetPlayer)
			end
		end

		local totalPages = math.max(1, math.ceil(#targets / CATEGORY_ITEMS_PER_PAGE))
		categoryPageIndex = math.clamp(categoryPageIndex, 1, totalPages)
		pageLabel.Text = "page " .. categoryPageIndex .. "/" .. totalPages

		local pageEntries = paginate(targets, categoryPageIndex, CATEGORY_ITEMS_PER_PAGE)
		if #pageEntries == 0 then
			createPlaceholderRow(1)
		else
			for order, targetPlayer in ipairs(pageEntries) do
				createPlayerTeleportRow(targetPlayer, order)
			end
		end
		return
	end

	local items = category.items
	local totalPages = math.max(1, math.ceil(#items / CATEGORY_ITEMS_PER_PAGE))
	categoryPageIndex = math.clamp(categoryPageIndex, 1, totalPages)
	pageLabel.Text = "page " .. categoryPageIndex .. "/" .. totalPages

	local pageEntries = paginate(items, categoryPageIndex, CATEGORY_ITEMS_PER_PAGE)
	if #pageEntries == 0 then
		createPlaceholderRow(1)
	else
		for order, item in ipairs(pageEntries) do
			if item.type == "toggle" then
				createToggleRow(item.label, order, item.key)
			elseif item.type == "stepper" then
				createStepperRow(item.label, order, item.key, item.min, item.max, item.step)
			elseif item.type == "theme" then
				createThemePickerRow(order)
			elseif item.type == "fontpick" then
				createFontPickerRow(order)
			elseif item.type == "action" then
				createActionRow(item.label, order, function()
					local handler = actionHandlers[item.action]
					if handler then handler() end
				end)
			elseif item.type == "rebind" then
				createActionRow(item.label .. " (" .. ByteMenu.menuToggleKey.Name .. ")", order, function(nameLabel)
					beginRebindMenuKey(nameLabel, item.label)
				end)
			end
		end
	end
end

-- Arrows and the Next Page bar only move within whatever view (root list or
-- an opened category) is currently active - never jump between categories.
local function goToPreviousPage()
	if viewMode == "root" then
		rootPageIndex = rootPageIndex - 1
	else
		categoryPageIndex = categoryPageIndex - 1
	end
	renderCurrentPage()
end

local function goToNextPage()
	if viewMode == "root" then
		rootPageIndex = rootPageIndex + 1
	else
		categoryPageIndex = categoryPageIndex + 1
	end
	renderCurrentPage()
end

leftArrowButton.MouseButton1Click:Connect(goToPreviousPage)
rightArrowButton.MouseButton1Click:Connect(goToNextPage)
nextPageButton.MouseButton1Click:Connect(goToNextPage)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchText = searchBox.Text
	if viewMode == "root" then
		rootPageIndex = 1
		renderCurrentPage()
	end
end)

-- Refresh the Players page live as people join/leave while it's open.
table.insert(ByteMenu.connections, playersService.PlayerAdded:Connect(function()
	if viewMode == "category" and categories[activeCategoryIndex] and categories[activeCategoryIndex].dynamic then
		renderCurrentPage()
	end
end))
table.insert(ByteMenu.connections, playersService.PlayerRemoving:Connect(function()
	if viewMode == "category" and categories[activeCategoryIndex] and categories[activeCategoryIndex].dynamic then
		renderCurrentPage()
	end
end))

---Flip the menu's open/closed state, driven by either the toggle button or keybind.
local function setMenuOpen(state)
	ByteMenu.menuOpen = state
	mainFrame.Visible = state
	disconnectButton.Visible = state
end

toggleButton.MouseButton1Click:Connect(function()
	setMenuOpen(not ByteMenu.menuOpen)
end)

table.insert(ByteMenu.connections, userInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == ByteMenu.menuToggleKey then
		setMenuOpen(not ByteMenu.menuOpen)
	end
end))

---Fully unload the menu and restore any hooked function + modified state.
local function detachByteMenu()
	for _, connection in ipairs(ByteMenu.connections) do
		pcall(function() connection:Disconnect() end)
	end
	clearEsp()

	for _, highlight in pairs(chamHighlights) do
		pcall(function() highlight:Destroy() end)
	end
	table.clear(chamHighlights)

	ByteMenu.objectNoclipEnabled = false
	applyObjectNoclip(localPlayer.Character)

	ByteMenu.fullbrightEnabled = false
	applyFullbright()

	ByteMenu.removeFogEnabled = false
	applyRemoveFog()

	ByteMenu.fpsUnlockEnabled = false
	applyFpsUnlock()

	pcall(function() runService:UnbindFromRenderStep("ByteCustomFov") end)

	if ByteMenu.controllerClass then
		pcall(restorefunction, ByteMenu.controllerClass.step)
	end
	if ByteMenu.capsuleMotorClass then
		pcall(restorefunction, ByteMenu.capsuleMotorClass.step)
	end

	if loadingGui and loadingGui.Parent then
		loadingGui:Destroy()
	end
	if screenGui and screenGui.Parent then
		screenGui:Destroy()
	end
end

disconnectButton.MouseButton1Click:Connect(detachByteMenu)

---This is called when initialization errors.
---@param errorMessage string
local function onInitializeError(errorMessage)
	warn("Byte: failed to initialize.")
	warn(errorMessage)
	warn(debug.traceback())
end

---Run the 5-second loading sequence, then reveal the main menu.
local function runLoadingSequence()
	local phaseDuration = LOADING_DURATION / #LOADING_PHASES
	local startClock = os.clock()

	for _, phaseText in ipairs(LOADING_PHASES) do
		loadingStatus.Text = phaseText
		local phaseStart = os.clock()
		while os.clock() - phaseStart < phaseDuration do
			local elapsed = os.clock() - startClock
			progressFill.Size = UDim2.new(math.clamp(elapsed / LOADING_DURATION, 0, 1), 0, 1, 0)
			task.wait()
		end
	end

	progressFill.Size = UDim2.new(1, 0, 1, 0)
	tweenService:Create(bypassedBanner, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	task.wait(0.8)

	screenGui.Enabled = true
	mainFrame.Visible = ByteMenu.menuOpen
	disconnectButton.Visible = ByteMenu.menuOpen
	toggleButton.Visible = true

	local fadeOut = tweenService:Create(loadingBackground, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	tweenService:Create(loadingShieldImage, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
	tweenService:Create(loadingTitle, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	tweenService:Create(loadingStatus, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	tweenService:Create(bypassedBanner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	tweenService:Create(creditsLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	fadeOut:Play()
	fadeOut.Completed:Wait()
	loadingGui:Destroy()
end

---Capture spawn/safe position and keep noclip synced whenever the character respawns.
---@param character Instance
local function onCharacterAdded(character)
	watchCharacterForNoclip(character)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		ByteMenu.spawnPosition = hrp.Position
		ByteMenu.lastSafePosition = hrp.Position
	end
end

---Finds both movement classes, hooks them, and starts the per-frame loops.
local function initializeByteMenu()
	applyThemeGlobal()
	renderCurrentPage()

	runService:BindToRenderStep("ByteCustomFov", Enum.RenderPriority.Camera.Value + 1, function()
		if ByteMenu.customFovEnabled then
			workspace.CurrentCamera.FieldOfView = ByteMenu.customFovValue
		end
	end)

	table.insert(ByteMenu.connections, runService.RenderStepped:Connect(function(deltaTime)
		currentCamera = workspace.CurrentCamera
		updateEsp()
		refreshChams()
		fpsLabel.Text = string.format("FPS : %d", math.floor(1 / math.max(deltaTime, 0.0001)))

		local character = localPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if hrp then
			if ByteMenu.controllerInstance and ByteMenu.controllerInstance.motor and ByteMenu.controllerInstance.motor.grounded then
				ByteMenu.lastSafePosition = hrp.Position
			end
			if ByteMenu.antiVoidEnabled and hrp.Position.Y < ByteMenu.antiVoidHeight then
				local recoverPosition = ByteMenu.lastSafePosition or ByteMenu.spawnPosition
				if recoverPosition then
					pcall(function()
						if ByteMenu.controllerInstance then
							ByteMenu.controllerInstance:correct(CFrame.new(recoverPosition))
						else
							hrp.CFrame = CFrame.new(recoverPosition)
						end
					end)
				end
			end
		end

		if humanoid then
			if ByteMenu.godModeEnabled then
				humanoid.Health = humanoid.MaxHealth
			elseif ByteMenu.regenHealthEnabled then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + ByteMenu.regenRate * deltaTime)
			end
		end
	end))

	table.insert(ByteMenu.connections, localPlayer.Idled:Connect(function()
		if not ByteMenu.antiAfkEnabled then return end
		pcall(function()
			mousemoverel(1, 0)
			mousemoverel(-1, 0)
		end)
	end))

	table.insert(ByteMenu.connections, localPlayer.CharacterAdded:Connect(onCharacterAdded))
	if localPlayer.Character then
		onCharacterAdded(localPlayer.Character)
	end

	task.spawn(runLoadingSequence)

	ByteMenu.controllerClass, ByteMenu.capsuleMotorClass = waitForClasses()
	if not ByteMenu.controllerClass or not ByteMenu.capsuleMotorClass then
		warn("Byte: movement classes never appeared, movement mods disabled.")
		return
	end
	hookControllerStep()
	hookCapsuleMotorStep()
end

-- Detach any previous instance before installing a new one (singleton pattern).
if shared.ByteMenu then
	pcall(shared.ByteMenu.detach)
end

ByteMenu.detach = detachByteMenu
shared.ByteMenu = ByteMenu

task.spawn(function()
	xpcall(initializeByteMenu, onInitializeError)
end)
