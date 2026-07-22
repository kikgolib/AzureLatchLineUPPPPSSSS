Ошибка **`attempt to call a nil value`** означает, что скрипт пытается вызвать как функцию то, что равно `nil` (не существует в вашем экскуторе).

В данном коде это происходит из-за функций работы с буфером обмена или файлами, если экскутор их не поддерживает (например, `setclipboard`, `writefile`, `readfile` или `isfile`).

Ниже исправленный вариант кода, в котором добавлены безопасные проверки (`pcall` и проверки на наличие функций) — теперь скрипт **не будет вылетать с ошибкой**, даже если ваш экскутор не поддерживает сохранение файлов или копирование в буфер обмена.

```lua
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local saveKey = Enum.KeyCode.G
local toggleUIKey = Enum.KeyCode.K
local DEFAULT_ACTIVATION_RADIUS = 3
local TURN_SPEED = 0.15
local FILE_NAME = "AutoLook_Config.json"
local GITHUB_LINK = "https://github.com/kikgolib/AzureLatchLineUPPPPSSSS"

local currentLang = "EN"
local currentTheme = "Obsidian"
local savedPoints = {}
local pointCounter = 0
local visualObjects = {}

local renderConnection = nil
local inputConnection = nil
local waitingForKeyType = nil

local themes = {
	Obsidian = {
		mainBg = Color3.fromRGB(15, 16, 20),
		topBg = Color3.fromRGB(22, 24, 30),
		cardBg = Color3.fromRGB(26, 28, 36),
		accent = Color3.fromRGB(88, 101, 242),
		text = Color3.fromRGB(240, 240, 245),
		subText = Color3.fromRGB(140, 145, 160),
		border = Color3.fromRGB(35, 38, 50)
	},
	Midnight = {
		mainBg = Color3.fromRGB(16, 12, 26),
		topBg = Color3.fromRGB(24, 18, 40),
		cardBg = Color3.fromRGB(32, 24, 52),
		accent = Color3.fromRGB(168, 85, 247),
		text = Color3.fromRGB(245, 240, 255),
		subText = Color3.fromRGB(160, 140, 190),
		border = Color3.fromRGB(48, 36, 75)
	},
	Cyber = {
		mainBg = Color3.fromRGB(10, 15, 20),
		topBg = Color3.fromRGB(15, 24, 32),
		cardBg = Color3.fromRGB(20, 32, 44),
		accent = Color3.fromRGB(0, 230, 180),
		text = Color3.fromRGB(230, 255, 250),
		subText = Color3.fromRGB(100, 170, 170),
		border = Color3.fromRGB(30, 55, 70)
	},
	OLED = {
		mainBg = Color3.fromRGB(0, 0, 0),
		topBg = Color3.fromRGB(10, 10, 10),
		cardBg = Color3.fromRGB(18, 18, 18),
		accent = Color3.fromRGB(255, 255, 255),
		text = Color3.fromRGB(255, 255, 255),
		subText = Color3.fromRGB(130, 130, 130),
		border = Color3.fromRGB(35, 35, 35)
	}
}

local translations = {
	EN = {
		pointsTab = "Points",
		configTab = "Settings",
		delete = "Delete",
		color = "Color",
		shape = "Shape",
		sq = "Square",
		ci = "Circle",
		tr = "Triangle",
		im = "Image",
		imgPlaceholder = "Asset ID...",
		hitboxLbl = "Hitbox (m):",
		saveKeyLbl = "Save Key",
		toggleKeyLbl = "Menu Key",
		langLbl = "Language",
		themeLbl = "UI Theme",
		hideUi = "Minimize UI",
		clearAll = "Clear All Points",
		unload = "Unload",
		pressKey = "Press key...",
		copied = "Copied!"
	},
	RU = {
		pointsTab = "Точки",
		configTab = "Настройки",
		delete = "Удалить",
		color = "Цвет",
		shape = "Форма",
		sq = "Квадрат",
		ci = "Круг",
		tr = "Треугольник",
		im = "Картинка",
		imgPlaceholder = "Asset ID...",
		hitboxLbl = "Хитбокс (м):",
		saveKeyLbl = "Бинд сохранения",
		toggleKeyLbl = "Бинд меню",
		langLbl = "Язык",
		themeLbl = "Тема UI",
		hideUi = "Скрыть UI",
		clearAll = "Очистить точки",
		unload = "Выгрузить",
		pressKey = "Нажмите...",
		copied = "Скопировано!"
	}
}

local function t(key)
	return (translations[currentLang] and translations[currentLang][key]) or translations["EN"][key] or ""
end

local function parseAssetId(input)
	if not input or input == "" then return "" end
	local id = input:match("%d+")
	if id then return "rbxassetid://" .. id end
	return input
end

local function saveToFile()
	if type(writefile) ~= "function" then return end

	local exportTable = {
		saveKey = saveKey.Name,
		toggleUIKey = toggleUIKey.Name,
		language = currentLang,
		theme = currentTheme,
		points = {}
	}

	for _, point in ipairs(savedPoints) do
		table.insert(exportTable.points, {
			name = point.name,
			position = {point.position.X, point.position.Y, point.position.Z},
			cameraCFrame = {point.cameraCFrame:GetComponents()},
			color = {point.color.R, point.color.G, point.color.B},
			showESP = point.showESP,
			showHighlight = point.showHighlight,
			shape = point.shape or "Square",
			imageId = point.imageId or "",
			hitbox = point.hitbox or DEFAULT_ACTIVATION_RADIUS
		})
	end

	pcall(function()
		writefile(FILE_NAME, HttpService:JSONEncode(exportTable))
	end)
end

local function loadFromFile()
	if type(readfile) ~= "function" or type(isfile) ~= "function" then return end

	local exists = false
	pcall(function()
		exists = isfile(FILE_NAME)
	end)
	if not exists then return end

	local success, result = pcall(function()
		return HttpService:JSONDecode(readfile(FILE_NAME))
	end)

	if success and type(result) == "table" then
		if result.language and (result.language == "EN" or result.language == "RU") then
			currentLang = result.language
		end
		if result.theme and themes[result.theme] then
			currentTheme = result.theme
		end
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
					showHighlight = item.showHighlight ~= false,
					shape = item.shape or "Square",
					imageId = item.imageId or "",
					hitbox = tonumber(item.hitbox) or DEFAULT_ACTIVATION_RADIUS
				})
			end
			pointCounter = #savedPoints
		end
	end
end

local function clearVisuals()
	for _, obj in pairs(visualObjects) do
		if obj and obj.Parent then obj:Destroy() end
	end
	visualObjects = {}

	local folder = workspace:FindFirstChild("AutoLook_Visuals")
	if folder then folder:Destroy() end
end

local function updateVisuals()
	clearVisuals()

	local folder = Instance.new("Folder")
	folder.Name = "AutoLook_Visuals"
	folder.Parent = workspace

	for index, point in ipairs(savedPoints) do
		local shapeType = point.shape or "Square"
		local part

		if shapeType == "Circle" then
			part = Instance.new("Part")
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(0.2, 3, 3)
			part.CFrame = CFrame.new(point.position - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		elseif shapeType == "Triangle" then
			part = Instance.new("WedgePart")
			part.Size = Vector3.new(1.8, 1.8, 1.8)
			part.Position = point.position
		else
			part = Instance.new("Part")
			part.Shape = Enum.PartType.Block
			part.Size = Vector3.new(1.5, 1.5, 1.5)
			part.Position = point.position
		end

		part.Name = "Point_" .. index
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = point.color
		part.Transparency = point.showHighlight and 0.3 or 1
		part.Parent = folder
		table.insert(visualObjects, part)

		if shapeType == "Image" or (point.imageId and point.imageId ~= "") then
			local decalAsset = parseAssetId(point.imageId)
			if decalAsset ~= "" then
				for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
					local decal = Instance.new("Decal")
					decal.Texture = decalAsset
					decal.Face = face
					decal.Parent = part
				end
			end
		end

		if point.showHighlight then
			local highlight = Instance.new("Highlight")
			highlight.Adornee = part
			highlight.FillColor = point.color
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.4
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = part
		end

		if point.showESP then
			local billboard = Instance.new("BillboardGui")
			billboard.Adornee = part
			billboard.Size = UDim2.new(0, 140, 0, 40)
			billboard.StudsOffset = Vector3.new(0, 2.2, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = part

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = point.color
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 13
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

local playerGui = localPlayer:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("AutoLookGui") then
	playerGui.AutoLookGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoLookGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "OpenToggleButton"
toggleBtn.Size = UDim2.new(0, 42, 0, 42)
toggleBtn.Position = UDim2.new(0, 20, 0.2, 0)
toggleBtn.BackgroundColor3 = themes[currentTheme].topBg
toggleBtn.TextColor3 = themes[currentTheme].accent
toggleBtn.Text = "⚡"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 18
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = themes[currentTheme].border
toggleStroke.Thickness = 1
toggleStroke.Parent = toggleBtn

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 360, 0, 430)
mainFrame.Position = UDim2.new(0, 20, 0.5, -215)
mainFrame.BackgroundColor3 = themes[currentTheme].mainBg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = themes[currentTheme].border
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

toggleBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

local headerFrame = Instance.new("Frame")
headerFrame.Size = UDim2.new(1, 0, 0, 40)
headerFrame.BackgroundColor3 = themes[currentTheme].topBg
headerFrame.BorderSizePixel = 0
headerFrame.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = headerFrame

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = themes[currentTheme].topBg
headerFix.BorderSizePixel = 0
headerFix.Parent = headerFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 120, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AUTOLOOK"
titleLabel.TextColor3 = themes[currentTheme].text
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, 0)
accentLine.BackgroundColor3 = themes[currentTheme].accent
accentLine.BorderSizePixel = 0
accentLine.Parent = headerFrame

local navFrame = Instance.new("Frame")
navFrame.Size = UDim2.new(0, 100, 1, -42)
navFrame.Position = UDim2.new(0, 0, 0, 42)
navFrame.BackgroundColor3 = themes[currentTheme].topBg
navFrame.BorderSizePixel = 0
navFrame.Parent = mainFrame

local navDivider = Instance.new("Frame")
navDivider.Size = UDim2.new(0, 1, 1, 0)
navDivider.Position = UDim2.new(1, 0, 0, 0)
navDivider.BackgroundColor3 = themes[currentTheme].border
navDivider.BorderSizePixel = 0
navDivider.Parent = navFrame

local pointsTabBtn = Instance.new("TextButton")
pointsTabBtn.Size = UDim2.new(1, -12, 0, 32)
pointsTabBtn.Position = UDim2.new(0, 6, 0, 10)
pointsTabBtn.BackgroundColor3 = themes[currentTheme].cardBg
pointsTabBtn.TextColor3 = themes[currentTheme].text
pointsTabBtn.Font = Enum.Font.GothamBold
pointsTabBtn.TextSize = 11
pointsTabBtn.Parent = navFrame

local ptCorner = Instance.new("UICorner")
ptCorner.CornerRadius = UDim.new(0, 6)
ptCorner.Parent = pointsTabBtn

local configTabBtn = Instance.new("TextButton")
configTabBtn.Size = UDim2.new(1, -12, 0, 32)
configTabBtn.Position = UDim2.new(0, 6, 0, 48)
configTabBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
configTabBtn.BackgroundTransparency = 1
configTabBtn.TextColor3 = themes[currentTheme].subText
configTabBtn.Font = Enum.Font.GothamMedium
configTabBtn.TextSize = 11
configTabBtn.Parent = navFrame

local cfgCorner = Instance.new("UICorner")
cfgCorner.CornerRadius = UDim.new(0, 6)
cfgCorner.Parent = configTabBtn

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -108, 1, -50)
contentArea.Position = UDim2.new(0, 104, 0, 46)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local pointsPage = Instance.new("Frame")
pointsPage.Size = UDim2.new(1, 0, 1, 0)
pointsPage.BackgroundTransparency = 1
pointsPage.Parent = contentArea

local configPage = Instance.new("ScrollingFrame")
configPage.Size = UDim2.new(1, 0, 1, 0)
configPage.BackgroundTransparency = 1
configPage.CanvasSize = UDim2.new(0, 0, 0, 420)
configPage.ScrollBarThickness = 2
configPage.ScrollBarImageColor3 = themes[currentTheme].accent
configPage.Visible = false
configPage.Parent = contentArea

pointsTabBtn.MouseButton1Click:Connect(function()
	pointsPage.Visible = true
	configPage.Visible = false
	pointsTabBtn.BackgroundColor3 = themes[currentTheme].cardBg
	pointsTabBtn.BackgroundTransparency = 0
	pointsTabBtn.TextColor3 = themes[currentTheme].text
	pointsTabBtn.Font = Enum.Font.GothamBold

	configTabBtn.BackgroundTransparency = 1
	configTabBtn.TextColor3 = themes[currentTheme].subText
	configTabBtn.Font = Enum.Font.GothamMedium
end)

configTabBtn.MouseButton1Click:Connect(function()
	pointsPage.Visible = false
	configPage.Visible = true
	configTabBtn.BackgroundColor3 = themes[currentTheme].cardBg
	configTabBtn.BackgroundTransparency = 0
	configTabBtn.TextColor3 = themes[currentTheme].text
	configTabBtn.Font = Enum.Font.GothamBold

	pointsTabBtn.BackgroundTransparency = 1
	pointsTabBtn.TextColor3 = themes[currentTheme].subText
	pointsTabBtn.Font = Enum.Font.GothamMedium
end)

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -6, 1, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 2
scrollFrame.ScrollBarImageColor3 = themes[currentTheme].accent
scrollFrame.Parent = pointsPage

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = scrollFrame
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 6)

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end)

local shapeOrder = {"Square", "Circle", "Triangle", "Image"}

local function getShapeName(shapeKey)
	if shapeKey == "Circle" then return t("ci")
	elseif shapeKey == "Triangle" then return t("tr")
	elseif shapeKey == "Image" then return t("im")
	else return t("sq") end
end

local refreshUI

local function createRowLabel(text, posY)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 16)
	label.Position = UDim2.new(0, 0, 0, posY)
	label.BackgroundTransparency = 1
	label.TextColor3 = themes[currentTheme].subText
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = configPage
	return label
end

local saveKeyLbl = createRowLabel("", 4)
local saveKeyBtn = Instance.new("TextButton")
saveKeyBtn.Size = UDim2.new(1, -12, 0, 26)
saveKeyBtn.Position = UDim2.new(0, 0, 0, 22)
saveKeyBtn.BackgroundColor3 = themes[currentTheme].cardBg
saveKeyBtn.TextColor3 = themes[currentTheme].accent
saveKeyBtn.Font = Enum.Font.GothamBold
saveKeyBtn.TextSize = 11
saveKeyBtn.Parent = configPage

local skCorner = Instance.new("UICorner")
skCorner.CornerRadius = UDim.new(0, 5)
skCorner.Parent = saveKeyBtn

saveKeyBtn.MouseButton1Click:Connect(function()
	waitingForKeyType = "save"
	saveKeyBtn.Text = t("pressKey")
end)

local toggleKeyLbl = createRowLabel("", 54)
local toggleKeyBtn = Instance.new("TextButton")
toggleKeyBtn.Size = UDim2.new(1, -12, 0, 26)
toggleKeyBtn.Position = UDim2.new(0, 0, 0, 72)
toggleKeyBtn.BackgroundColor3 = themes[currentTheme].cardBg
toggleKeyBtn.TextColor3 = themes[currentTheme].accent
toggleKeyBtn.Font = Enum.Font.GothamBold
toggleKeyBtn.TextSize = 11
toggleKeyBtn.Parent = configPage

local tkCorner = Instance.new("UICorner")
tkCorner.CornerRadius = UDim.new(0, 5)
tkCorner.Parent = toggleKeyBtn

toggleKeyBtn.MouseButton1Click:Connect(function()
	waitingForKeyType = "toggle"
	toggleKeyBtn.Text = t("pressKey")
end)

local langLbl = createRowLabel("", 104)
local langBtn = Instance.new("TextButton")
langBtn.Size = UDim2.new(1, -12, 0, 26)
langBtn.Position = UDim2.new(0, 0, 0, 122)
langBtn.BackgroundColor3 = themes[currentTheme].cardBg
langBtn.TextColor3 = themes[currentTheme].text
langBtn.Font = Enum.Font.GothamMedium
langBtn.TextSize = 11
langBtn.Parent = configPage

local lgCorner = Instance.new("UICorner")
lgCorner.CornerRadius = UDim.new(0, 5)
lgCorner.Parent = langBtn

langBtn.MouseButton1Click:Connect(function()
	currentLang = (currentLang == "EN") and "RU" or "EN"
	saveToFile()
	refreshUI()
end)

local themeLbl = createRowLabel("", 154)
local themeBtn = Instance.new("TextButton")
themeBtn.Size = UDim2.new(1, -12, 0, 26)
themeBtn.Position = UDim2.new(0, 0, 0, 172)
themeBtn.BackgroundColor3 = themes[currentTheme].cardBg
themeBtn.TextColor3 = themes[currentTheme].text
themeBtn.Font = Enum.Font.GothamMedium
themeBtn.TextSize = 11
themeBtn.Parent = configPage

local tmCorner = Instance.new("UICorner")
tmCorner.CornerRadius = UDim.new(0, 5)
tmCorner.Parent = themeBtn

local themeList = {"Obsidian", "Midnight", "Cyber", "OLED"}
themeBtn.MouseButton1Click:Connect(function()
	local idx = 1
	for i, name in ipairs(themeList) do
		if name == currentTheme then
			idx = (i % #themeList) + 1
			break
		end
	end
	currentTheme = themeList[idx]
	saveToFile()
	refreshUI()
end)

local hideUiBtn = Instance.new("TextButton")
hideUiBtn.Size = UDim2.new(1, -12, 0, 26)
hideUiBtn.Position = UDim2.new(0, 0, 0, 208)
hideUiBtn.BackgroundColor3 = themes[currentTheme].cardBg
hideUiBtn.TextColor3 = themes[currentTheme].text
hideUiBtn.Font = Enum.Font.GothamMedium
hideUiBtn.TextSize = 11
hideUiBtn.Parent = configPage

local huCorner = Instance.new("UICorner")
huCorner.CornerRadius = UDim.new(0, 5)
huCorner.Parent = hideUiBtn

hideUiBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

local clearAllBtn = Instance.new("TextButton")
clearAllBtn.Size = UDim2.new(1, -12, 0, 26)
clearAllBtn.Position = UDim2.new(0, 0, 0, 240)
clearAllBtn.BackgroundColor3 = Color3.fromRGB(170, 60, 60)
clearAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearAllBtn.Font = Enum.Font.GothamBold
clearAllBtn.TextSize = 11
clearAllBtn.Parent = configPage

local caCorner = Instance.new("UICorner")
caCorner.CornerRadius = UDim.new(0, 5)
caCorner.Parent = clearAllBtn

clearAllBtn.MouseButton1Click:Connect(function()
	savedPoints = {}
	saveToFile()
	updateVisuals()
	refreshUI()
end)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(1, -12, 0, 26)
unloadBtn.Position = UDim2.new(0, 0, 0, 272)
unloadBtn.BackgroundColor3 = Color3.fromRGB(130, 35, 35)
unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 11
unloadBtn.Parent = configPage

local unCorner = Instance.new("UICorner")
unCorner.CornerRadius = UDim.new(0, 5)
unCorner.Parent = unloadBtn

createRowLabel("GitHub", 308)
local ghBox = Instance.new("TextBox")
ghBox.Size = UDim2.new(1, -12, 0, 24)
ghBox.Position = UDim2.new(0, 0, 0, 326)
ghBox.BackgroundColor3 = themes[currentTheme].cardBg
ghBox.TextColor3 = themes[currentTheme].accent
ghBox.Text = GITHUB_LINK
ghBox.Font = Enum.Font.Gotham
ghBox.TextSize = 10
ghBox.ClearTextOnFocus = false
ghBox.Parent = configPage

local ghCorner = Instance.new("UICorner")
ghCorner.CornerRadius = UDim.new(0, 5)
ghCorner.Parent = ghBox

ghBox.Focused:Connect(function()
	if type(setclipboard) == "function" then
		pcall(setclipboard, GITHUB_LINK)
		ghBox.Text = t("copied")
		task.wait(1.5)
		ghBox.Text = GITHUB_LINK
	end
end)

local creditsLabel = Instance.new("TextLabel")
creditsLabel.Size = UDim2.new(1, -12, 0, 18)
creditsLabel.Position = UDim2.new(0, 0, 0, 362)
creditsLabel.BackgroundTransparency = 1
creditsLabel.Text = "made by KIKGOLIB"
creditsLabel.TextColor3 = themes[currentTheme].subText
creditsLabel.Font = Enum.Font.GothamMedium
creditsLabel.TextSize = 9
creditsLabel.TextTransparency = 0.4
creditsLabel.TextXAlignment = Enum.TextXAlignment.Center
creditsLabel.Parent = configPage

refreshUI = function()
	local activeTheme = themes[currentTheme]

	mainFrame.BackgroundColor3 = activeTheme.mainBg
	mainStroke.Color = activeTheme.border

	toggleBtn.BackgroundColor3 = activeTheme.topBg
	toggleBtn.TextColor3 = activeTheme.accent
	toggleStroke.Color = activeTheme.border

	headerFrame.BackgroundColor3 = activeTheme.topBg
	headerFix.BackgroundColor3 = activeTheme.topBg
	titleLabel.TextColor3 = activeTheme.text
	accentLine.BackgroundColor3 = activeTheme.accent

	navFrame.BackgroundColor3 = activeTheme.topBg
	navDivider.BackgroundColor3 = activeTheme.border

	if pointsPage.Visible then
		pointsTabBtn.BackgroundColor3 = activeTheme.cardBg
		pointsTabBtn.TextColor3 = activeTheme.text
		configTabBtn.TextColor3 = activeTheme.subText
	else
		configTabBtn.BackgroundColor3 = activeTheme.cardBg
		configTabBtn.TextColor3 = activeTheme.text
		pointsTabBtn.TextColor3 = activeTheme.subText
	end

	pointsTabBtn.Text = t("pointsTab")
	configTabBtn.Text = t("configTab")

	saveKeyLbl.Text = t("saveKeyLbl")
	saveKeyLbl.TextColor3 = activeTheme.subText
	saveKeyBtn.Text = "[" .. saveKey.Name .. "]"
	saveKeyBtn.BackgroundColor3 = activeTheme.cardBg
	saveKeyBtn.TextColor3 = activeTheme.accent

	toggleKeyLbl.Text = t("toggleKeyLbl")
	toggleKeyLbl.TextColor3 = activeTheme.subText
	toggleKeyBtn.Text = "[" .. toggleUIKey.Name .. "]"
	toggleKeyBtn.BackgroundColor3 = activeTheme.cardBg
	toggleKeyBtn.TextColor3 = activeTheme.accent

	langLbl.Text = t("langLbl")
	langLbl.TextColor3 = activeTheme.subText
	langBtn.Text = (currentLang == "EN") and "English" or "Русский"
	langBtn.BackgroundColor3 = activeTheme.cardBg
	langBtn.TextColor3 = activeTheme.text

	themeLbl.Text = t("themeLbl")
	themeLbl.TextColor3 = activeTheme.subText
	themeBtn.Text = currentTheme
	themeBtn.BackgroundColor3 = activeTheme.cardBg
	themeBtn.TextColor3 = activeTheme.text

	hideUiBtn.Text = t("hideUi")
	hideUiBtn.BackgroundColor3 = activeTheme.cardBg
	hideUiBtn.TextColor3 = activeTheme.text

	clearAllBtn.Text = t("clearAll")
	unloadBtn.Text = t("unload")

	ghBox.BackgroundColor3 = activeTheme.cardBg
	ghBox.TextColor3 = activeTheme.accent
	creditsLabel.TextColor3 = activeTheme.subText

	scrollFrame.ScrollBarImageColor3 = activeTheme.accent
	configPage.ScrollBarImageColor3 = activeTheme.accent

	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for index, point in ipairs(savedPoints) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -4, 0, 120)
		card.BackgroundColor3 = activeTheme.cardBg
		card.BorderSizePixel = 0
		card.Parent = scrollFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 6)
		cardCorner.Parent = card

		local nameBox = Instance.new("TextBox")
		nameBox.Size = UDim2.new(0.62, -4, 0, 22)
		nameBox.Position = UDim2.new(0, 5, 0, 5)
		nameBox.BackgroundColor3 = activeTheme.mainBg
		nameBox.Text = point.name
		nameBox.TextColor3 = activeTheme.text
		nameBox.Font = Enum.Font.GothamMedium
		nameBox.TextSize = 11
		nameBox.Parent = card

		local nameCorner = Instance.new("UICorner")
		nameCorner.CornerRadius = UDim.new(0, 4)
		nameCorner.Parent = nameBox

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
		delBtn.Size = UDim2.new(0.38, -11, 0, 22)
		delBtn.Position = UDim2.new(0.62, 6, 0, 5)
		delBtn.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
		delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		delBtn.Text = t("delete")
		delBtn.Font = Enum.Font.GothamBold
		delBtn.TextSize = 10
		delBtn.Parent = card

		local delCorner = Instance.new("UICorner")
		delCorner.CornerRadius = UDim.new(0, 4)
		delCorner.Parent = delBtn

		delBtn.MouseButton1Click:Connect(function()
			table.remove(savedPoints, index)
			saveToFile()
			updateVisuals()
			refreshUI()
		end)

		local shapeBtn = Instance.new("TextButton")
		shapeBtn.Size = UDim2.new(0.48, -4, 0, 22)
		shapeBtn.Position = UDim2.new(0, 5, 0, 32)
		shapeBtn.BackgroundColor3 = activeTheme.mainBg
		shapeBtn.TextColor3 = activeTheme.subText
		shapeBtn.Text = getShapeName(point.shape or "Square")
		shapeBtn.Font = Enum.Font.Gotham
		shapeBtn.TextSize = 10
		shapeBtn.Parent = card

		local shapeCorner = Instance.new("UICorner")
		shapeCorner.CornerRadius = UDim.new(0, 4)
		shapeCorner.Parent = shapeBtn

		shapeBtn.MouseButton1Click:Connect(function()
			local currentShape = point.shape or "Square"
			local nextIdx = 1
			for i, s in ipairs(shapeOrder) do
				if s == currentShape then
					nextIdx = (i % #shapeOrder) + 1
					break
				end
			end
			point.shape = shapeOrder[nextIdx]
			saveToFile()
			updateVisuals()
			refreshUI()
		end)

		local colorBtn = Instance.new("TextButton")
		colorBtn.Size = UDim2.new(0.52, -11, 0, 22)
		colorBtn.Position = UDim2.new(0.48, 6, 0, 32)
		colorBtn.BackgroundColor3 = point.color
		colorBtn.Text = t("color")
		colorBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		colorBtn.Font = Enum.Font.GothamBold
		colorBtn.TextSize = 10
		colorBtn.Parent = card

		local colorCorner = Instance.new("UICorner")
		colorCorner.CornerRadius = UDim.new(0, 4)
		colorCorner.Parent = colorBtn

		local colors = {Color3.fromRGB(255, 200, 0), Color3.fromRGB(0, 255, 150), Color3.fromRGB(255, 50, 50), Color3.fromRGB(50, 150, 255), Color3.fromRGB(200, 50, 255)}
		colorBtn.MouseButton1Click:Connect(function()
			local colorIdx = 1
			for i, c in ipairs(colors) do
				if c == point.color then
					colorIdx = (i % #colors) + 1
					break
				end
			end
			point.color = colors[colorIdx]
			saveToFile()
			updateVisuals()
			refreshUI()
		end)

		local imgBox = Instance.new("TextBox")
		imgBox.Size = UDim2.new(1, -10, 0, 22)
		imgBox.Position = UDim2.new(0, 5, 0, 59)
		imgBox.BackgroundColor3 = activeTheme.mainBg
		imgBox.Text = (point.imageId and point.imageId ~= "") and point.imageId or t("imgPlaceholder")
		imgBox.TextColor3 = (point.imageId and point.imageId ~= "") and activeTheme.accent or activeTheme.subText
		imgBox.Font = Enum.Font.Gotham
		imgBox.TextSize = 10
		imgBox.ClearTextOnFocus = false
		imgBox.Parent = card

		local imgCorner = Instance.new("UICorner")
		imgCorner.CornerRadius = UDim.new(0, 4)
		imgCorner.Parent = imgBox

		imgBox.FocusLost:Connect(function()
			point.imageId = imgBox.Text
			saveToFile()
			updateVisuals()
		end)

		local hitboxLabel = Instance.new("TextLabel")
		hitboxLabel.Size = UDim2.new(0.5, -5, 0, 22)
		hitboxLabel.Position = UDim2.new(0, 5, 0, 86)
		hitboxLabel.BackgroundTransparency = 1
		hitboxLabel.Text = t("hitboxLbl")
		hitboxLabel.TextColor3 = activeTheme.subText
		hitboxLabel.Font = Enum.Font.GothamMedium
		hitboxLabel.TextSize = 10
		hitboxLabel.TextXAlignment = Enum.TextXAlignment.Left
		hitboxLabel.Parent = card

		local hitboxBox = Instance.new("TextBox")
		hitboxBox.Size = UDim2.new(0.5, -6, 0, 22)
		hitboxBox.Position = UDim2.new(0.5, 1, 0, 86)
		hitboxBox.BackgroundColor3 = activeTheme.mainBg
		hitboxBox.Text = tostring(point.hitbox or DEFAULT_ACTIVATION_RADIUS)
		hitboxBox.TextColor3 = activeTheme.accent
		hitboxBox.Font = Enum.Font.GothamBold
		hitboxBox.TextSize = 10
		hitboxBox.Parent = card

		local hbCorner = Instance.new("UICorner")
		hbCorner.CornerRadius = UDim.new(0, 4)
		hbCorner.Parent = hitboxBox

		hitboxBox.FocusLost:Connect(function()
			local num = tonumber(hitboxBox.Text)
			if num and num > 0 then
				point.hitbox = num
				saveToFile()
			else
				hitboxBox.Text = tostring(point.hitbox or DEFAULT_ACTIVATION_RADIUS)
			end
		end)
	end
end

local function unloadScript()
	if renderConnection then renderConnection:Disconnect() end
	if inputConnection then inputConnection:Disconnect() end
	clearVisuals()
	if screenGui then screenGui:Destroy() end
end

unloadBtn.MouseButton1Click:Connect(unloadScript)

local function saveCurrentLocation()
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	pointCounter = pointCounter + 1
	local pointData = {
		name = (currentLang == "EN" and "Point " or "Точка ") .. pointCounter,
		position = character.HumanoidRootPart.Position,
		cameraCFrame = camera.CFrame,
		color = Color3.fromRGB(255, 200, 0),
		showESP = true,
		showHighlight = true,
		shape = "Square",
		imageId = "",
		hitbox = DEFAULT_ACTIVATION_RADIUS
	}

	table.insert(savedPoints, pointData)
	saveToFile()
	updateVisuals()
	refreshUI()
end

loadFromFile()
updateVisuals()
refreshUI()

renderConnection = RunService.RenderStepped:Connect(function()
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local currentPos = character.HumanoidRootPart.Position

	for _, point in ipairs(savedPoints) do
		local distance = (currentPos - point.position).Magnitude
		local radius = point.hitbox or DEFAULT_ACTIVATION_RADIUS

		if distance <= radius then
			local targetRotation = CFrame.new(camera.CFrame.Position) * point.cameraCFrame.Rotation
			camera.CFrame = camera.CFrame:Lerp(targetRotation, TURN_SPEED)
		end
	end
end)

inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if waitingForKeyType and input.UserInputType == Enum.UserInputType.Keyboard then
		if waitingForKeyType == "save" then
			saveKey = input.KeyCode
			saveKeyBtn.Text = "[" .. saveKey.Name .. "]"
		elseif waitingForKeyType == "toggle" then
			toggleUIKey = input.KeyCode
			toggleUIKeyBtn.Text = "[" .. toggleUIKey.Name .. "]"
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

```
