-- src/server/services/CharacterService.lua
-- Сервис для управления персонажами игроков

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)

local CharacterService = setmetatable({}, { __index = BaseService })
CharacterService.__index = CharacterService

function CharacterService.new()
	local self = setmetatable(BaseService.new("CharacterService"), CharacterService)

	-- Состояние персонажей
	self.PlayerCharacters = {} -- [Player] = Character
	self.DeathHandlers = {} -- [Character] = {Humanoid connection, etc}
	self.RespawnTimers = {} -- [Player] = {StartTime, Duration}
	self.InvulnerableList = {} -- [Player] = EndTime
	self.CharacterSetupQueue = {} -- [Player] = true (для отложенной настройки)

	-- События
	self.CharacterSetup = Instance.new("BindableEvent")
	self.PlayerDied = Instance.new("BindableEvent")
	self.PlayerRespawned = Instance.new("BindableEvent")
	self.ResourceChanged = Instance.new("BindableEvent")

	-- Настройки регенерации
	self.LastRegenTime = tick()
	self.RegenInterval = 1 / 60 -- Каждый кадр для плавности

	return self
end

function CharacterService:OnInitialize()
	print("[CHARACTER SERVICE] Initializing character management...")

	-- Подключаем события игроков
	self:ConnectEvent(Players.PlayerAdded, function(player)
		self:OnPlayerAdded(player)
	end)

	self:ConnectEvent(Players.PlayerRemoving, function(player)
		self:OnPlayerRemoving(player)
	end)

	-- Обрабатываем уже подключенных игроков
	for _, player in ipairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end

	-- Система регенерации ресурсов
	self:ConnectEvent(RunService.Heartbeat, function()
		self:UpdateResourceRegeneration()
		self:UpdateRespawnTimers()
		self:UpdateInvulnerability()
	end)

	print("[CHARACTER SERVICE] Character system initialized")
end

function CharacterService:OnStart()
	print("[CHARACTER SERVICE] Character service started!")
	print("[CHARACTER SERVICE] Respawn time: " .. Constants.WORLD.RESPAWN_TIME .. " seconds")
	print("[CHARACTER SERVICE] Invulnerability time: " .. Constants.WORLD.RESPAWN_INVULNERABILITY .. " seconds")
end

---[[ СОБЫТИЯ ИГРОКОВ ]]---

-- Обработка подключения игрока
function CharacterService:OnPlayerAdded(player)
	print("[CHARACTER SERVICE] Player added: " .. player.Name)

	-- Ждем появления персонажа
	if player.Character then
		self:OnCharacterAdded(player, player.Character)
	end

	self:ConnectEvent(player.CharacterAdded, function(character)
		self:OnCharacterAdded(player, character)
	end)

	self:ConnectEvent(player.CharacterRemoving, function(character)
		self:OnCharacterRemoving(player, character)
	end)
end

-- Обработка отключения игрока
function CharacterService:OnPlayerRemoving(player)
	print("[CHARACTER SERVICE] Player removing: " .. player.Name)

	-- Очищаем все данные игрока
	self.PlayerCharacters[player] = nil
	self.RespawnTimers[player] = nil
	self.InvulnerableList[player] = nil
	self.CharacterSetupQueue[player] = nil

	-- Отключаем обработчики персонажа
	if self.DeathHandlers[player] then
		for _, connection in pairs(self.DeathHandlers[player]) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		self.DeathHandlers[player] = nil
	end
end

-- Обработка появления персонажа
function CharacterService:OnCharacterAdded(player, character)
	print("[CHARACTER SERVICE] Character added for " .. player.Name)

	-- Сохраняем ссылку на персонажа
	self.PlayerCharacters[player] = character

	-- Ждем появления Humanoid
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		warn("[CHARACTER SERVICE] No Humanoid found for " .. player.Name)
		return
	end

	-- Добавляем в очередь настройки (ждем загрузки данных)
	self.CharacterSetupQueue[player] = true

	-- Настраиваем обработчики смерти
	self:SetupDeathHandlers(player, character, humanoid)

	-- Пытаемся настроить персонажа (если данные уже загружены)
	self:TrySetupCharacter(player, character)

	-- Уведомляем о появлении персонажа
	self:FireClient(player, Constants.REMOTE_EVENTS.CHARACTER_SPAWNED, {
		Position = character.HumanoidRootPart.Position,
		Health = humanoid.Health,
		MaxHealth = humanoid.MaxHealth,
	})

	print("[CHARACTER SERVICE] Character setup initiated for " .. player.Name)
end

-- Обработка удаления персонажа
function CharacterService:OnCharacterRemoving(player, character)
	print("[CHARACTER SERVICE] Character removing for " .. player.Name)

	-- Очищаем обработчики
	if self.DeathHandlers[character] then
		for _, connection in pairs(self.DeathHandlers[character]) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		self.DeathHandlers[character] = nil
	end

	-- Убираем из списка персонажей
	if self.PlayerCharacters[player] == character then
		self.PlayerCharacters[player] = nil
	end
end

---[[ НАСТРОЙКА ПЕРСОНАЖА ]]---

-- Попытка настройки персонажа
function CharacterService:TrySetupCharacter(player, character)
	-- Проверяем, что данные игрока загружены
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not PlayerDataService or not PlayerDataService:IsDataLoaded(player) then
		-- Данные еще не загружены, ждем
		return false
	end

	-- Данные загружены, настраиваем персонажа
	self:SetupCharacterStats(player, character)
	self.CharacterSetupQueue[player] = nil

	return true
end

-- Настройка характеристик персонажа
function CharacterService:SetupCharacterStats(player, character)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if not data then
		warn("[CHARACTER SERVICE] No data available for " .. player.Name)
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		warn("[CHARACTER SERVICE] No Humanoid found for character setup")
		return
	end

	-- Рассчитываем максимальные ресурсы
	local maxHealth = Constants.PLAYER.BASE_HEALTH
		+ (data.Attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
	local maxMana = Constants.PLAYER.BASE_MANA + (data.Attributes.Intelligence * Constants.PLAYER.MANA_PER_INTELLIGENCE)
	local maxStamina = Constants.PLAYER.BASE_STAMINA
		+ (data.Attributes.Constitution * Constants.PLAYER.STAMINA_PER_CONSTITUTION)

	-- Обновляем данные игрока
	data.MaxHealth = maxHealth
	data.MaxMana = maxMana
	data.MaxStamina = maxStamina

	-- Если это первый спавн, устанавливаем полные ресурсы
	if data.Health <= 0 or not data.Health then
		data.Health = maxHealth
		data.Mana = maxMana
		data.Stamina = maxStamina
	end

	-- Применяем к Humanoid
	humanoid.MaxHealth = maxHealth
	humanoid.Health = data.Health

	-- Добавляем атрибуты скорости, если есть (пример)
	local walkSpeed = 16 + (data.Attributes.Dexterity * 0.1) -- Базовая скорость + бонус от ловкости
	humanoid.WalkSpeed = math.min(walkSpeed, 50) -- Ограничиваем максимум

	-- Уведомляем клиент об обновлении ресурсов
	self:NotifyResourceChanged(player, "Health", data.Health, maxHealth)
	self:NotifyResourceChanged(player, "Mana", data.Mana, maxMana)
	self:NotifyResourceChanged(player, "Stamina", data.Stamina, maxStamina)

	-- Отправляем полные данные клиенту
	PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

	print(
		string.format(
			"[CHARACTER SERVICE] Stats applied to %s: HP=%d/%d, MP=%d/%d, SP=%d/%d",
			player.Name,
			data.Health,
			maxHealth,
			data.Mana,
			maxMana,
			data.Stamina,
			maxStamina
		)
	)

	-- Уведомляем о настройке персонажа
	self.CharacterSetup:Fire(player, character, data)
end

---[[ ОБРАБОТКА СМЕРТИ ]]---

-- Настройка обработчиков смерти
function CharacterService:SetupDeathHandlers(player, character, humanoid)
	local handlers = {}

	-- Обработчик смерти
	handlers.DiedConnection = humanoid.Died:Connect(function()
		self:OnPlayerDied(player, character)
	end)

	-- Обработчик изменения здоровья
	handlers.HealthChanged = humanoid.HealthChanged:Connect(function(health)
		self:OnHealthChanged(player, health, humanoid.MaxHealth)
	end)

	self.DeathHandlers[character] = handlers
end

-- Обработка смерти игрока
function CharacterService:OnPlayerDied(player, character)
	print("[CHARACTER SERVICE] Player died: " .. player.Name)

	-- Получаем данные игрока
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if data then
		-- Обновляем статистику
		data.Statistics.Deaths = data.Statistics.Deaths + 1
		data.Health = 0

		-- Уведомляем об изменении здоровья
		self:NotifyResourceChanged(player, "Health", 0, data.MaxHealth)
	end

	-- Запускаем таймер респавна
	self:StartRespawnTimer(player)

	-- Уведомляем клиент о смерти
	self:FireClient(player, Constants.REMOTE_EVENTS.CHARACTER_DIED, {
		RespawnTime = Constants.WORLD.RESPAWN_TIME,
		DeathCause = "Unknown", -- Можно расширить в будущем
	})

	-- Уведомляем другие системы
	self.PlayerDied:Fire(player, character)

	print(string.format("[CHARACTER SERVICE] %s will respawn in %d seconds", player.Name, Constants.WORLD.RESPAWN_TIME))
end

-- Обработка изменения здоровья
function CharacterService:OnHealthChanged(player, newHealth, maxHealth)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if data then
		data.Health = newHealth
		self:NotifyResourceChanged(player, "Health", newHealth, maxHealth)
	end
end

---[[ СИСТЕМА РЕСПАВНА ]]---

-- Запуск таймера респавна
function CharacterService:StartRespawnTimer(player)
	self.RespawnTimers[player] = {
		StartTime = tick(),
		Duration = Constants.WORLD.RESPAWN_TIME,
	}

	print("[CHARACTER SERVICE] Respawn timer started for " .. player.Name)
end

-- Обновление таймеров респавна
function CharacterService:UpdateRespawnTimers()
	local currentTime = tick()

	for player, timerInfo in pairs(self.RespawnTimers) do
		if currentTime - timerInfo.StartTime >= timerInfo.Duration then
			-- Время респавна истекло
			self:RespawnPlayer(player)
			self.RespawnTimers[player] = nil
		end
	end
end

-- Респавн игрока
function CharacterService:RespawnPlayer(player)
	if not player.Parent then
		-- Игрок отключился
		return
	end

	print("[CHARACTER SERVICE] Respawning player: " .. player.Name)

	-- Выбираем точку спавна
	local spawnLocation = self:GetSpawnLocation(player)

	-- Загружаем персонажа
	player:LoadCharacter()

	-- Ждем появления персонажа
	if player.Character then
		local humanoidRootPart = player.Character:WaitForChild("HumanoidRootPart", 5)
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(spawnLocation)
		end
	end

	-- Активируем неуязвимость
	self:SetPlayerInvulnerable(player, Constants.WORLD.RESPAWN_INVULNERABILITY)

	-- Восстанавливаем ресурсы
	spawn(function()
		wait(1) -- Ждем полной загрузки персонажа
		self:RestorePlayerResources(player)
	end)

	-- Уведомляем о респавне
	self.PlayerRespawned:Fire(player)

	print("[CHARACTER SERVICE] Player respawned: " .. player.Name)
end

-- Получение точки спавна
function CharacterService:GetSpawnLocation(player)
	-- Пока что используем главную точку спавна
	-- В будущем можно добавить логику выбора ближайшей/случайной точки
	local spawnLocations = Constants.WORLD.SPAWN_LOCATIONS
	return spawnLocations.MAIN.Position
end

-- Восстановление ресурсов игрока
function CharacterService:RestorePlayerResources(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end

	-- Восстанавливаем полные ресурсы
	data.Health = data.MaxHealth
	data.Mana = data.MaxMana
	data.Stamina = data.MaxStamina

	-- Обновляем Humanoid
	local character = self.PlayerCharacters[player]
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = data.Health
		end
	end

	-- Уведомляем об изменениях
	self:NotifyResourceChanged(player, "Health", data.Health, data.MaxHealth)
	self:NotifyResourceChanged(player, "Mana", data.Mana, data.MaxMana)
	self:NotifyResourceChanged(player, "Stamina", data.Stamina, data.MaxStamina)

	print("[CHARACTER SERVICE] Resources restored for " .. player.Name)
end

---[[ СИСТЕМА НЕУЯЗВИМОСТИ ]]---

-- Установка неуязвимости
function CharacterService:SetPlayerInvulnerable(player, duration)
	local endTime = tick() + duration
	self.InvulnerableList[player] = endTime

	-- Уведомляем клиент
	self:FireClient(player, Constants.REMOTE_EVENTS.INVULNERABILITY_CHANGED, {
		IsInvulnerable = true,
		Duration = duration,
		EndTime = endTime,
	})

	print(string.format("[CHARACTER SERVICE] %s is invulnerable for %.1f seconds", player.Name, duration))
end

-- Проверка неуязвимости
function CharacterService:IsPlayerInvulnerable(player)
	local endTime = self.InvulnerableList[player]
	if not endTime then
		return false
	end

	return tick() < endTime
end

-- Обновление неуязвимости
function CharacterService:UpdateInvulnerability()
	local currentTime = tick()

	for player, endTime in pairs(self.InvulnerableList) do
		if currentTime >= endTime then
			-- Неуязвимость истекла
			self.InvulnerableList[player] = nil

			-- Уведомляем клиент
			self:FireClient(player, Constants.REMOTE_EVENTS.INVULNERABILITY_CHANGED, {
				IsInvulnerable = false,
				Duration = 0,
				EndTime = 0,
			})

			print("[CHARACTER SERVICE] Invulnerability ended for " .. player.Name)
		end
	end
end

---[[ УПРАВЛЕНИЕ РЕСУРСАМИ ]]---

-- Нанесение урона
function CharacterService:DamagePlayer(player, damage, damageType, source)
	damageType = damageType or "Physical"
	source = source or "Unknown"

	-- Проверяем неуязвимость
	if self:IsPlayerInvulnerable(player) then
		print("[CHARACTER SERVICE] Damage blocked by invulnerability: " .. player.Name)
		return false
	end

	local character = self.PlayerCharacters[player]
	if not character then
		return false
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- Валидация урона
	local damageResult = ValidationUtils.ValidateNumberRange(damage, 0, 50000, "Damage")
	if not damageResult.IsValid then
		warn("[CHARACTER SERVICE] Invalid damage amount: " .. damage)
		return false
	end

	-- Применяем урон
	humanoid.Health = math.max(0, humanoid.Health - damage)

	-- Уведомляем клиент
	self:FireClient(player, Constants.REMOTE_EVENTS.DAMAGE_TAKEN, {
		Damage = damage,
		DamageType = damageType,
		Source = source,
		NewHealth = humanoid.Health,
		MaxHealth = humanoid.MaxHealth,
	})

	print(string.format("[CHARACTER SERVICE] %s took %d %s damage from %s", player.Name, damage, damageType, source))
	return true
end

-- Лечение игрока
function CharacterService:HealPlayer(player, amount, healType)
	healType = healType or "Regeneration"

	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if not data then
		return false
	end

	local character = self.PlayerCharacters[player]
	if not character then
		return false
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return false
	end

	-- Рассчитываем новое здоровье
	local newHealth = math.min(data.MaxHealth, data.Health + amount)
	local actualHealing = newHealth - data.Health

	-- Не обрабатываем нулевое лечение
	if actualHealing <= 0.1 then -- Минимальный порог
		return false
	end

	-- Применяем лечение
	data.Health = newHealth
	humanoid.Health = newHealth

	-- Уведомляем об изменении
	self:NotifyResourceChanged(player, "Health", newHealth, data.MaxHealth)

	-- Уведомляем о лечении только если это не регенерация или значительное лечение
	if healType ~= "Regeneration" or actualHealing >= 1 then
		self:FireClient(player, Constants.REMOTE_EVENTS.HEALING_RECEIVED, {
			Amount = actualHealing,
			HealType = healType,
			NewHealth = newHealth,
			MaxHealth = data.MaxHealth,
		})
	end

	return true
end

-- Восстановление маны
function CharacterService:RestoreMana(player, amount)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if not data then
		return false
	end

	local newMana = math.min(data.MaxMana, data.Mana + amount)
	local actualRestore = newMana - data.Mana

	-- Не обрабатываем нулевое восстановление
	if actualRestore <= 0.1 then
		return false
	end

	data.Mana = newMana
	self:NotifyResourceChanged(player, "Mana", newMana, data.MaxMana)

	return true
end

-- Потребление стамины
function CharacterService:ConsumeStamina(player, amount)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if not data then
		return false
	end

	if data.Stamina < amount then
		return false -- Недостаточно стамины
	end

	data.Stamina = math.max(0, data.Stamina - amount)
	self:NotifyResourceChanged(player, "Stamina", data.Stamina, data.MaxStamina)

	return true
end

-- Восстановление стамины
function CharacterService:RestoreStamina(player, amount)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if not data then
		return false
	end

	local newStamina = math.min(data.MaxStamina, data.Stamina + amount)
	local actualRestore = newStamina - data.Stamina

	-- Не обрабатываем нулевое восстановление
	if actualRestore <= 0.1 then
		return false
	end

	data.Stamina = newStamina
	self:NotifyResourceChanged(player, "Stamina", newStamina, data.MaxStamina)

	return true
end

---[[ СИСТЕМА РЕГЕНЕРАЦИИ ]]---

-- Обновление регенерации ресурсов
function CharacterService:UpdateResourceRegeneration()
	local currentTime = tick()
	local deltaTime = currentTime - self.LastRegenTime

	-- Обновляем реже - каждые 200мс вместо каждого кадра
	if deltaTime < 0.2 then
		return
	end

	self.LastRegenTime = currentTime

	-- Обрабатываем всех игроков
	for player, character in pairs(self.PlayerCharacters) do
		if not character or not character.Parent then
			continue
		end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		self:RegeneratePlayerResources(player, deltaTime)
	end
end

-- Регенерация ресурсов конкретного игрока
function CharacterService:RegeneratePlayerResources(player, deltaTime)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end

	local healthRegen = Constants.COMBAT.HEALTH_REGEN_RATE * deltaTime
	local manaRegen = Constants.COMBAT.MANA_REGEN_RATE * deltaTime
	local staminaRegen = Constants.COMBAT.STAMINA_REGEN_RATE * deltaTime

	-- Регенерация здоровья
	if data.Health < data.MaxHealth and data.Health > 0 then
		self:HealPlayer(player, healthRegen, "Regeneration")
	end

	-- Регенерация маны
	if data.Mana < data.MaxMana then
		self:RestoreMana(player, manaRegen)
	end

	-- Регенерация стамины
	if data.Stamina < data.MaxStamina then
		self:RestoreStamina(player, staminaRegen)
	end
end

---[[ УТИЛИТЫ ]]---

-- Уведомление об изменении ресурса
function CharacterService:NotifyResourceChanged(player, resourceType, newValue, maxValue)
	self:FireClient(player, Constants.REMOTE_EVENTS.RESOURCE_CHANGED, {
		ResourceType = resourceType,
		Value = newValue,
		MaxValue = maxValue,
		Percentage = (newValue / maxValue) * 100,
	})

	-- Локальное событие для других сервисов
	self.ResourceChanged:Fire(player, resourceType, newValue, maxValue)
end

-- Получение персонажа игрока
function CharacterService:GetPlayerCharacter(player)
	return self.PlayerCharacters[player]
end

-- Проверка, настроен ли персонаж
function CharacterService:IsCharacterSetup(player)
	return self.CharacterSetupQueue[player] == nil and self.PlayerCharacters[player] ~= nil
end

-- Принудительная настройка персонажа (для debug команд)
function CharacterService:ForceSetupCharacter(player)
	local character = self.PlayerCharacters[player]
	if character then
		self:SetupCharacterStats(player, character)
		return true
	end
	return false
end

-- Отправка события клиенту
function CharacterService:FireClient(player, eventName, data)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local RemoteService = ServiceManager:GetService("RemoteService")

	if RemoteService and RemoteService:IsReady() then
		RemoteService:FireClient(player, eventName, data)
	end
end

-- Обработка очереди настройки персонажей
function CharacterService:ProcessSetupQueue()
	for player, _ in pairs(self.CharacterSetupQueue) do
		local character = self.PlayerCharacters[player]
		if character then
			if self:TrySetupCharacter(player, character) then
				print("[CHARACTER SERVICE] Delayed character setup completed for " .. player.Name)
			end
		end
	end
end

function CharacterService:OnCleanup()
	-- Очищаем все соединения и данные
	for player, _ in pairs(self.PlayerCharacters) do
		self:OnPlayerRemoving(player)
	end

	-- Очищаем события
	if self.CharacterSetup then
		self.CharacterSetup:Destroy()
	end
	if self.PlayerDied then
		self.PlayerDied:Destroy()
	end
	if self.PlayerRespawned then
		self.PlayerRespawned:Destroy()
	end
	if self.ResourceChanged then
		self.ResourceChanged:Destroy()
	end

	print("[CHARACTER SERVICE] Character service cleaned up")
end

return CharacterService
