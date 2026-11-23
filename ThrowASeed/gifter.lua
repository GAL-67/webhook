local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local RequestRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request")

local TARGET_USER_ID = 11611120336

-- Hapus UI lama jika di-execute ulang
local parentGui = (gethui and gethui()) or CoreGui
local oldGui = parentGui:FindFirstChild("InteliusAutoGifter1T")
if oldGui then oldGui:Destroy() end

local isRunning = false

-- Parser angka suffix (K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc)
local Multipliers = {
	k = 1e3,
	m = 1e6,
	b = 1e9,
	t = 1e12,
	qa = 1e15,
	qi = 1e18,
	sx = 1e21,
	sp = 1e24,
	oc = 1e27,
	no = 1e30,
	dc = 1e33
}

local function parseIncome(rawText)
	if not rawText or rawText == "" then return 0 end
	local cleaned = rawText:gsub(",", ""):gsub("%$", ""):gsub("/s", ""):gsub("%s+", "")
	local numStr, suffix = cleaned:match("^([%d%.]+)([a-zA-Z]*)$")
	local num = tonumber(numStr) or 0
	
	if suffix and suffix ~= "" then
		local mult = Multipliers[suffix:lower()]
		if mult then
			return num * mult
		end
	end
	return num
end

-- Simulasi klik tombol UI (ImageButton / GuiButton) di Delta Executor
local function clickButton(btn)
	if not btn then return false end

	-- Jika yang diberikan adalah child (seperti Nom/Haut), cari parent tombolnya
	if not btn:IsA("GuiButton") then
		btn = btn:FindFirstAncestorWhichIsA("GuiButton") or btn.Parent
	end
	if not btn then return false end

	local events = {"MouseButton1Click", "Activated", "MouseButton1Down"}
	local fired = false

	for _, eventName in ipairs(events) do
		local signal = btn[eventName]
		if signal then
			if firesignal then
				pcall(function()
					firesignal(signal)
					fired = true
				end)
			elseif getconnections then
				pcall(function()
					for _, conn in ipairs(getconnections(signal)) do
						conn:Fire()
						fired = true
					end
				end)
			end
		end
	end
	return fired
end

-- Cek apakah penerima ada di server yang sama
local function getTargetInServer()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.UserId == TARGET_USER_ID then
			return plr
		end
	end
	return nil
end

-- Buat UI Minimalis On/Off
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InteliusAutoGifter1T"
screenGui.ResetOnSpawn = false
screenGui.Parent = parentGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 145)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -72)
mainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(220, 38, 38)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 0, 32)
titleLabel.Position = UDim2.new(0, 12, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AUTO GIFT 1T/s+"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(220, 38, 38)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local targetInfo = Instance.new("TextLabel")
targetInfo.Size = UDim2.new(1, -24, 0, 20)
targetInfo.Position = UDim2.new(0, 12, 0, 38)
targetInfo.BackgroundTransparency = 1
targetInfo.Text = "Target ID: " .. tostring(TARGET_USER_ID)
targetInfo.TextColor3 = Color3.fromRGB(160, 160, 170)
targetInfo.Font = Enum.Font.Gotham
targetInfo.TextSize = 11
targetInfo.TextXAlignment = Enum.TextXAlignment.Left
targetInfo.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 24)
statusLabel.Position = UDim2.new(0, 12, 0, 60)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: OFF"
statusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -24, 0, 38)
toggleBtn.Position = UDim2.new(0, 12, 0, 92)
toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Text = "AUTO GIFT: OFF"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.Parent = mainFrame
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local function setStatus(text, color)
	statusLabel.Text = "Status: " .. text
	statusLabel.TextColor3 = color or Color3.fromRGB(220, 220, 230)
end

-- Buka Inventory button di HUD & Tab OngletPlantes
local function openPlantInventory()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end

	-- 1. Cari slot Plante_ di Inventaire.Barre yang .Nom.Text == "Inventory"
	local inventaire = playerGui:FindFirstChild("Inventaire")
	local barre = inventaire and inventaire:FindFirstChild("Barre")
	local invButton = nil

	if barre then
		for _, child in ipairs(barre:GetChildren()) do
			if child.Name:match("^Plante_") then
				local nomLabel = child:FindFirstChild("Nom")
				if nomLabel and nomLabel.Text:lower():gsub("%s+", "") == "inventory" then
					invButton = child
					break
				end
			end
		end
	end

	-- Cek apakah MenuInventory sudah terbuka atau perlu dibuka via invButton
	local menuInv = playerGui:FindFirstChild("MenuInventory")
	local fenetre = menuInv and menuInv:FindFirstChild("Fenetre")

	if invButton then
		if not fenetre or not fenetre.Visible then
			clickButton(invButton)
			task.wait(0.35)
		end
	end

	-- 2. Activate Plant section imgbutton (OngletPlantes)
	menuInv = playerGui:FindFirstChild("MenuInventory")
	fenetre = menuInv and menuInv:FindFirstChild("Fenetre")
	local entete = fenetre and fenetre:FindFirstChild("Entete")
	local ongletPlantes = entete and entete:FindFirstChild("OngletPlantes")

	if ongletPlantes then
		clickButton(ongletPlantes)
		task.wait(0.35)
	end

	return true
end

-- Kumpulkan semua tanaman >= 1T/s dari HUD (Inventaire) dan MenuInventory
local function scanHighIncomePlants()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return {} end

	local candidates = {}

	-- A. Scan HUD Barre (Plante_1, Plante_2, dst.)
	local inventaire = playerGui:FindFirstChild("Inventaire")
	local barre = inventaire and inventaire:FindFirstChild("Barre")
	if barre then
		for _, slot in ipairs(barre:GetChildren()) do
			if slot.Name:match("^Plante_") then
				local nomLabel = slot:FindFirstChild("Nom")
				local hautLabel = slot:FindFirstChild("Haut")

				-- Skip tombol "Inventory"
				local isInvBtn = nomLabel and nomLabel.Text:lower():gsub("%s+", "") == "inventory"
				if not isInvBtn and hautLabel and hautLabel.Text ~= "" then
					local val = parseIncome(hautLabel.Text)
					if val >= 1e12 then
						table.insert(candidates, {
							source = "HUD",
							button = slot,
							incomeRaw = hautLabel.Text,
							value = val
						})
					end
				end
			end
		end
	end

	-- B. Scan MenuInventory Liste (Plante_1, Plante_2, dst.)
	local menuInv = playerGui:FindFirstChild("MenuInventory")
	local fenetre = menuInv and menuInv:FindFirstChild("Fenetre")
	local corps = fenetre and fenetre:FindFirstChild("Corps")
	local liste = corps and corps:FindFirstChild("Liste")

	if liste then
		for _, slot in ipairs(liste:GetChildren()) do
			if slot.Name:match("^Plante_") then
				local etiquette = slot:FindFirstChild("Etiquette")
				if etiquette and etiquette.Text ~= "" then
					local val = parseIncome(etiquette.Text)
					if val >= 1e12 then
						table.insert(candidates, {
							source = "MENU",
							button = slot,
							incomeRaw = etiquette.Text,
							value = val
						})
					end
				end
			end
		end
	end

	-- Sortir dari income terbesar ke terkecil (High to Low)
	table.sort(candidates, function(a, b)
		return a.value > b.value
	end)

	return candidates
end

-- Proses 1 siklus equip -> gift -> tunggu diterima
local function processSingleGift(plantData, targetPlayer)
	if not plantData.button or not plantData.button.Parent then
		return false
	end

	setStatus("Equipping " .. plantData.incomeRaw .. " (" .. plantData.source .. ")", Color3.fromRGB(250, 204, 21))

	-- Jika berasal dari MENU, pastikan MenuInventory terbuka
	if plantData.source == "MENU" then
		openPlantInventory()
	end

	-- Klik tombol tanaman untuk memegang item
	clickButton(plantData.button)

	-- Tunggu sampai attribute "Holding" terisi (maksimal 2.5 detik)
	local holdWait = 0
	while not LocalPlayer:GetAttribute("Holding") and holdWait < 25 do
		if not isRunning then return false end
		task.wait(0.1)
		holdWait += 1
	end

	local holdingId = LocalPlayer:GetAttribute("Holding")
	if not holdingId then
		-- Jika gagal equip (misal slot sudah kosong/bergeser), skip ke scan berikutnya
		return false
	end

	setStatus("Gifting " .. plantData.incomeRaw .. " -> " .. targetPlayer.Name, Color3.fromRGB(96, 165, 250))

	-- Kirim request Gift ke target
	local ok, success, msg = pcall(function()
		return RequestRemote:InvokeServer("Gift", {
			to = targetPlayer.UserId
		})
	end)

	if not ok or not success then
		setStatus("Gift gagal: " .. tostring(msg or "Rejected"), Color3.fromRGB(248, 113, 113))
		task.wait(1.5)
		return false
	end

	-- Tunggu sampai penerima menerima gift (attribute Holding berubah / menjadi nil)
	setStatus("Waiting accept (" .. plantData.incomeRaw .. ")...", Color3.fromRGB(192, 132, 252))
	local acceptTimeout = 0
	while isRunning do
		-- Cek jika penerima keluar server di tengah proses
		if not getTargetInServer() then
			setStatus("Target keluar server!", Color3.fromRGB(248, 113, 113))
			return false
		end

		local currentHolding = LocalPlayer:GetAttribute("Holding")
		-- Jika Holding sudah nil atau berbeda dari item sebelumnya, artinya gift sudah diterima
		if currentHolding == nil or currentHolding ~= holdingId then
			setStatus("Accepted! (" .. plantData.incomeRaw .. ")", Color3.fromRGB(74, 222, 128))
			task.wait(0.5)
			return true
		end

		task.wait(0.25)
		acceptTimeout += 0.25

		-- Jika lewat 22 detik (TTL GiftOffer 20s) belum diterima, kirim ulang
		if acceptTimeout >= 22 then
			setStatus("Timeout, mengulang...", Color3.fromRGB(251, 191, 36))
			return false
		end
	end

	return false
end

-- Loop utama Auto-Gifter
local function runAutoGifterLoop()
	task.spawn(function()
		while isRunning and screenGui.Parent do
			local targetPlayer = getTargetInServer()
			if not targetPlayer then
				setStatus("Target (" .. TARGET_USER_ID .. ") tidak di server", Color3.fromRGB(248, 113, 113))
				task.wait(2)
				continue
			end

			if targetPlayer:GetAttribute("SetDeclineGifts") == true then
				setStatus("Target mematikan fitur Gift!", Color3.fromRGB(248, 113, 113))
				task.wait(2)
				continue
			end

			setStatus("Scanning 1T/s+ plants...", Color3.fromRGB(220, 220, 230))
			openPlantInventory()
			task.wait(0.3)

			local highPlants = scanHighIncomePlants()
			if #highPlants == 0 then
				setStatus("Tidak ada tanaman 1T/s+ tersisa", Color3.fromRGB(160, 160, 170))
				task.wait(2.5)
				continue
			end

			-- Ambil tanaman dengan income paling besar (index 1 setelah sort)
			-- Setelah 1 tanaman berhasil diterima, loop mengulang scan agar urutan slot terbaru selalu akurat
			local topPlant = highPlants[1]
			processSingleGift(topPlant, targetPlayer)
			task.wait(0.3)
		end
	end)
end

-- Toggle ON / OFF
toggleBtn.MouseButton1Click:Connect(function()
	isRunning = not isRunning
	if isRunning then
		toggleBtn.Text = "AUTO GIFT: ON"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
		runAutoGifterLoop()
	else
		toggleBtn.Text = "AUTO GIFT: OFF"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
		setStatus("OFF", Color3.fromRGB(220, 220, 230))
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	isRunning = false
	screenGui:Destroy()
end)
