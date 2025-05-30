-- src/client/controllers/UIController.lua
-- Простой контроллер для тестирования UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseController = require(ReplicatedStorage.Shared.BaseController)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local UIController = setmetatable({}, { __index = BaseController })
UIController.__index = UIController

function UIController.new()
	local self = setmetatable(BaseController.new("UIController"), UIController)

	self.LocalPlayer = Players.LocalPlayer
	self.PlayerGui = self.LocalPlayer:WaitForChild("PlayerGui")

	-- UI элементы
	self.MainHUD = nil

	return self
end

function UIController:OnInitialize()
	print("[UI CONTROLLER] Initializing UI...")
	self:CreateMainHUD()
end

function UIController:OnStart()
	print("[UI CONTROLLER] UI Ready!")
end

-- Создать основной HUD
function UIController:CreateMainHUD()
	-- Создаем основной ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.Parent = self.PlayerGui

	-- Фрейм для статистик
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0, 200, 0, 100)
	statsFrame.Position = UDim2.new(0, 10, 0, 10)
	statsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	statsFrame.BackgroundTransparency = 0.5
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = screenGui

	-- Заголовок
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Text = "Player Stats"
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Constants.UI.FONTS.BOLD
	titleLabel.Parent = statsFrame

	-- Лейбл уровня
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Text = "Level: 1"
	levelLabel.Size = UDim2.new(1, 0, 0, 20)
	levelLabel.Position = UDim2.new(0, 0, 0, 25)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextScaled = true
	levelLabel.Font = Constants.UI.FONTS.MAIN
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = statsFrame

	-- Лейбл золота
	local goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Text = "Gold: 100"
	goldLabel.Size = UDim2.new(1, 0, 0, 20)
	goldLabel.Position = UDim2.new(0, 0, 0, 50)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLabel.TextScaled = true
	goldLabel.Font = Constants.UI.FONTS.MAIN
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Parent = statsFrame

	-- Лейбл здоровья
	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthLabel"
	healthLabel.Text = "Health: 100/100"
	healthLabel.Size = UDim2.new(1, 0, 0, 20)
	healthLabel.Position = UDim2.new(0, 0, 0, 75)
	healthLabel.BackgroundTransparency = 1
	healthLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
	healthLabel.TextScaled = true
	healthLabel.Font = Constants.UI.FONTS.MAIN
	healthLabel.TextXAlignment = Enum.TextXAlignment.Left
	healthLabel.Parent = statsFrame

	self.MainHUD = screenGui

	print("[UI CONTROLLER] Main HUD created!")
end

-- Обновить статистики на UI
function UIController:UpdateStats(data)
	if self.MainHUD == nil then
		print("[UI CONTROLLER] MainHUD is nil!")
		return
	end

	local statsFrame = self.MainHUD:FindFirstChild("StatsFrame")
	if statsFrame == nil then
		print("[UI CONTROLLER] StatsFrame not found!")
		return
	end

	-- Обновляем уровень
	local levelLabel = statsFrame:FindFirstChild("LevelLabel")
	if levelLabel then
		levelLabel.Text = "Level: " .. (data.Level or 1)
		print("[UI CONTROLLER] Updated level: " .. (data.Level or 1))
	end

	-- Обновляем золото
	local goldLabel = statsFrame:FindFirstChild("GoldLabel")
	if goldLabel and data.Currency then
		goldLabel.Text = "Gold: " .. (data.Currency.Gold or 0)
		print("[UI CONTROLLER] Updated gold: " .. (data.Currency.Gold or 0))
	end

	-- Обновляем здоровье
	local healthLabel = statsFrame:FindFirstChild("HealthLabel")
	if healthLabel then
		local health = data.Health or 100
		local maxHealth = data.MaxHealth or 100
		healthLabel.Text = "Health: " .. health .. "/" .. maxHealth
		print("[UI CONTROLLER] Updated health: " .. health .. "/" .. maxHealth)
	end

	print("[UI CONTROLLER] Stats update completed!")
end

function UIController:OnCleanup()
	if self.MainHUD then
		self.MainHUD:Destroy()
		self.MainHUD = nil
	end
end

return UIController
