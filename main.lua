local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- НАСТРОЙКИ ПО УМОЛЧАНИЮ
local saveKey = Enum.KeyCode.G
local ACTIVATION_RADIUS = 3
local TURN_SPEED = 0.15
local FILE_NAME = "AutoLook_Config.json"
local GITHUB_LINK = "https://github.com/amsobruv/roblox-autolook"

local savedPoints = {}
local pointCounter = 0
local visualObjects = {} -- Хранилище ESP и Highlight

--------------------------------------------------------------------------------
-- РАБОТА С ФАЙЛАМИ
--------------------------------------------------------------------------------

local function saveToFile()
	if not writefile then return end

	local exportTable = {
		keybind = saveKey.Name,
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
		return HttpService:JSONEncode(readfile(FILE_NAME))
	end)

	if success and type(result) == "table" then
		if result.keybind and Enum.KeyCode[result.keybind] then
			saveKey = Enum.KeyCode[result.keybind]
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
end

local function updateVisuals()
	clearVisuals()

	local folder = workspace:FindFirstChild("AutoLook_Visuals") or Instance.new("Folder")
	folder.Name = "AutoLook_Visuals"
	folder.Parent = workspace

	for index, point in ipairs(savedPoints) do
		-- Создаем физический анкор для точки
		local part = Instance.new("Part")
		part.Name = "Point_" .. index
		part.Size = Vector3.new(1.5, 1.5, 1.5)
		part.Position = point.position
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Parent = folder
		table.insert(visualObjects, part)

		-- 3D Highlight
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

		-- 3D ESP (BillboardGui)
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

			-- Обновление дистанции
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

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 380)
mainFrame.Position = UDim2.new(0, 20, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

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

-- Контейнеры для содержимого
local pointsPage = Instance.new("Frame")
pointsPage.Size = UDim2.new(1, -10, 1, -45)
pointsPage.Position = UDim2.new(0, 5, 0, 40)
pointsPage.BackgroundTransparency = 1
pointsPage.Parent = mainFrame

local configPage = Instance.new("Frame")
configPage.Size = UDim2.new(1, -10, 1, -45)
configPage.Position = UDim2.new(0, 5, 0, 40)
configPage.BackgroundTransparency = 1
configPage.Visible = false
configPage.Parent = mainFrame

-- Переключение вкладок
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

		-- Переименование
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

		-- Кнопка удаления
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

		-- Переключатели ESP и Highlight
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

		-- Кнопка смены цвета
		local colorBtn = Instance.new("TextButton")
		colorBtn.Size = UDim2.new(0.3, -5, 0, 25)
		colorBtn.Position = UDim2.new(0.68, 0, 0, 35)
		colorBtn.BackgroundColor3 = point.color
		colorBtn.Text = "Цвет"
		colorBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		colorBtn.Font = Enum.Font.SourceSansBold
		colorBtn.TextSize = 12
		colorBtn.Parent = card

		-- Быстрая смена палитры при клике
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

-- Настройка Keybind
local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(1, 0, 0, 25)
keyLabel.Position = UDim2.new(0, 0, 0, 10)
keyLabel.BackgroundTransparency = 1
keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyLabel.Text = "Клавиша записи точек:"
keyLabel.Font = Enum.Font.SourceSansBold
keyLabel.TextSize = 15
keyLabel.Parent = configPage

local keyBtn = Instance.new("TextButton")
keyBtn.Size = UDim2.new(1, 0, 0, 30)
keyBtn.Position = UDim2.new(0, 0, 0, 40)
keyBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
keyBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
keyBtn.Text = "[" .. saveKey.Name .. "]"
keyBtn.Font = Enum.Font.SourceSansBold
keyBtn.TextSize = 16
keyBtn.Parent = configPage

local waitingForKey = false
keyBtn.MouseButton1Click:Connect(function()
	waitingForKey = true
	keyBtn.Text = "Нажмите любую клавишу..."
end)

-- Ссылка на GitHub
local ghLabel = Instance.new("TextLabel")
ghLabel.Size = UDim2.new(1, 0, 0, 25)
ghLabel.Position = UDim2.new(0, 0, 0, 90)
ghLabel.BackgroundTransparency = 1
ghLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ghLabel.Text = "GitHub Репозиторий (клик для копирования):"
ghLabel.Font = Enum.Font.SourceSansBold
ghLabel.TextSize = 14
ghLabel.Parent = configPage

local ghBox = Instance.new("TextBox")
ghBox.Size = UDim2.new(1, 0, 0, 30)
ghBox.Position = UDim2.new(0, 0, 0, 120)
ghBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
ghBox.TextColor3 = Color3.fromRGB(100, 180, 255)
ghBox.Text = GITHUB_LINK
ghBox.Font = Enum.Font.SourceSans
ghBox.TextSize = 13
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

-- Авторство (made by amsobruv)
local creditsLabel = Instance.new("TextLabel")
creditsLabel.Size = UDim2.new(1, 0, 0, 30)
creditsLabel.Position = UDim2.new(0, 0, 1, -35)
creditsLabel.BackgroundTransparency = 1
creditsLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
creditsLabel.Text = "made by amsobruv"
creditsLabel.Font = Enum.Font.SourceSansItalic
creditsLabel.TextSize = 16
creditsLabel.Parent = configPage

--------------------------------------------------------------------------------
-- ЛОГИКА СОХРАНЕНИЯ И ВВОДА
--------------------------------------------------------------------------------

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

-- Проверка дистанции для автоповорота
RunService.RenderStepped:Connect(function()
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

-- Ввод клавиш
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if waitingForKey and input.UserInputType == Enum.UserInputType.Keyboard then
		saveKey = input.KeyCode
		keyBtn.Text = "[" .. saveKey.Name .. "]"
		waitingForKey = false
		saveToFile()
		return
	end

	if input.KeyCode == saveKey then
		saveCurrentLocation()
	end
end)
