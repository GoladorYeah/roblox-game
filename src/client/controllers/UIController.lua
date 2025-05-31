-- src/client/controllers/UIController.lua
-- Простой контроллер для базового UI (статистика игрока)

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

	-- Дебаунс для предотвращения спама обновлений
	self.LastUpdateTime = 0
	self.UpdateCooldown = 0.1 -- 100мс между обновлениями

	return self
end

function UIController:OnInitialize()
	print("[UI CONTROLLER] Initializing basic UI...")
	self:CreateMainHUD()
end

function UIController:OnStart()
	print("[UI CONTROLLER] Basic UI Ready!")
end

-- Создать основной HUD
function UIController:CreateMainHUD()
	-- Создаем основной ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.Parent = self.PlayerGui

	-- Фрейм для базовых статистик
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0, 200, 0, 80) -- Уменьшаем высоту, убираем health
	statsFrame.Position = UDim2.new(0, 10, 0, 10)
	statsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	statsFrame.BackgroundTransparency = 0.5
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = screenGui

	-- Добавляем скругленные углы
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = statsFrame

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

	self.MainHUD = screenGui

	print("[UI CONTROLLER] Main HUD created successfully!")
end

-- Обновить базовые статистики на UI (БЕЗ health - только уровень и золото)
function UIController:UpdateStats(data)
	-- Проверяем дебаунс
	local currentTime = tick()
	if currentTime - self.LastUpdateTime < self.UpdateCooldown then
		return -- Слишком частые обновления, пропускаем
	end
	self.LastUpdateTime = currentTime

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
	if levelLabel and data.Level then
		levelLabel.Text = "Level: " .. data.Level
		print("[UI CONTROLLER] Updated level: " .. data.Level)
	end

	-- Обновляем золото
	local goldLabel = statsFrame:FindFirstChild("GoldLabel")
	if goldLabel and data.Currency then
		goldLabel.Text = "Gold: " .. (data.Currency.Gold or 0)
		print("[UI CONTROLLER] Updated gold: " .. (data.Currency.Gold or 0))
	end

	print("[UI CONTROLLER] Basic stats update completed!")
end

-- Показать системное уведомление
function UIController:ShowNotification(message, messageType, duration)
	if not self.MainHUD then
		print("[UI CONTROLLER] Cannot show notification - MainHUD not ready")
		return
	end

	messageType = messageType or "INFO"
	duration = duration or 3

	-- Цвета для разных типов сообщений
	local colors = {
		INFO = Color3.fromRGB(100, 150, 255),
		SUCCESS = Color3.fromRGB(100, 255, 100),
		WARNING = Color3.fromRGB(255, 200, 100),
		ERROR = Color3.fromRGB(255, 100, 100),
		CRITICAL = Color3.fromRGB(255, 50, 50),
	}

	-- Создаем уведомление
	local notification = Instance.new("Frame")
	notification.Name = "Notification"
	notification.Size = UDim2.new(0, 300, 0, 60)
	notification.Position = UDim2.new(1, -310, 0, 10)
	notification.BackgroundColor3 = colors[messageType] or colors.INFO
	notification.BackgroundTransparency = 0.1
	notification.BorderSizePixel = 0
	notification.Parent = self.MainHUD

	-- Скругленные углы
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification

	-- Текст сообщения
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, -20, 1, -20)
	messageLabel.Position = UDim2.new(0, 10, 0, 10)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	messageLabel.TextScaled = true
	messageLabel.TextWrapped = true
	messageLabel.Font = Constants.UI.FONTS.MAIN
	messageLabel.TextStrokeTransparency = 0.5
	messageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	messageLabel.Parent = notification

	-- Анимация появления
	local TweenService = game:GetService("TweenService")

	-- Начальная позиция (за экраном)
	notification.Position = UDim2.new(1, 10, 0, 10)

	-- Анимация входа
	local slideIn = TweenService:Create(
		notification,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -310, 0, 10) }
	)
	slideIn:Play()

	-- Автоматическое скрытие
	spawn(function()
		wait(duration)

		-- Анимация выхода
		local slideOut =
			TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 10, 0, 10),
				BackgroundTransparency = 1,
			})

		-- Анимация исчезновения текста
		local fadeText = TweenService:Create(
			messageLabel,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)

		slideOut:Play()
		fadeText:Play()

		slideOut.Completed:Connect(function()
			if notification.Parent then
				notification:Destroy()
			end
		end)
	end)

	print("[UI CONTROLLER] Notification shown: " .. messageType .. " - " .. message)
end

-- Показать информацию о повышении уровня
function UIController:ShowLevelUpEffect(newLevel, attributePoints)
	if not self.MainHUD then
		return
	end

	-- Создаем эффект повышения уровня
	local levelUpFrame = Instance.new("Frame")
	levelUpFrame.Name = "LevelUpEffect"
	levelUpFrame.Size = UDim2.new(0, 400, 0, 150)
	levelUpFrame.Position = UDim2.new(0.5, -200, 0.3, -75)
	levelUpFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	levelUpFrame.BackgroundTransparency = 0.2
	levelUpFrame.BorderSizePixel = 0
	levelUpFrame.Parent = self.MainHUD

	-- Скругленные углы
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = levelUpFrame

	-- Заголовок "LEVEL UP!"
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 50)
	titleLabel.Position = UDim2.new(0, 0, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🎉 LEVEL UP! 🎉"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Constants.UI.FONTS.BOLD
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.Parent = levelUpFrame

	-- Новый уровень
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.Size = UDim2.new(1, 0, 0, 40)
	levelLabel.Position = UDim2.new(0, 0, 0, 60)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level " .. newLevel
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextScaled = true
	levelLabel.Font = Constants.UI.FONTS.MAIN
	levelLabel.TextStrokeTransparency = 0.5
	levelLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	levelLabel.Parent = levelUpFrame

	-- Очки атрибутов
	if attributePoints and attributePoints > 0 then
		local pointsLabel = Instance.new("TextLabel")
		pointsLabel.Name = "Points"
		pointsLabel.Size = UDim2.new(1, 0, 0, 30)
		pointsLabel.Position = UDim2.new(0, 0, 0, 105)
		pointsLabel.BackgroundTransparency = 1
		pointsLabel.Text = "+" .. attributePoints .. " Attribute Points"
		pointsLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
		pointsLabel.TextScaled = true
		pointsLabel.Font = Constants.UI.FONTS.MAIN
		pointsLabel.TextStrokeTransparency = 0.5
		pointsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		pointsLabel.Parent = levelUpFrame
	end

	-- Анимация появления и исчезновения
	local TweenService = game:GetService("TweenService")

	-- Начальные параметры
	levelUpFrame.Size = UDim2.new(0, 0, 0, 0)
	levelUpFrame.Position = UDim2.new(0.5, 0, 0.3, 0)

	-- Анимация появления
	local expandTween =
		TweenService:Create(levelUpFrame, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 400, 0, 150),
			Position = UDim2.new(0.5, -200, 0.3, -75),
		})
	expandTween:Play()

	-- Автоматическое скрытие через 4 секунды
	spawn(function()
		wait(4)

		local fadeTween = TweenService:Create(
			levelUpFrame,
			TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)

		local fadeTitle = TweenService:Create(
			titleLabel,
			TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)

		local fadeLevel = TweenService:Create(
			levelLabel,
			TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)

		fadeTween:Play()
		fadeTitle:Play()
		fadeLevel:Play()

		fadeTween.Completed:Connect(function()
			if levelUpFrame.Parent then
				levelUpFrame:Destroy()
			end
		end)
	end)

	print("[UI CONTROLLER] Level up effect shown: Level " .. newLevel)
end

-- Получить главный HUD (для других контроллеров)
function UIController:GetMainHUD()
	return self.MainHUD
end

-- Проверка готовности UI
function UIController:IsUIReady()
	return self.MainHUD ~= nil
end

function UIController:OnCleanup()
	if self.MainHUD then
		self.MainHUD:Destroy()
		self.MainHUD = nil
	end

	print("[UI CONTROLLER] UI controller cleaned up")
end

return UIController
