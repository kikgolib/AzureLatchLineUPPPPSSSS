local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- НАСТРОЙКИ И ПЕРЕМЕННЫЕ
local saveKey = Enum.KeyCode.G
local toggleUIKey = Enum.KeyCode.K
local ACTIVATION_RADIUS = 3
local TURN_SPEED = 0.15
local FILE_NAME = "AutoLook_Config.json"
local GITHUB_LINK = "https://github.com/kikgolib/AzureLatchLineUPPPPSSSS"

local savedPoints = {}
local pointCounter = 0
local visualObjects = {}

local renderConnection = nil
local inputConnection = nil
local waitingForKeyType = nil

--------------------------------------------------------------------------------
-- РАБОТА С ФАЙЛАМИ (JSON)
--------------------------------------------------------------------------------

local function saveToFile()
	if not writefile then return end

	local exportTable = {
		saveKey = saveKey.Name,
		toggleUIKey = toggleUIKey.Name,
		points = {}
	}

	for _, point in ipairs(savedPoints) do
		table.insert(exportTable.points, {
			name = point.name,
			position = {point.position.X, point.position.Y, point.position.Z},
			cameraCFrame = {point.cameraCFrame:GetComponents()},
			color = {point.color.R, point.color.G, point.color.B},
			showESP = point.showESP,
			showHighlight = point.showHighlight
		})
	end

	pcall(function()
		writefile(FILE_NAME, HttpService:JSONEncode(exportTable))
	end)
end

local function loadFromFile()
	if not readfile or not isfile or not isfile(FILE_NAME) then return end

	local success, result = pcall(function()
		return HttpService:JSONDecode(readfile(FILE_NAME))
	end)

	if success and type(result) == "table" then
		if result.saveKey and Enum.KeyCode[result.saveKey] then
			saveKey = Enum.KeyCode[result.saveKey]
		end
		if result.toggleUIKey and Enum.KeyCode[result.toggleUIKey] then
			toggleUIKey = Enum.KeyCode[result.toggleUIKey]
		end

		if result.points then
			savedPoints = {}
			for _, item in ipairs(result.points) do
				local col = item.color or {1, 0.8, 0}
				table.insert(savedPoints, {
					name = item.name,
					position = Vector3.new(item.position[1], item.position[2], item.position[3]),
					cameraCFrame = CFrame.new(unpack(item.cameraCFrame)),
					color = Color3.new(col[1], col[2], col[3]),
					showESP = item.showESP ~= false,
					showHighlight = item.showHighlight ~= false
				})
			end
			pointCounter = #savedPoints
		end
	end
end

--------------------------------------------------------------------------------
-- УПРАВЛЕНИЕ 3D ВИЗУАЛОМ (ESP / HIGHLIGHT)
--------------------------------------------------------------------------------

local function clearVisuals()
	for _, obj in pairs(visualObjects) do
		if obj and obj.Parent then
			obj:Destroy()
		end
	end
	visualObjects = {}

	local folder = workspace:FindFirstChild("AutoLook_Visuals")
	if folder then
		folder:Destroy()
	end
end

local function updateVisuals()
	clearVisuals()

	local folder = Instance.new("Folder")
	folder.Name = "AutoLook_Visuals"
	folder.Parent = workspace

	for index, point in ipairs(savedPoints) do
		local part = Instance.new("Part")
		part.Name = "Point_" .. index
		part.Size = Vector3.new(1.5, 1.5, 1.5)
		part.Position = point.position
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Parent = folder
		table.insert(visualObjects, part)

		if point.showHighlight then
			local highlight = Instance.new("Highlight")
			highlight.Adornee = part
			highlight.FillColor = point.color
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = part
		end

		if point.showESP then
			local billboard = Instance.new("BillboardGui")
			billboard.Adornee = part
			billboard.Size = UDim2.new(0, 120, 0, 40)
			billboard.StudsOffset = Vector3.new(0, 2.5, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = part

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = point.color
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			label.Font = Enum.Font.SourceSansBold
			label.TextSize = 14
			label.Text = point.name
			label.Parent = billboard

			RunService.RenderStepped:Connect(function()
				if part and part.Parent and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
					local dist = math.floor((localPlayer.Character.HumanoidRootPart.Position - point.position).Magnitude)
					label.Text = point.name .. "\n[" .. dist .. "m]"
				end
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- ИНТЕРФЕЙС (GUI)
--------------------------------------------------------------------------------

local playerGui = localPlayer:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("AutoLookGui") then
	playerGui.AutoLookGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoLookGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

--------------------------------------------------------------------------------
-- ПЛАВАЮЩАЯ КНОПКА ОТКРЫТИЯ/ЗАКРЫТИЯ UI (TOGGLE BUTTON)
--------------------------------------------------------------------------------
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "OpenToggleButton"
toggleBtn.Size = UDim2.new(0, 110, 0, 35)
toggleBtn.Position = UDim2.new(0, 20, 0.2, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
toggleBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
toggleBtn.Text = "AutoLook [UI]"
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 14
toggleBtn.Active = true
toggleBtn.Draggable = true -- Перетаскивается мышкой или пальцем
toggleBtn.Parent = screenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = toggleBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(80, 80, 100)
btnStroke.Thickness = 1.5
btnStroke.Parent = toggleBtn

--------------------------------------------------------------------------------
-- ГЛАВНОЕ ОКНО
--------------------------------------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 310, 0, 420)
mainFrame.Position = UDim2.new(0, 20, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- Связка нажатия плавающей кнопки с видимостью главного окна
toggleBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

-- Вкладки (Tabs)
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, 0, 0, 35)
tabFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
tabFrame.BorderSizePixel = 0
tabFrame.Parent = mainFrame

local pointsTabBtn = Instance.new("TextButton")
pointsTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
pointsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
pointsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
pointsTabBtn.Text = "Точки"
pointsTabBtn.Font = Enum.Font.SourceSansBold
pointsTabBtn.TextSize = 15
pointsTabBtn.Parent = tabFrame

local configTabBtn = Instance.new("TextButton")
configTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
configTabBtn.Position = UDim2.new(0.5, 0, 0, 0)
configTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
configTabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
configTabBtn.Text = "Config"
configTabBtn.Font = Enum.Font.SourceSansBold
configTabBtn.TextSize = 15
configTabBtn.Parent = tabFrame

local pointsPage = Instance.new("Frame")
pointsPage.Size = UDim2.new(1, -10, 1, -45)
pointsPage.Position = UDim2.new(0, 5, 0, 40)
pointsPage.BackgroundTransparency = 1
pointsPage.Parent = mainFrame

local configPage = Instance.new("ScrollingFrame")
configPage.Size = UDim2.new(1, -10, 1, -45)
configPage.Position = UDim2.new(0, 5, 0, 40)
configPage.BackgroundTransparency = 1
configPage.CanvasSize = UDim2.new(0, 0, 0, 460)
configPage.ScrollBarThickness = 6
configPage.Visible = false
configPage.Parent = mainFrame

pointsTabBtn.MouseButton1Click:Connect(function()
	pointsPage.Visible = true
	configPage.Visible = false
	pointsTabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	pointsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	configTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	configTabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
end)

configTabBtn.MouseButton1Click:Connect(function()
	pointsPage.Visible = false
	configPage.Visible = true
	configTabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	configTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	pointsTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	pointsTabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
end)

--------------------------------------------------------------------------------
-- ВКЛАДКА "ТОЧКИ"
--------------------------------------------------------------------------------

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = pointsPage

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = scrollFrame
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 6)

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end)

local function refreshUI()
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for index, point in ipairs(savedPoints) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 65)
		card.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
		card.BorderSizePixel = 0
		card.Parent = scrollFrame

		local nameBox = Instance.new("TextBox")
		nameBox.Size = UDim2.new(0.6, 0, 0, 25)
		nameBox.Position = UDim2.new(0, 5, 0, 5)
		nameBox.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
		nameBox.Text = point.name
		nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameBox.Font = Enum.Font.SourceSans
		nameBox.TextSize = 14
		nameBox.Parent = card

		nameBox.FocusLost:Connect(function()
			if nameBox.Text ~= "" then
				point.name = nameBox.Text
				saveToFile()
				updateVisuals()
			else
				nameBox.Text = point.name
			end
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.new(0.35, -5, 0, 25)
		delBtn.Position = UDim2.new(0.65, 0, 0, 5)
		delBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		delBtn.Text = "Удалить"
		delBtn.Font = Enum.Font.SourceSansBold
		delBtn.TextSize = 13
		delBtn.Parent = card

		delBtn.MouseButton1Click:Connect(function()
			table.remove(savedPoints, index)
			saveToFile()
			updateVisuals()
			refreshUI()
		end)

		local espToggle = Instance.new("TextButton")
		espToggle.Size = UDim2.new(0.3, 0, 0, 25)
		espToggle.Position = UDim2.new(0, 5, 0, 35)
		espToggle.BackgroundColor3 = point.showESP and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(80, 80, 80)
		espToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
		espToggle.Text = "ESP: " .. (point.showESP and "ON" or "OFF")
		espToggle.Font = Enum.Font.SourceSans
		espToggle.TextSize = 12
		espToggle.Parent = card

		espToggle.MouseButton1Click:Connect(function()
			point.showESP = not point.showESP
			saveToFile()
			updateVisuals()
			refreshUI()
		end)

		local hlToggle = Instance.new("TextButton")
		hlToggle.Size = UDim2.new(0.35, 0, 0, 25)
		hlToggle.Position = UDim2.new(0.32, 0, 0, 35)
		hlToggle.BackgroundColor3 = point.showHighlight and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(80, 80, 80)
		hlToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
		hlToggle.Text = "Highlight: " .. (point.showHighlight and "ON" or "OFF")
		hlToggle.Font = Enum.Font.SourceSans
		hlToggle.TextSize = 12
		hlToggle.Parent = card

		hlToggle.MouseButton1Click:Connect(function()
			point.showHighlight = not point.showHighlight
			saveToFile()
			updateVisuals()
			refreshUI()
		end)

		local colorBtn = Instance.new("TextButton")
		colorBtn.Size = UDim2.new(0.3, -5, 0, 25)
		colorBtn.Position = UDim2.new(0.68, 0, 0, 35)
		colorBtn.BackgroundColor3 = point.color
		colorBtn.Text = "Цвет"
		colorBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		colorBtn.Font = Enum.Font.SourceSansBold
		colorBtn.TextSize = 12
		colorBtn.Parent = card

		local colors = {Color3.fromRGB(255, 200, 0), Color3.fromRGB(0, 255, 150), Color3.fromRGB(255, 50, 50), Color3.fromRGB(50, 150, 255), Color3.fromRGB(200, 50, 255)}
		local colorIdx = 1
		colorBtn.MouseButton1Click:Connect(function()
			colorIdx = (colorIdx % #colors) + 1
			point.color = colors[colorIdx]
			saveToFile()
			updateVisuals()
			refreshUI()
		end)
	end
end

--------------------------------------------------------------------------------
-- ВКЛАДКА "CONFIG"
--------------------------------------------------------------------------------

local saveKeyLabel = Instance.new("TextLabel")
saveKeyLabel.Size = UDim2.new(1, 0, 0, 20)
saveKeyLabel.Position = UDim2.new(0, 0, 0, 5)
saveKeyLabel.BackgroundTransparency = 1
saveKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
saveKeyLabel.Text = "Клавиша записи точки:"
saveKeyLabel.Font = Enum.Font.SourceSansBold
saveKeyLabel.TextSize = 14
saveKeyLabel.Parent = configPage

local saveKeyBtn = Instance.new("TextButton")
saveKeyBtn.Size = UDim2.new(1, -10, 0, 28)
saveKeyBtn.Position = UDim2.new(0, 0, 0, 28)
saveKeyBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
saveKeyBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
saveKeyBtn.Text = "[" .. saveKey.Name .. "]"
saveKeyBtn.Font = Enum.Font.SourceSansBold
saveKeyBtn.TextSize = 15
saveKeyBtn.Parent = configPage

saveKeyBtn.MouseButton1Click:Connect(function()
	waitingForKeyType = "save"
	saveKeyBtn.Text = "Нажмите клавишу..."
end)

local toggleKeyLabel = Instance.new("TextLabel")
toggleKeyLabel.Size = UDim2.new(1, 0, 0, 20)
toggleKeyLabel.Position = UDim2.new(0, 0, 0, 65)
toggleKeyLabel.BackgroundTransparency = 1
toggleKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleKeyLabel.Text = "Клавиша скрыть/показать UI:"
toggleKeyLabel.Font = Enum.Font.SourceSansBold
toggleKeyLabel.TextSize = 14
toggleKeyLabel.Parent = configPage

local toggleKeyBtn = Instance.new("TextButton")
toggleKeyBtn.Size = UDim2.new(1, -10, 0, 28)
toggleKeyBtn.Position = UDim2.new(0, 0, 0, 88)
toggleKeyBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
toggleKeyBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
toggleKeyBtn.Text = "[" .. toggleUIKey.Name .. "]"
toggleKeyBtn.Font = Enum.Font.SourceSansBold
toggleKeyBtn.TextSize = 15
toggleKeyBtn.Parent = configPage

toggleKeyBtn.MouseButton1Click:Connect(function()
	waitingForKeyType = "toggle"
	toggleKeyBtn.Text = "Нажмите клавишу..."
end)

local hideUiBtn = Instance.new("TextButton")
hideUiBtn.Size = UDim2.new(1, -10, 0, 30)
hideUiBtn.Position = UDim2.new(0, 0, 0, 130)
hideUiBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
hideUiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hideUiBtn.Text = "Скрыть меню (Hide UI)"
hideUiBtn.Font = Enum.Font.SourceSansBold
hideUiBtn.TextSize = 14
hideUiBtn.Parent = configPage

hideUiBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

local clearAllBtn = Instance.new("TextButton")
clearAllBtn.Size = UDim2.new(1, -10, 0, 30)
clearAllBtn.Position = UDim2.new(0, 0, 0, 170)
clearAllBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 30)
clearAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearAllBtn.Text = "Удалить все точки"
clearAllBtn.Font = Enum.Font.SourceSansBold
clearAllBtn.TextSize = 14
clearAllBtn.Parent = configPage

clearAllBtn.MouseButton1Click:Connect(function()
	savedPoints = {}
	saveToFile()
	updateVisuals()
	refreshUI()
end)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(1, -10, 0, 32)
unloadBtn.Position = UDim2.new(0, 0, 0, 210)
unloadBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadBtn.Text = "Выключить скрипт полностью"
unloadBtn.Font = Enum.Font.SourceSansBold
unloadBtn.TextSize = 14
unloadBtn.Parent = configPage

local ghLabel = Instance.new("TextLabel")
ghLabel.Size = UDim2.new(1, 0, 0, 20)
ghLabel.Position = UDim2.new(0, 0, 0, 255)
ghLabel.BackgroundTransparency = 1
ghLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ghLabel.Text = "GitHub (клик для копирования):"
ghLabel.Font = Enum.Font.SourceSansBold
ghLabel.TextSize = 13
ghLabel.Parent = configPage

local ghBox = Instance.new("TextBox")
ghBox.Size = UDim2.new(1, -10, 0, 28)
ghBox.Position = UDim2.new(0, 0, 0, 278)
ghBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
ghBox.TextColor3 = Color3.fromRGB(100, 180, 255)
ghBox.Text = GITHUB_LINK
ghBox.Font = Enum.Font.SourceSans
ghBox.TextSize = 12
ghBox.ClearTextOnFocus = false
ghBox.Parent = configPage

ghBox.Focused:Connect(function()
	if setclipboard then
		setclipboard(GITHUB_LINK)
		ghBox.Text = "Ссылка скопирована!"
		task.wait(1.5)
		ghBox.Text = GITHUB_LINK
	end
end)

local creditsLabel = Instance.new("TextLabel")
creditsLabel.Size = UDim2.new(1, 0, 0, 25)
creditsLabel.Position = UDim2.new(0, 0, 0, 315)
creditsLabel.BackgroundTransparency = 1
creditsLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
creditsLabel.Text = "made by amsobruv"
creditsLabel.Font = Enum.Font.SourceSansItalic
creditsLabel.TextSize = 15
creditsLabel.Parent = configPage

--------------------------------------------------------------------------------
-- ЛОГИКА СОХРАНЕНИЯ, ВЫКЛЮЧЕНИЯ И ВВОДА
--------------------------------------------------------------------------------

local function unloadScript()
	if renderConnection then renderConnection:Disconnect() end
	if inputConnection then inputConnection:Disconnect() end
	clearVisuals()
	if screenGui then screenGui:Destroy() end
	print("[AutoLook] Скрипт полностью выключен!")
end

unloadBtn.MouseButton1Click:Connect(unloadScript)

local function saveCurrentLocation()
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	pointCounter = pointCounter + 1
	local pointData = {
		name = "Точка " .. pointCounter,
		position = character.HumanoidRootPart.Position,
		cameraCFrame = camera.CFrame,
		color = Color3.fromRGB(255, 200, 0),
		showESP = true,
		showHighlight = true
	}

	table.insert(savedPoints, pointData)
	saveToFile()
	updateVisuals()
	refreshUI()
end

loadFromFile()
updateVisuals()
refreshUI()

-- Проверка расстояния
renderConnection = RunService.RenderStepped:Connect(function()
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local currentPos = character.HumanoidRootPart.Position

	for _, point in ipairs(savedPoints) do
		local distance = (currentPos - point.position).Magnitude

		if distance <= ACTIVATION_RADIUS then
			local targetRotation = CFrame.new(camera.CFrame.Position) * point.cameraCFrame.Rotation
			camera.CFrame = camera.CFrame:Lerp(targetRotation, TURN_SPEED)
		end
	end
end)

-- Ввод с клавиатуры
inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if waitingForKeyType and input.UserInputType == Enum.UserInputType.Keyboard then
		if waitingForKeyType == "save" then
			saveKey = input.KeyCode
			saveKeyBtn.Text = "[" .. saveKey.Name .. "]"
		elseif waitingForKeyType == "toggle" then
			toggleUIKey = input.KeyCode
			toggleKeyBtn.Text = "[" .. toggleUIKey.Name .. "]"
		end
		waitingForKeyType = nil
		saveToFile()
		return
	end

	if input.KeyCode == saveKey then
		saveCurrentLocation()
	elseif input.KeyCode == toggleUIKey then
		mainFrame.Visible = not mainFrame.Visible
	end
end)
