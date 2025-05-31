-- src/client/controllers/ResourceController.lua
-- Контроллер для управления ресурсами игрока (здоровье, мана, стамина)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local BaseController = require(ReplicatedStorage.Shared.BaseController)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local ResourceController = setmetatable({}, { __index = BaseController })
ResourceController.__index = ResourceController

function ResourceController.new()
	local self = setmetatable(BaseController.new("ResourceController"), ResourceController)

	self.LocalPlayer = Players.LocalPlayer
	self.PlayerGui = self.LocalPlayer:WaitForChild("PlayerGui")

	-- Состояние ресурсов
	self.Resources = {
		Health = { Current = 100, Max = 100, LastValue = 100 },
		Mana = { Current = 50, Max = 50, LastValue = 50 },
		Stamina = { Current = 100, Max = 100, LastValue = 100 },
	}

	-- UI элементы
	self.ResourceBars = {}
	self.ResourceTexts = {}
	self.IsUIReady = false

	-- Очередь обновлений до готовности UI
	self.PendingUpdates = {}

	-- Настройки анимации
	self.AnimationDuration = 0.5
	self.LastUpdateTime = 0
	self.UpdateCooldown = 0.05 -- 50мс между обновлениями

	-- Настройки звуков
	self.SoundEnabled = true
	self.LastSoundTime = {
		Damage = 0,
		Heal = 0,
		ManaDrain = 0,
		StaminaDrain = 0,
	}
	self.SoundCooldown = 0.1 -- 100мс между звуками

	return self
end

function ResourceController:OnInitialize()
	print("[RESOURCE CONTROLLER] Initializing resource management...")

	-- Ждем появления основного HUD
	self:WaitForMainHUD()
end

function ResourceController:OnStart()
	-- Подключаем обработчики событий от сервера
	self:ConnectServerEvents()

	print("[RESOURCE CONTROLLER] Resource management ready!")
end

-- Ожидание появления основного HUD
function ResourceController:WaitForMainHUD()
	spawn(function()
		local maxAttempts = 200 -- Увеличиваем количество попыток
		local attempts = 0

		while attempts < maxAttempts do
			local mainHUD = self.PlayerGui:FindFirstChild("MainHUD")
			if mainHUD then
				self:CreateResourceBars(mainHUD)
				self.IsUIReady = true

				-- Обрабатываем все отложенные обновления
				self:ProcessPendingUpdates()
				break
			end

			attempts = attempts + 1
			wait(0.1)
		end

		if attempts >= maxAttempts then
			warn("[RESOURCE CONTROLLER] MainHUD not found after " .. maxAttempts .. " attempts")
			-- Пытаемся создать UI принудительно
			self:CreateResourceBarsForced()
		end
	end)
end

-- Принудительное создание UI если MainHUD не найден
function ResourceController:CreateResourceBarsForced()
	print("[RESOURCE CONTROLLER] Creating resource bars in PlayerGui directly")

	-- Создаем собственный ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ResourceHUD"
	screenGui.Parent = self.PlayerGui

	self:CreateResourceBars(screenGui)
	self.IsUIReady = true
	self:ProcessPendingUpdates()
end

-- Обработка отложенных обновлений
function ResourceController:ProcessPendingUpdates()
	print("[RESOURCE CONTROLLER] Processing " .. #self.PendingUpdates .. " pending updates")

	for _, updateData in ipairs(self.PendingUpdates) do
		self:UpdateResourceBar(updateData.resourceType, updateData.newValue, updateData.maxValue)
	end

	self.PendingUpdates = {}
end

-- Создание полосок ресурсов
function ResourceController:CreateResourceBars(parent)
	-- Создаем основной фрейм для ресурсов
	local resourceFrame = Instance.new("Frame")
	resourceFrame.Name = "ResourceFrame"
	resourceFrame.Size = UDim2.new(0, 250, 0, 90)
	resourceFrame.Position = UDim2.new(0, 10, 0, 120) -- Под существующим StatsFrame
	resourceFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	resourceFrame.BackgroundTransparency = 0.5
	resourceFrame.BorderSizePixel = 0
	resourceFrame.Parent = parent

	-- Добавляем скругленные углы
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = resourceFrame

	-- Создаем полоски ресурсов
	self:CreateResourceBar(resourceFrame, "Health", "❤️", Color3.fromRGB(255, 0, 0), 0)
	self:CreateResourceBar(resourceFrame, "Mana", "💙", Color3.fromRGB(0, 100, 255), 30)
	self:CreateResourceBar(resourceFrame, "Stamina", "💛", Color3.fromRGB(255, 200, 0), 60)

	print("[RESOURCE CONTROLLER] Resource bars created successfully")
end

-- Создание отдельной полоски ресурса
function ResourceController:CreateResourceBar(parent, resourceType, icon, color, yOffset)
	-- Основной фрейм полоски
	local barFrame = Instance.new("Frame")
	barFrame.Name = resourceType .. "Bar"
	barFrame.Size = UDim2.new(1, -20, 0, 25)
	barFrame.Position = UDim2.new(0, 10, 0, yOffset + 5)
	barFrame.BackgroundTransparency = 1
	barFrame.Parent = parent

	-- Иконка ресурса
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 20, 1, 0)
	iconLabel.Position = UDim2.new(0, 0, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextScaled = true
	iconLabel.Font = Constants.UI.FONTS.MAIN
	iconLabel.Parent = barFrame

	-- Фон полоски
	local barBackground = Instance.new("Frame")
	barBackground.Name = "Background"
	barBackground.Size = UDim2.new(1, -70, 0, 18)
	barBackground.Position = UDim2.new(0, 25, 0, 4)
	barBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBackground.BorderSizePixel = 0
	barBackground.Parent = barFrame

	-- Скругленные углы для фона
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 3)
	bgCorner.Parent = barBackground

	-- Полоска заполнения
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.Position = UDim2.new(0, 0, 0, 0)
	barFill.BackgroundColor3 = color
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground

	-- Скругленные углы для заполнения
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = barFill

	-- Текст с цифрами
	local valueText = Instance.new("TextLabel")
	valueText.Name = "ValueText"
	valueText.Size = UDim2.new(0, 45, 1, 0)
	valueText.Position = UDim2.new(1, -45, 0, 0)
	valueText.BackgroundTransparency = 1
	valueText.Text = "100/100"
	valueText.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueText.TextScaled = true
	valueText.Font = Constants.UI.FONTS.MAIN
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.Parent = barFrame

	-- Сохраняем ссылки
	self.ResourceBars[resourceType] = barFill
	self.ResourceTexts[resourceType] = valueText

	-- Добавляем градиент для красоты
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.8, 0.8, 0.8)),
	})
	gradient.Rotation = 90
	gradient.Parent = barFill

	print("[RESOURCE CONTROLLER] Created resource bar: " .. resourceType)
end

-- Подключение событий от сервера
function ResourceController:ConnectServerEvents()
	local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Изменение ресурсов
	local resourceChanged = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.RESOURCE_CHANGED)
	self:ConnectEvent(resourceChanged.OnClientEvent, function(data)
		self:OnResourceChanged(data)
	end)

	-- Получение урона
	local damageTaken = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.DAMAGE_TAKEN)
	self:ConnectEvent(damageTaken.OnClientEvent, function(data)
		self:OnDamageTaken(data)
	end)

	-- Получение лечения
	local healingReceived = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.HEALING_RECEIVED)
	self:ConnectEvent(healingReceived.OnClientEvent, function(data)
		self:OnHealingReceived(data)
	end)

	-- Изменение неуязвимости
	local invulnerabilityChanged = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.INVULNERABILITY_CHANGED)
	self:ConnectEvent(invulnerabilityChanged.OnClientEvent, function(data)
		self:OnInvulnerabilityChanged(data)
	end)

	-- Смерть персонажа
	local characterDied = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.CHARACTER_DIED)
	self:ConnectEvent(characterDied.OnClientEvent, function(data)
		self:OnCharacterDied(data)
	end)

	-- Появление персонажа
	local characterSpawned = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.CHARACTER_SPAWNED)
	self:ConnectEvent(characterSpawned.OnClientEvent, function(data)
		self:OnCharacterSpawned(data)
	end)

	print("[RESOURCE CONTROLLER] Server events connected")
end

---[[ ОБРАБОТЧИКИ СОБЫТИЙ ]]---

-- Обработка изменения ресурса
function ResourceController:OnResourceChanged(data)
	local resourceType = data.ResourceType
	local newValue = data.Value
	local maxValue = data.MaxValue

	if not resourceType or not newValue or not maxValue then
		warn("[RESOURCE CONTROLLER] Invalid resource data received")
		return
	end

	-- Если UI еще не готов, добавляем в очередь
	if not self.IsUIReady then
		table.insert(self.PendingUpdates, {
			resourceType = resourceType,
			newValue = newValue,
			maxValue = maxValue,
		})
		print("[RESOURCE CONTROLLER] Queued resource update: " .. resourceType)
		return
	end

	-- Проверяем дебаунс
	local currentTime = tick()
	if currentTime - self.LastUpdateTime < self.UpdateCooldown then
		-- Сохраняем данные для отложенного обновления
		spawn(function()
			wait(self.UpdateCooldown)
			if self.IsUIReady then
				self:UpdateResourceBar(resourceType, newValue, maxValue)
			end
		end)
		return
	end

	self.LastUpdateTime = currentTime
	self:UpdateResourceBar(resourceType, newValue, maxValue)
end

-- Обработка получения урона
function ResourceController:OnDamageTaken(data)
	print(
		string.format(
			"[RESOURCE CONTROLLER] Damage taken: %d %s from %s",
			data.Damage,
			data.DamageType or "Unknown",
			data.Source or "Unknown"
		)
	)

	-- Воспроизводим звук урона
	self:PlayDamageSound(data.Damage)

	-- Создаем визуальный эффект
	self:CreateDamageEffect(data.Damage)

	-- Встряхиваем экран при сильном уроне
	if data.Damage > 50 then
		self:ShakeScreen(0.5, data.Damage / 100)
	end
end

-- Обработка получения лечения
function ResourceController:OnHealingReceived(data)
	-- Не показываем эффекты для малого лечения
	if data.Amount < 1 then
		return
	end

	print(
		string.format(
			"[RESOURCE CONTROLLER] Healing received: %d %s",
			math.floor(data.Amount),
			data.HealType or "Unknown"
		)
	)

	-- Воспроизводим звук лечения
	self:PlayHealSound(data.Amount)

	-- Создаем визуальный эффект лечения
	self:CreateHealEffect(data.Amount)
end

-- Обработка изменения неуязвимости
function ResourceController:OnInvulnerabilityChanged(data)
	if data.IsInvulnerable then
		print(string.format("[RESOURCE CONTROLLER] Invulnerability activated for %.1f seconds", data.Duration))
		self:ShowInvulnerabilityEffect(data.Duration)
	else
		print("[RESOURCE CONTROLLER] Invulnerability ended")
		self:HideInvulnerabilityEffect()
	end
end

-- Обработка смерти персонажа
function ResourceController:OnCharacterDied(data)
	print(string.format("[RESOURCE CONTROLLER] Character died, respawn in %d seconds", data.RespawnTime))

	-- Обновляем здоровье на 0
	if self.IsUIReady then
		self:UpdateResourceBar("Health", 0, self.Resources.Health.Max)
	end

	-- Показываем экран смерти
	self:ShowDeathScreen(data.RespawnTime)
end

-- Обработка появления персонажа
function ResourceController:OnCharacterSpawned(data)
	print("[RESOURCE CONTROLLER] Character spawned")

	-- Скрываем экран смерти
	self:HideDeathScreen()

	-- Обновляем ресурсы
	if data.Health and data.MaxHealth and self.IsUIReady then
		self:UpdateResourceBar("Health", data.Health, data.MaxHealth)
	end
end

---[[ ОБНОВЛЕНИЕ UI ]]---

-- Обновление полоски ресурса
function ResourceController:UpdateResourceBar(resourceType, newValue, maxValue)
	local barFill = self.ResourceBars[resourceType]
	local valueText = self.ResourceTexts[resourceType]

	if not barFill or not valueText then
		warn(
			"[RESOURCE CONTROLLER] Resource bar not found: "
				.. resourceType
				.. " (UI Ready: "
				.. tostring(self.IsUIReady)
				.. ")"
		)

		-- Если UI не готов, добавляем в очередь
		if not self.IsUIReady then
			table.insert(self.PendingUpdates, {
				resourceType = resourceType,
				newValue = newValue,
				maxValue = maxValue,
			})
		end
		return
	end

	-- Сохраняем старое значение для анимации
	local resource = self.Resources[resourceType]
	local oldValue = resource.Current

	-- Обновляем состояние
	resource.Current = newValue
	resource.Max = maxValue
	resource.LastValue = oldValue

	-- Рассчитываем процент заполнения
	local percentage = maxValue > 0 and (newValue / maxValue) or 0
	percentage = math.max(0, math.min(1, percentage))

	-- Анимируем изменение размера полоски
	local targetSize = UDim2.new(percentage, 0, 1, 0)

	local tweenInfo = TweenInfo.new(self.AnimationDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	local sizeTween = TweenService:Create(barFill, tweenInfo, { Size = targetSize })
	sizeTween:Play()

	-- Обновляем текст
	valueText.Text = string.format("%d/%d", math.floor(newValue), math.floor(maxValue))

	-- Изменяем цвет в зависимости от процента (для здоровья)
	if resourceType == "Health" then
		self:UpdateHealthBarColor(barFill, percentage)
	end

	-- Воспроизводим звуки изменения ресурсов (только для значительных изменений)
	if math.abs(oldValue - newValue) >= 1 then
		self:PlayResourceChangeSound(resourceType, oldValue, newValue)
	end

	-- Логируем только значительные изменения
	if math.abs(oldValue - newValue) >= 5 then
		print(
			string.format(
				"[RESOURCE CONTROLLER] Updated %s: %d/%d (%.1f%%)",
				resourceType,
				newValue,
				maxValue,
				percentage * 100
			)
		)
	end
end

-- Обновление цвета полоски здоровья
function ResourceController:UpdateHealthBarColor(barFill, percentage)
	local color

	if percentage > 0.6 then
		-- Зеленый (здоровый)
		color = Color3.fromRGB(0, 255, 0)
	elseif percentage > 0.3 then
		-- Желтый (раненый)
		color = Color3.fromRGB(255, 255, 0)
	else
		-- Красный (критическое состояние)
		color = Color3.fromRGB(255, 0, 0)
	end

	-- Анимируем изменение цвета
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local colorTween = TweenService:Create(barFill, tweenInfo, { BackgroundColor3 = color })
	colorTween:Play()
end

---[[ ЗВУКОВЫЕ ЭФФЕКТЫ ]]---

-- Воспроизведение звука урона
function ResourceController:PlayDamageSound(damage)
	if not self.SoundEnabled then
		return
	end

	local currentTime = tick()
	if currentTime - self.LastSoundTime.Damage < self.SoundCooldown then
		return
	end

	self.LastSoundTime.Damage = currentTime

	-- Выбираем звук в зависимости от урона
	local soundId
	if damage > 100 then
		soundId = "rbxasset://sounds/impact_hurt_3.mp3" -- Сильный урон
	elseif damage > 25 then
		soundId = "rbxasset://sounds/impact_hurt_2.mp3" -- Средний урон
	else
		soundId = "rbxasset://sounds/impact_hurt_1.mp3" -- Слабый урон
	end

	self:PlaySound(soundId, 0.5)
end

-- Воспроизведение звука лечения
function ResourceController:PlayHealSound(amount)
	if not self.SoundEnabled then
		return
	end

	local currentTime = tick()
	if currentTime - self.LastSoundTime.Heal < self.SoundCooldown then
		return
	end

	self.LastSoundTime.Heal = currentTime

	-- Звук лечения
	self:PlaySound("rbxasset://sounds/electronicpingshort.wav", 0.3)
end

-- Воспроизведение звука изменения ресурса
function ResourceController:PlayResourceChangeSound(resourceType, oldValue, newValue)
	if not self.SoundEnabled then
		return
	end

	local currentTime = tick()
	local soundType = resourceType == "Mana" and "ManaDrain" or "StaminaDrain"

	if currentTime - self.LastSoundTime[soundType] < self.SoundCooldown then
		return
	end

	-- Воспроизводим звук только при значительном изменении
	local change = math.abs(newValue - oldValue)
	if change < 5 then
		return
	end

	self.LastSoundTime[soundType] = currentTime

	if resourceType == "Mana" and newValue < oldValue then
		-- Трата маны
		self:PlaySound("rbxasset://sounds/electronicpingshort.wav", 0.2)
	elseif resourceType == "Stamina" and newValue < oldValue then
		-- Трата стамины
		self:PlaySound("rbxasset://sounds/impact_grunt.mp3", 0.2)
	end
end

-- Универсальная функция воспроизведения звука
function ResourceController:PlaySound(soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = SoundService

	sound:Play()

	-- Удаляем звук после воспроизведения
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

---[[ ВИЗУАЛЬНЫЕ ЭФФЕКТЫ ]]---

-- Создание эффекта урона
function ResourceController:CreateDamageEffect(damage)
	local screenGui = self.PlayerGui:FindFirstChild("MainHUD") or self.PlayerGui:FindFirstChild("ResourceHUD")
	if not screenGui then
		return
	end

	-- Создаем текст урона
	local damageText = Instance.new("TextLabel")
	damageText.Name = "DamageText"
	damageText.Size = UDim2.new(0, 100, 0, 30)
	damageText.Position = UDim2.new(0.5, math.random(-50, 50), 0.4, math.random(-20, 20))
	damageText.BackgroundTransparency = 1
	damageText.Text = "-" .. math.floor(damage)
	damageText.TextColor3 = Color3.fromRGB(255, 50, 50)
	damageText.TextScaled = true
	damageText.Font = Constants.UI.FONTS.BOLD
	damageText.TextStrokeTransparency = 0
	damageText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	damageText.Parent = screenGui

	-- Анимация вылета вверх и исчезновения
	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local moveTween = TweenService:Create(damageText, tweenInfo, {
		Position = UDim2.new(
			damageText.Position.X.Scale,
			damageText.Position.X.Offset,
			damageText.Position.Y.Scale - 0.1,
			damageText.Position.Y.Offset
		),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	moveTween:Play()
	moveTween.Completed:Connect(function()
		damageText:Destroy()
	end)
end

-- Создание эффекта лечения
function ResourceController:CreateHealEffect(amount)
	-- Не создаем эффекты для малого лечения
	if amount < 1 then
		return
	end

	local screenGui = self.PlayerGui:FindFirstChild("MainHUD") or self.PlayerGui:FindFirstChild("ResourceHUD")
	if not screenGui then
		return
	end

	-- Создаем текст лечения
	local healText = Instance.new("TextLabel")
	healText.Name = "HealText"
	healText.Size = UDim2.new(0, 100, 0, 30)
	healText.Position = UDim2.new(0.5, math.random(-50, 50), 0.4, math.random(-20, 20))
	healText.BackgroundTransparency = 1
	healText.Text = "+" .. math.floor(amount)
	healText.TextColor3 = Color3.fromRGB(50, 255, 50)
	healText.TextScaled = true
	healText.Font = Constants.UI.FONTS.BOLD
	healText.TextStrokeTransparency = 0
	healText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	healText.Parent = screenGui

	-- Анимация вылета вверх и исчезновения
	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local moveTween = TweenService:Create(healText, tweenInfo, {
		Position = UDim2.new(
			healText.Position.X.Scale,
			healText.Position.X.Offset,
			healText.Position.Y.Scale - 0.1,
			healText.Position.Y.Offset
		),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	moveTween:Play()
	moveTween.Completed:Connect(function()
		healText:Destroy()
	end)
end

-- Эффект встряхивания экрана
function ResourceController:ShakeScreen(duration, intensity)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local originalCFrame = camera.CFrame
	local shakeCoroutine = coroutine.create(function()
		local startTime = tick()

		while tick() - startTime < duration do
			local randomX = (math.random() - 0.5) * intensity
			local randomY = (math.random() - 0.5) * intensity
			local randomZ = (math.random() - 0.5) * intensity

			camera.CFrame = originalCFrame + Vector3.new(randomX, randomY, randomZ)

			wait()
		end

		-- Возвращаем камеру в исходное положение
		camera.CFrame = originalCFrame
	end)

	coroutine.resume(shakeCoroutine)
end

-- Показать эффект неуязвимости
function ResourceController:ShowInvulnerabilityEffect(duration)
	local screenGui = self.PlayerGui:FindFirstChild("MainHUD") or self.PlayerGui:FindFirstChild("ResourceHUD")
	if not screenGui then
		return
	end

	-- Создаем эффект мерцания границ экрана
	local invulEffect = Instance.new("Frame")
	invulEffect.Name = "InvulnerabilityEffect"
	invulEffect.Size = UDim2.new(1, 0, 1, 0)
	invulEffect.Position = UDim2.new(0, 0, 0, 0)
	invulEffect.BackgroundTransparency = 1
	invulEffect.BorderSizePixel = 3
	invulEffect.BorderColor3 = Color3.fromRGB(255, 215, 0) -- Золотой цвет
	invulEffect.Parent = screenGui

	-- Анимация мерцания
	local blinkTween = TweenService:Create(
		invulEffect,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
		{ BorderColor3 = Color3.fromRGB(255, 255, 255) }
	)
	blinkTween:Play()

	-- Убираем эффект через указанное время
	spawn(function()
		wait(duration)
		blinkTween:Cancel()
		if invulEffect.Parent then
			invulEffect:Destroy()
		end
	end)
end

-- Скрыть эффект неуязвимости
function ResourceController:HideInvulnerabilityEffect()
	local screenGui = self.PlayerGui:FindFirstChild("MainHUD") or self.PlayerGui:FindFirstChild("ResourceHUD")
	if not screenGui then
		return
	end

	local invulEffect = screenGui:FindFirstChild("InvulnerabilityEffect")
	if invulEffect then
		invulEffect:Destroy()
	end
end

-- Показать экран смерти
function ResourceController:ShowDeathScreen(respawnTime)
	local screenGui = self.PlayerGui:FindFirstChild("MainHUD") or self.PlayerGui:FindFirstChild("ResourceHUD")
	if not screenGui then
		return
	end

	-- Создаем экран смерти
	local deathScreen = Instance.new("Frame")
	deathScreen.Name = "DeathScreen"
	deathScreen.Size = UDim2.new(1, 0, 1, 0)
	deathScreen.Position = UDim2.new(0, 0, 0, 0)
	deathScreen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	deathScreen.BackgroundTransparency = 0.5
	deathScreen.Parent = screenGui

	-- Текст "ВЫ МЕРТВЫ"
	local deathText = Instance.new("TextLabel")
	deathText.Name = "DeathText"
	deathText.Size = UDim2.new(0, 400, 0, 100)
	deathText.Position = UDim2.new(0.5, -200, 0.4, -50)
	deathText.BackgroundTransparency = 1
	deathText.Text = "ВЫ МЕРТВЫ"
	deathText.TextColor3 = Color3.fromRGB(255, 0, 0)
	deathText.TextScaled = true
	deathText.Font = Constants.UI.FONTS.BOLD
	deathText.TextStrokeTransparency = 0
	deathText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	deathText.Parent = deathScreen

	-- Таймер респавна
	local timerText = Instance.new("TextLabel")
	timerText.Name = "TimerText"
	timerText.Size = UDim2.new(0, 300, 0, 50)
	timerText.Position = UDim2.new(0.5, -150, 0.55, 0)
	timerText.BackgroundTransparency = 1
	timerText.Text = "Респавн через: " .. respawnTime .. " сек"
	timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerText.TextScaled = true
	timerText.Font = Constants.UI.FONTS.MAIN
	timerText.Parent = deathScreen

	-- Обновляем таймер
	spawn(function()
		local timeLeft = respawnTime
		while timeLeft > 0 and timerText.Parent do
			timerText.Text = "Респавн через: " .. timeLeft .. " сек"
			wait(1)
			timeLeft = timeLeft - 1
		end

		if timerText.Parent then
			timerText.Text = "Респавн..."
		end
	end)
end

-- Скрыть экран смерти
function ResourceController:HideDeathScreen()
	local screenGui = self.PlayerGui:FindFirstChild("MainHUD") or self.PlayerGui:FindFirstChild("ResourceHUD")
	if not screenGui then
		return
	end

	local deathScreen = screenGui:FindFirstChild("DeathScreen")
	if deathScreen then
		deathScreen:Destroy()
	end
end

---[[ УТИЛИТЫ ]]---

-- Получить текущее значение ресурса
function ResourceController:GetResourceValue(resourceType)
	local resource = self.Resources[resourceType]
	return resource and resource.Current or 0
end

-- Получить максимальное значение ресурса
function ResourceController:GetResourceMax(resourceType)
	local resource = self.Resources[resourceType]
	return resource and resource.Max or 0
end

-- Получить процент ресурса
function ResourceController:GetResourcePercentage(resourceType)
	local resource = self.Resources[resourceType]
	if not resource or resource.Max <= 0 then
		return 0
	end
	return (resource.Current / resource.Max) * 100
end

-- Включить/выключить звуки
function ResourceController:SetSoundEnabled(enabled)
	self.SoundEnabled = enabled
	print("[RESOURCE CONTROLLER] Sound effects " .. (enabled and "enabled" or "disabled"))
end

-- Получить информацию о всех ресурсах
function ResourceController:GetAllResourcesInfo()
	local info = {}
	for resourceType, resource in pairs(self.Resources) do
		info[resourceType] = {
			Current = resource.Current,
			Max = resource.Max,
			Percentage = self:GetResourcePercentage(resourceType),
		}
	end
	return info
end

-- Принудительное обновление UI (для дебага)
function ResourceController:ForceUpdateUI()
	if not self.IsUIReady then
		print("[RESOURCE CONTROLLER] UI not ready for force update")
		return
	end

	-- Обновляем все ресурсы текущими значениями
	for resourceType, resource in pairs(self.Resources) do
		self:UpdateResourceBar(resourceType, resource.Current, resource.Max)
	end

	print("[RESOURCE CONTROLLER] Force updated all resource bars")
end

-- Проверка готовности UI
function ResourceController:IsUIReady()
	return self.IsUIReady
end

function ResourceController:OnCleanup()
	-- Очищаем все визуальные эффекты
	local screenGui = self.PlayerGui:FindFirstChild("MainHUD") or self.PlayerGui:FindFirstChild("ResourceHUD")
	if screenGui then
		local deathScreen = screenGui:FindFirstChild("DeathScreen")
		if deathScreen then
			deathScreen:Destroy()
		end

		local invulEffect = screenGui:FindFirstChild("InvulnerabilityEffect")
		if invulEffect then
			invulEffect:Destroy()
		end
	end

	-- Очищаем ссылки
	self.ResourceBars = {}
	self.ResourceTexts = {}
	self.Resources = {}
	self.PendingUpdates = {}

	print("[RESOURCE CONTROLLER] Resource controller cleaned up")
end

return ResourceController
