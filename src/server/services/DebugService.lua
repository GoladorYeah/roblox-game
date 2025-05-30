-- src/server/services/DebugService.lua
-- Сервис для отладочных команд и тестирования

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local DebugService = setmetatable({}, { __index = BaseService })
DebugService.__index = DebugService

function DebugService.new()
	local self = setmetatable(BaseService.new("DebugService"), DebugService)

	self.Commands = {}
	self.AdminPlayers = {} -- Здесь можно добавить admin player ID's

	return self
end

function DebugService:OnInitialize()
	-- Регистрируем базовые команды
	self:RegisterCommand("help", "Показать все команды", function(player, _)
		self:ShowHelp(player)
	end)

	self:RegisterCommand("addxp", "Добавить опыт: /addxp [количество]", function(player, args)
		local amount = tonumber(args[1]) or 100
		self:AddExperience(player, amount)
	end)

	-- ДОПОЛНИТЕЛЬНО: Добавить команду для установки опыта
	self:RegisterCommand(
		"setexp",
		"Установить опыт: /setexp [количество]",
		function(player, args)
			local experience = tonumber(args[1]) or 0
			self:SetExperience(player, experience)
		end
	)

	self:RegisterCommand(
		"setlevel",
		"Установить уровень: /setlevel [уровень]",
		function(player, args)
			local level = tonumber(args[1]) or 1
			self:SetLevel(player, level)
		end
	)

	self:RegisterCommand(
		"addgold",
		"Добавить золото: /addgold [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 100
			self:AddGold(player, amount)
		end
	)

	self:RegisterCommand("stats", "Показать статистику игрока", function(player, _)
		self:ShowStats(player)
	end)

	self:RegisterCommand("heal", "Восстановить здоровье", function(player, _)
		self:HealPlayer(player)
	end)

	-- НОВЫЕ КОМАНДЫ ДЛЯ ВАЛИДАЦИИ
	self:RegisterCommand("valstats", "Статистика валидации", function(player, _)
		self:ShowValidationStats(player)
	end)

	self:RegisterCommand("testval", "Тест валидации: /testval [тип]", function(player, args)
		local testType = args[1] or "player"
		self:TestValidation(player, testType)
	end)

	self:RegisterCommand("resetval", "Сброс статистики валидации", function(player, _)
		self:ResetValidationStats(player)
	end)

	self:RegisterCommand("perf", "Статистика производительности", function(player, _)
		self:ShowPerformanceStats(player)
	end)

	-- Диагностика системы опыта
	self:RegisterCommand("xpdiag", "Диагностика опыта", function(player, _)
		self:DiagnoseExperience(player)
	end)

	-- Исправить опыт для текущего уровня
	self:RegisterCommand("fixexp", "Исправить опыт", function(player, _)
		self:FixPlayerExperience(player)
	end)
end

function DebugService:OnStart()
	-- Подключаем обработчик чата
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		-- Новая система чата
		self:ConnectEvent(TextChatService.MessageReceived, function(textChatMessage)
			local player = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
			if player then
				self:ProcessChatMessage(player, textChatMessage.Text)
			end
		end)
	else
		-- Старая система чата
		self:ConnectEvent(Players.PlayerAdded, function(player)
			if player.Chatted then
				self:ConnectEvent(player.Chatted, function(message)
					self:ProcessChatMessage(player, message)
				end)
			end
		end)

		-- Для уже подключенных игроков
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Chatted then
				self:ConnectEvent(player.Chatted, function(message)
					self:ProcessChatMessage(player, message)
				end)
			end
		end
	end
end

-- Регистрация команды
function DebugService:RegisterCommand(commandName, description, callback)
	self.Commands[commandName] = {
		Description = description,
		Callback = callback,
	}
end

-- Обработка сообщений чата
function DebugService:ProcessChatMessage(player, message)
	if message:sub(1, 1) ~= "/" then
		return
	end

	-- Парсим команду и аргументы
	local parts = {}
	for part in message:gmatch("%S+") do
		table.insert(parts, part)
	end

	if #parts == 0 then
		return
	end

	local commandName = parts[1]:sub(2):lower() -- Убираем "/" и делаем lowercase
	local args = {}

	for i = 2, #parts do
		table.insert(args, parts[i])
	end

	-- Выполняем команду
	self:ExecuteCommand(player, commandName, args)
end

-- Выполнение команды
function DebugService:ExecuteCommand(player, commandName, args)
	local command = self.Commands[commandName]
	if not command then
		self:SendMessage(
			player,
			"Команда /"
				.. commandName
				.. " не найдена. Используйте /help для списка команд."
		)
		return
	end

	print("[DEBUG] " .. player.Name .. " executed command: /" .. commandName)

	local success, result = pcall(command.Callback, player, args)
	if not success then
		warn("[DEBUG] Error executing command /" .. commandName .. ": " .. tostring(result))
		self:SendMessage(player, "Ошибка выполнения команды!")
	end
end

-- Показать помощь
function DebugService:ShowHelp(player)
	self:SendMessage(player, "=== ДОСТУПНЫЕ КОМАНДЫ ===")
	for commandName, command in pairs(self.Commands) do
		self:SendMessage(player, "/" .. commandName .. " - " .. command.Description)
	end
end

-- Добавить опыт
function DebugService:AddExperience(player, amount)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService ~= nil and PlayerDataService:IsDataLoaded(player) then
		PlayerDataService:AddExperience(player, amount)
		self:SendMessage(player, "Добавлено " .. amount .. " опыта!")
	else
		self:SendMessage(player, "Данные игрока не загружены!")
	end
end

-- Установить уровень (ИСПРАВЛЕННАЯ ВЕРСИЯ)
function DebugService:SetLevel(player, level)
	local ServiceManager = require(ServerScriptService.Server.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		level = math.max(1, math.min(level, Constants.PLAYER.MAX_LEVEL))

		-- ИСПРАВЛЕНИЕ: Рассчитываем правильный опыт для уровня
		local totalExperience = 0

		-- Суммируем опыт, необходимый для достижения указанного уровня
		for currentLevel = 1, level - 1 do
			local expRequired =
				math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (currentLevel ^ Constants.EXPERIENCE.XP_MULTIPLIER))
			totalExperience = totalExperience + expRequired
		end

		-- Устанавливаем уровень и соответствующий опыт
		data.Level = level
		data.Experience = totalExperience -- Опыт в начале уровня (0 прогресса к следующему)

		-- Добавляем очки атрибутов за новые уровни (если повышаем)
		if level > 1 then
			data.AttributePoints = (level - 1) * 5 -- 5 очков за каждый уровень после первого
		else
			data.AttributePoints = 0
		end

		-- Пересчитываем ресурсы с новыми характеристиками
		PlayerDataService:InitializePlayerResources(player)

		-- Отправляем обновленные данные клиенту
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		-- Отправляем событие повышения уровня для эффектов
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.LEVEL_UP, {
			NewLevel = level,
			AttributePoints = data.AttributePoints,
		})

		self:SendMessage(
			player,
			string.format(
				"Уровень установлен на %d! Опыт: %d, Очки атрибутов: %d",
				level,
				totalExperience,
				data.AttributePoints
			)
		)

		-- Логируем для отладки
		print(
			string.format(
				"[DEBUG] %s level set to %d (XP: %d, Points: %d)",
				player.Name,
				level,
				totalExperience,
				data.AttributePoints
			)
		)
	end
end

-- Установить опыт (новый метод)
function DebugService:SetExperience(player, experience)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		experience = math.max(0, experience)

		-- Сохраняем старые значения для сравнения
		local oldLevel = data.Level
		local oldExperience = data.Experience

		-- Устанавливаем новый опыт
		data.Experience = experience

		-- Пересчитываем уровень на основе опыта
		local newLevel = 1
		local currentExp = experience

		while newLevel < Constants.PLAYER.MAX_LEVEL do
			local expRequired =
				math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (newLevel ^ Constants.EXPERIENCE.XP_MULTIPLIER))
			if currentExp < expRequired then
				break
			end
			currentExp = currentExp - expRequired
			newLevel = newLevel + 1
		end

		-- Устанавливаем новый уровень и остаток опыта
		data.Level = newLevel
		data.Experience = currentExp

		-- Пересчитываем очки атрибутов
		data.AttributePoints = math.max(0, (newLevel - 1) * 5)

		-- Пересчитываем ресурсы
		PlayerDataService:InitializePlayerResources(player)

		-- Отправляем обновленные данные
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		-- Если уровень изменился, отправляем событие
		if newLevel ~= oldLevel then
			PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.LEVEL_UP, {
				NewLevel = newLevel,
				AttributePoints = data.AttributePoints,
			})
		end

		self:SendMessage(
			player,
			string.format(
				"Опыт установлен! Уровень: %d, Опыт: %d/%d",
				newLevel,
				currentExp,
				math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (newLevel ^ Constants.EXPERIENCE.XP_MULTIPLIER))
			)
		)

		print(
			string.format(
				"[DEBUG] %s experience set: Level %d -> %d, XP %d -> %d",
				player.Name,
				oldLevel,
				newLevel,
				oldExperience,
				currentExp
			)
		)
	end
end

-- Добавить золото
function DebugService:AddGold(player, amount)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local success = PlayerDataService:AddGold(player, amount, "ADMIN_GRANT")
	if success then
		self:SendMessage(player, "Добавлено " .. amount .. " золота!")
	else
		self:SendMessage(player, "Ошибка при добавлении золота!")
	end
end

-- Показать статистику
function DebugService:ShowStats(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		self:SendMessage(player, "=== СТАТИСТИКА ===")
		self:SendMessage(player, "Уровень: " .. data.Level)
		self:SendMessage(player, "Опыт: " .. data.Experience)
		self:SendMessage(player, "Золото: " .. data.Currency.Gold)
		self:SendMessage(player, "Здоровье: " .. data.Health)
		self:SendMessage(player, "Время игры: " .. math.floor(data.Statistics.TotalPlayTime / 60) .. " мин")
	end
end

-- Восстановить здоровье
function DebugService:HealPlayer(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		local maxHealth = Constants.PLAYER.BASE_HEALTH
			+ (data.Attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
		data.Health = maxHealth
		data.Mana = Constants.PLAYER.BASE_MANA + (data.Attributes.Intelligence * Constants.PLAYER.MANA_PER_INTELLIGENCE)
		data.Stamina = Constants.PLAYER.BASE_STAMINA
			+ (data.Attributes.Constitution * Constants.PLAYER.STAMINA_PER_CONSTITUTION)

		PlayerDataService:InitializePlayerResources(player)

		self:SendMessage(player, "Здоровье восстановлено!")
	end
end

-- Показать статистику производительности
function DebugService:ShowPerformanceStats(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)

	self:SendMessage(player, "=== ПРОИЗВОДИТЕЛЬНОСТЬ ===")

	-- Статистика валидации
	local ValidationService = ServiceManager:GetService("ValidationService")
	if ValidationService then
		local stats = ValidationService:GetValidationStatistics()
		self:SendMessage(
			player,
			string.format("Валидации: %d (%.1f%% успех)", stats.TotalValidations, stats.SuccessRate)
		)
		self:SendMessage(player, string.format("Кэш: %.1f%% попаданий", stats.CacheHitRate))
	end

	-- Статистика сети
	local RemoteService = ServiceManager:GetService("RemoteService")
	if RemoteService then
		local netStats = RemoteService:GetNetworkStats()
		self:SendMessage(
			player,
			string.format(
				"События: %d, Функции: %d",
				netStats.TotalRemoteEvents,
				netStats.TotalRemoteFunctions
			)
		)
		self:SendMessage(player, string.format("Активные лимиты: %d", netStats.ActiveRateLimits))
	end

	-- Статистика игроков
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")
	if PlayerDataService then
		local playerCount = 0
		for _ in pairs(PlayerDataService.Profiles) do
			playerCount = playerCount + 1
		end
		self:SendMessage(player, string.format("Загружено профилей: %d", playerCount))
	end

	-- Память (примерно)
	self:SendMessage(player, string.format("Память: %.1f MB", collectgarbage("count") / 1024))
end

-- === МЕТОДЫ ДИАГНОСТИКИ ===

-- Диагностика опыта
function DebugService:DiagnoseExperience(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not PlayerDataService:IsDataLoaded(player) then
		self:SendMessage(player, "❌ Данные не загружены")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self:SendMessage(player, "❌ Данные недоступны")
		return
	end

	self:SendMessage(player, "=== ДИАГНОСТИКА ОПЫТА ===")
	self:SendMessage(player, string.format("Текущий уровень: %d", data.Level))
	self:SendMessage(player, string.format("Текущий опыт: %d", data.Experience))

	-- Рассчитываем правильный опыт для уровня
	local expForCurrentLevel = PlayerDataService:GetRequiredExperience(data.Level)
	self:SendMessage(player, string.format("Нужно для %d уровня: %d", data.Level, expForCurrentLevel))

	-- Рассчитываем какой уровень должен быть при текущем опыте
	local totalExp = data.Experience
	local calculatedLevel = 1
	local expUsed = 0

	-- Суммируем опыт от всех предыдущих уровней
	for level = 1, data.Level - 1 do
		local expRequired = PlayerDataService:GetRequiredExperience(level)
		expUsed = expUsed + expRequired
	end

	local totalExpShould = expUsed + data.Experience
	self:SendMessage(player, string.format("Общий опыт должен быть: %d", totalExpShould))

	-- Рассчитываем правильный уровень
	local tempExp = totalExpShould
	local correctLevel = 1

	while correctLevel < Constants.PLAYER.MAX_LEVEL do
		local expRequired = PlayerDataService:GetRequiredExperience(correctLevel)
		if tempExp < expRequired then
			break
		end
		tempExp = tempExp - expRequired
		correctLevel = correctLevel + 1
	end

	self:SendMessage(player, string.format("Правильный уровень: %d", correctLevel))
	self:SendMessage(player, string.format("Остаток опыта: %d", tempExp))

	if correctLevel ~= data.Level then
		self:SendMessage(player, "⚠️ НЕСООТВЕТСТВИЕ! Используйте /fixexp")
	else
		if data.Experience >= expForCurrentLevel then
			self:SendMessage(player, "⚠️ Слишком много опыта для уровня!")
		else
			self:SendMessage(player, "✅ Опыт в норме")
		end
	end
end

-- Исправить опыт игрока
function DebugService:FixPlayerExperience(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not PlayerDataService:IsDataLoaded(player) then
		self:SendMessage(player, "❌ Данные не загружены")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self:SendMessage(player, "❌ Данные недоступны")
		return
	end

	local oldLevel = data.Level
	local oldExp = data.Experience

	-- Вариант 1: Рассчитать правильный опыт для текущего уровня
	-- (сбросить опыт в начало уровня)
	local resetToLevelStart = function()
		data.Experience = 0
		self:SendMessage(player, string.format("Опыт сброшен к началу %d уровня", data.Level))
	end

	-- Вариант 2: Рассчитать правильный уровень для текущего опыта
	local recalculateLevel = function()
		-- Суммируем весь опыт
		local totalExp = 0
		for level = 1, oldLevel - 1 do
			totalExp = totalExp + PlayerDataService:GetRequiredExperience(level)
		end
		totalExp = totalExp + oldExp

		-- Пересчитываем уровень
		local newLevel = 1
		local remainingExp = totalExp

		while newLevel < Constants.PLAYER.MAX_LEVEL do
			local expRequired = PlayerDataService:GetRequiredExperience(newLevel)
			if remainingExp < expRequired then
				break
			end
			remainingExp = remainingExp - expRequired
			newLevel = newLevel + 1
		end

		data.Level = newLevel
		data.Experience = remainingExp
		data.AttributePoints = math.max(0, (newLevel - 1) * 5)

		self:SendMessage(player, string.format("Пересчитано: Уровень %d -> %d", oldLevel, newLevel))
		self:SendMessage(player, string.format("Опыт: %d -> %d", oldExp, remainingExp))
	end

	-- Проверяем какой вариант нужен
	local expForCurrentLevel = PlayerDataService:GetRequiredExperience(data.Level)

	if data.Experience >= expForCurrentLevel then
		-- Слишком много опыта - пересчитываем уровень
		recalculateLevel()
	else
		-- Опыт в норме, но могли быть проблемы - оставляем как есть
		self:SendMessage(player, "✅ Опыт уже в норме")
		return
	end

	-- Пересчитываем ресурсы и отправляем обновления
	PlayerDataService:InitializePlayerResources(player)
	PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

	if data.Level ~= oldLevel then
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.LEVEL_UP, {
			NewLevel = data.Level,
			AttributePoints = data.AttributePoints,
		})
	end

	self:SendMessage(player, "✅ Опыт исправлен!")
end

-- НОВЫЕ МЕТОДЫ ДЛЯ ВАЛИДАЦИИ

-- Показать статистику валидации
function DebugService:ShowValidationStats(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local ValidationService = ServiceManager:GetService("ValidationService")

	if not ValidationService then
		self:SendMessage(player, "ValidationService недоступен!")
		return
	end

	local stats = ValidationService:GetValidationStatistics()

	self:SendMessage(player, "=== СТАТИСТИКА ВАЛИДАЦИИ ===")
	self:SendMessage(player, string.format("Общих проверок: %d", stats.TotalValidations))
	self:SendMessage(player, string.format("Успешных: %d", stats.PassedValidations))
	self:SendMessage(player, string.format("Неудачных: %d", stats.FailedValidations))
	self:SendMessage(player, string.format("Успешность: %.2f%%", stats.SuccessRate))
	self:SendMessage(
		player,
		string.format("Попаданий в кэш: %d (%.2f%%)", stats.CacheHits, stats.CacheHitRate)
	)
	self:SendMessage(player, string.format("Время работы: %.2f часов", stats.UptimeHours))

	-- Показываем самые частые ошибки
	if next(stats.MostCommonErrors) then
		self:SendMessage(player, "Частые ошибки:")
		for errorCode, count in pairs(stats.MostCommonErrors) do
			self:SendMessage(player, string.format("  %s: %d раз", errorCode, count))
		end
	end
end

-- Тестирование валидации
function DebugService:TestValidation(player, testType)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local ValidationService = ServiceManager:GetService("ValidationService")
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not ValidationService then
		self:SendMessage(player, "ValidationService недоступен!")
		return
	end

	self:SendMessage(player, "Запуск тестов валидации...")

	if testType == "player" then
		-- Тест валидации данных игрока
		local data = PlayerDataService:GetData(player)
		if data then
			local result = ValidationService:ValidatePlayerData(data, player.UserId)
			if result.IsValid then
				self:SendMessage(player, "✅ Данные игрока прошли валидацию")
			else
				self:SendMessage(player, "❌ Ошибка валидации: " .. (result.ErrorMessage or "Unknown"))
			end
		else
			self:SendMessage(player, "❌ Данные игрока не загружены")
		end
	elseif testType == "exp" then
		-- Тест валидации опыта
		local result = ValidationService:ValidateExperienceChange(100, 50, player.UserId)
		if result.IsValid then
			self:SendMessage(player, "✅ Валидация опыта пройдена")
		else
			self:SendMessage(
				player,
				"❌ Ошибка валидации опыта: " .. (result.ErrorMessage or "Unknown")
			)
		end

		-- Тест недопустимого опыта
		local badResult = ValidationService:ValidateExperienceChange(100, 100000, player.UserId)
		if not badResult.IsValid then
			self:SendMessage(player, "✅ Большой опыт корректно отклонен")
		else
			self:SendMessage(player, "❌ Большой опыт не был отклонен!")
		end
	elseif testType == "gold" then
		-- Тест валидации золота
		local result = ValidationService:ValidateGoldTransaction(1000, -500, "ITEM_PURCHASE", player.UserId)
		if result.IsValid then
			self:SendMessage(player, "✅ Валидация золота пройдена")
		else
			self:SendMessage(
				player,
				"❌ Ошибка валидации золота: " .. (result.ErrorMessage or "Unknown")
			)
		end

		-- Тест недостатка золота
		local poorResult = ValidationService:ValidateGoldTransaction(100, -500, "ITEM_PURCHASE", player.UserId)
		if not poorResult.IsValid then
			self:SendMessage(player, "✅ Недостаток золота корректно отклонен")
		else
			self:SendMessage(player, "❌ Недостаток золота не был отклонен!")
		end
	elseif testType == "stress" then
		-- Стресс-тест валидации
		self:SendMessage(player, "Запуск стресс-теста (1000 валидаций)...")

		local startTime = tick()
		local passedTests = 0

		for _ = 1, 1000 do
			local testData = {
				Level = math.random(1, 100),
				Experience = math.random(0, 1000000),
				Attributes = {
					Strength = math.random(10, 100),
					Dexterity = math.random(10, 100),
					Intelligence = math.random(10, 100),
					Constitution = math.random(10, 100),
					Focus = math.random(10, 100),
				},
				Currency = { Gold = math.random(0, 100000) },
				Statistics = {
					TotalPlayTime = math.random(0, 86400),
					MobsKilled = math.random(0, 1000),
					QuestsCompleted = math.random(0, 100),
					ItemsCrafted = math.random(0, 500),
					Deaths = math.random(0, 50),
					DamageDealt = 0,
					DamageTaken = 0,
					DistanceTraveled = 0,
				},
				Equipment = {
					MainHand = nil,
					OffHand = nil,
					Helmet = nil,
					Chest = nil,
					Legs = nil,
					Boots = nil,
					Ring1 = nil,
					Ring2 = nil,
					Amulet = nil,
				},
				Inventory = {},
				WeaponMastery = {
					Sword = { Level = 1, Experience = 0 },
					Axe = { Level = 1, Experience = 0 },
					Bow = { Level = 1, Experience = 0 },
					Staff = { Level = 1, Experience = 0 },
					Spear = { Level = 1, Experience = 0 },
				},
				Settings = {
					MusicVolume = 0.5,
					SFXVolume = 0.7,
					ShowDamageNumbers = true,
					AutoPickupItems = true,
					ChatFilter = true,
					ShowPlayerNames = true,
				},
				AttributePoints = 0,
				Health = math.random(50, 200),
				Mana = math.random(20, 100),
				Stamina = math.random(50, 150),
				LastLogin = os.time(),
			}

			local result = ValidationService:ValidatePlayerData(testData, player.UserId)
			if result.IsValid then
				passedTests = passedTests + 1
			end
		end

		local endTime = tick()
		local duration = (endTime - startTime) * 1000

		self:SendMessage(player, string.format("Стресс-тест завершен за %.2f мс", duration))
		self:SendMessage(player, string.format("Прошло: %d/1000 тестов", passedTests))
		self:SendMessage(player, string.format("Среднее время: %.3f мс/тест", duration / 1000))
	else
		self:SendMessage(player, "Доступные типы тестов: player, exp, gold, stress")
	end
end

-- Сброс статистики валидации
function DebugService:ResetValidationStats(player)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local ValidationService = ServiceManager:GetService("ValidationService")

	if not ValidationService then
		self:SendMessage(player, "ValidationService недоступен!")
		return
	end

	ValidationService:ResetStatistics()
	self:SendMessage(player, "Статистика валидации сброшена!")
end

-- Отправить сообщение игроку
function DebugService:SendMessage(player, message)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local RemoteService = ServiceManager:GetService("RemoteService")

	if RemoteService ~= nil and RemoteService:IsReady() then
		RemoteService:SendSystemMessage(player, message, "INFO")
	else
		-- Fallback - отправляем через старую систему чата
		print("[DEBUG MESSAGE TO " .. player.Name .. "] " .. message)
	end
end

return DebugService
