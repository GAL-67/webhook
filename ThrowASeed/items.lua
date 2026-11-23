local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local ConfigFile = "Intelius_WebhookConfig.txt"
local HistoryFile = "Intelius_SentItems.json"

-- Hentikan loop lama jika script di-execute ulang
if getgenv().InteliusWebhookLoopId then
	getgenv().InteliusWebhookLoopId += 1
else
	getgenv().InteliusWebhookLoopId = 1
end
local currentLoopId = getgenv().InteliusWebhookLoopId

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

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

-- Simulasi klik ImageButton untuk Delta Executor
local function clickButton(btn)
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

-- Load & Save riwayat item untuk mendeteksi [NEW]
local function loadSentHistory()
	if isfile and readfile and isfile(HistoryFile) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(HistoryFile))
		end)
		if ok and type(data) == "table" then
			return data
		end
	end
	return {}
end

local function saveSentHistory(historyTable)
	if writefile then
		pcall(function()
			writefile(HistoryFile, HttpService:JSONEncode(historyTable))
		end)
	end
end

local function collectAndSend(webhookUrl)
	local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then return end

	-- 1. Activate / Klik ImageButton HudDroite.Panneau.Items
	local hudDroite = playerGui:FindFirstChild("HudDroite")
	local panneau = hudDroite and hudDroite:FindFirstChild("Panneau")
	local itemsBtn = panneau and panneau:FindFirstChild("Items")

	if itemsBtn then
		clickButton(itemsBtn)
	else
		warn("[Webhook Sender] Button HudDroite.Panneau.Items tidak ditemukan!")
	end

	-- 2. Tunggu sampai Liste muncul dan terisi data
	local menuItems = playerGui:WaitForChild("MenuItems", 5)
	local fenetre = menuItems and menuItems:WaitForChild("Fenetre", 5)
	local corps = fenetre and fenetre:WaitForChild("Corps", 5)
	local liste = corps and corps:WaitForChild("Liste", 5)

	if not liste then
		warn("[Webhook Sender] Path MenuItems.Fenetre.Corps.Liste tidak ditemukan!")
		return
	end

	local attempts = 0
	while attempts < 20 do
		local hasLigne = false
		for _, child in ipairs(liste:GetChildren()) do
			if child.Name:match("^Ligne_") then
				local nom = child:FindFirstChild("Nom")
				if nom and nom.Text ~= "" then
					hasLigne = true
					break
				end
			end
		end
		if hasLigne then break end
		attempts += 1
		task.wait(0.15)
	end

	-- 3. Ambil & filter data (hanya >= 1T/s)
	local validItems = {}

	for _, child in ipairs(liste:GetChildren()) do
		if child.Name:match("^Ligne_") then
			local nomObj = child:FindFirstChild("Nom")
			local revenuObj = child:FindFirstChild("Revenu")
			local tailleObj = child:FindFirstChild("Taille")

			if nomObj and revenuObj and tailleObj then
				local nameText = nomObj.Text
				local incomeText = revenuObj.Text
				local sizeText = tailleObj.Text

				if nameText ~= "" and incomeText ~= "" then
					local numericValue = parseIncome(incomeText)
					if numericValue >= 1e12 then
						local formattedLine = string.format("[%s] %s (%s)", sizeText, nameText, incomeText)
						table.insert(validItems, {
							name = nameText,
							incomeRaw = incomeText,
							size = sizeText,
							value = numericValue,
							formatted = formattedLine
						})
					end
				end
			end
		end
	end

	if #validItems == 0 then
		warn("[Webhook Sender] Tidak ada item >= 1T/s yang ditemukan.")
		return
	end

	-- Sort High to Low
	table.sort(validItems, function(a, b)
		return a.value > b.value
	end)

	-- 4. Cek item [NEW] menggunakan multiset count dari history sebelumnya
	local previousCounts = loadSentHistory()
	local currentCounts = {}
	local newItems = {}

	for _, item in ipairs(validItems) do
		local key = item.formatted
		currentCounts[key] = (currentCounts[key] or 0) + 1
		
		local prevCount = previousCounts[key] or 0
		if currentCounts[key] > prevCount then
			table.insert(newItems, item.formatted)
		end
	end

	saveSentHistory(currentCounts)

	-- 5. Grouping kelipatan 1T/s+
	local groups = {}
	local groupOrder = {}

	for _, item in ipairs(validItems) do
		local tier = math.floor(item.value / 1e12)
		if not groups[tier] then
			groups[tier] = {}
			table.insert(groupOrder, tier)
		end
		table.insert(groups[tier], item.formatted)
	end

	table.sort(groupOrder, function(a, b)
		return a > b
	end)

	-- 6. Susun format pesan akhir
	local outputLines = {}

	if #newItems > 0 then
		table.insert(outputLines, "[NEW]")
		for _, line in ipairs(newItems) do
			table.insert(outputLines, line)
		end
		table.insert(outputLines, "")
	end

	for _, tier in ipairs(groupOrder) do
		table.insert(outputLines, tostring(tier) .. "T/s+")
		for _, line in ipairs(groups[tier]) do
			table.insert(outputLines, line)
		end
		table.insert(outputLines, "")
	end

	local finalMessage = table.concat(outputLines, "\n"):gsub("%s+$", "")

	if #finalMessage > 4000 then
		finalMessage = finalMessage:sub(1, 3990) .. "\n...(truncated)"
	end

	local timeTag = os.date("%H:%M")
	local payload = HttpService:JSONEncode({
		username = "Tree Inventory Logger",
		embeds = {{
			title = "Inventory List (" .. LocalPlayer.Name .. ") • " .. timeTag,
			description = "```text\n" .. finalMessage .. "\n```",
			color = 14423100,
			footer = {
				text = "Total 1T/s+ Items: " .. tostring(#validItems) .. " | New: " .. tostring(#newItems)
			},
			timestamp = DateTime.now():ToIsoDate()
		}}
	})

	if httpRequest then
		local response = httpRequest({
			Url = webhookUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = payload
		})
		if response and (response.StatusCode == 200 or response.StatusCode == 204) then
			print(string.format("[Webhook Sender] [%s] Berhasil dikirim! Total: %d | New: %d", timeTag, #validItems, #newItems))
		else
			warn("[Webhook Sender] Gagal mengirim webhook. Status:", response and response.StatusCode)
		end
	else
		warn("[Webhook Sender] Executor tidak mendukung HTTP Request.")
	end
end

-- Hitung detik tepat menuju menit kelipatan 5 berikutnya (xx:x0 atau xx:x5)
local function getSecondsUntilNext5Min()
	local now = os.date("*t")
	local remMinutes = 5 - (now.min % 5)
	local waitSeconds = (remMinutes * 60) - now.sec
	if waitSeconds <= 0 then
		waitSeconds += 300
	end
	return waitSeconds
end

-- Jalankan pengiriman pertama + loop terjadwal tiap xx:x0 / xx:x5
local function startScheduledLoop(webhookUrl)
	task.spawn(function()
		-- Kirim langsung saat pertama dijalankan
		pcall(collectAndSend, webhookUrl)

		while getgenv().InteliusWebhookLoopId == currentLoopId do
			local waitSec = getSecondsUntilNext5Min()
			local nextTime = os.date("%H:%M:%S", os.time() + waitSec)
			print(string.format("[Webhook Sender] Jadwal berikutnya pada %s (menunggu %d detik)...", nextTime, waitSec))

			-- Sleep bertahap agar responsif jika loop dihentikan
			local targetTick = os.time() + waitSec
			while os.time() < targetTick do
				if getgenv().InteliusWebhookLoopId ~= currentLoopId then
					return
				end
				task.wait(0.5)
			end

			if getgenv().InteliusWebhookLoopId == currentLoopId then
				pcall(collectAndSend, webhookUrl)
				task.wait(2) -- Cooldown singkat agar tidak ter-trigger dua kali di detik yang sama
			end
		end
	end)
end

-- Mini UI Setup (hanya tampil jika webhook belum disimpan)
local function createSetupUI()
	local parentGui = (gethui and gethui()) or CoreGui
	local oldGui = parentGui:FindFirstChild("MiniWebhookSetup")
	if oldGui then oldGui:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MiniWebhookSetup"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = parentGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 320, 0, 130)
	mainFrame.Position = UDim2.new(0.5, -160, 0.5, -65)
	mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = mainFrame

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(220, 38, 38)
	uiStroke.Thickness = 1.5
	uiStroke.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = "DISCORD WEBHOOK SETUP"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = mainFrame

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -20, 0, 36)
	textBox.Position = UDim2.new(0, 10, 0, 40)
	textBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	textBox.TextColor3 = Color3.fromRGB(240, 240, 240)
	textBox.PlaceholderText = "Paste Discord Webhook URL here..."
	textBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
	textBox.Text = ""
	textBox.Font = Enum.Font.Gotham
	textBox.TextSize = 12
	textBox.ClearTextOnFocus = false
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.Parent = mainFrame

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = textBox

	local boxPadding = Instance.new("UIPadding")
	boxPadding.PaddingLeft = UDim.new(0, 8)
	boxPadding.PaddingRight = UDim.new(0, 8)
	boxPadding.Parent = textBox

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(1, -20, 0, 34)
	saveBtn.Position = UDim2.new(0, 10, 0, 84)
	saveBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	saveBtn.Text = "SAVE & SEND"
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextSize = 12
	saveBtn.Parent = mainFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = saveBtn

	saveBtn.MouseButton1Click:Connect(function()
		local url = textBox.Text:gsub("%s+", "")
		if url:match("^https://discord%.com/api/webhooks/") or url:match("^https://discordapp%.com/api/webhooks/") then
			if writefile then
				writefile(ConfigFile, url)
			end
			screenGui:Destroy()
			startScheduledLoop(url)
		else
			saveBtn.Text = "INVALID WEBHOOK URL!"
			saveBtn.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
			task.wait(1.5)
			saveBtn.Text = "SAVE & SEND"
			saveBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
		end
	end)
end

-- Entry Point
local savedUrl = nil
if isfile and readfile and isfile(ConfigFile) then
	local content = readfile(ConfigFile):gsub("%s+", "")
	if content ~= "" and content:match("^https://") then
		savedUrl = content
	end
end

if savedUrl then
	startScheduledLoop(savedUrl)
else
	createSetupUI()
end
