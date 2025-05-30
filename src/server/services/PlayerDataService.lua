-- src/server/services/PlayerDataService.lua
-- ИСПРАВЛЕННАЯ ВЕРСИЯ - Опыт теперь корректно обрабатывается

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)
local PlayerTypes = require(ReplicatedStorage.Shared.types.PlayerTypes)
local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)

local PlayerDataService = setmetatable({}, { __index = BaseService })
PlayerDataService.__index = PlayerDataService

-- Используем типизированный профиль по умолчанию
local DefaultProfile = PlayerTypes.CreateDefaultProfile()

function PlayerDataService.new()
	local self = setmetatable(BaseService.new("PlayerDataService"), PlayerDataService)

	self.ProfileStore = nil
	self.Profiles = {} -- [Player] = Profile
	self.LoadedProfiles = {} -- [Player] = true/false

	return self
end

function PlayerDataService:OnInitialize()
	-- Создаем ProfileStore с новым API
	self.ProfileStore = ProfileService.GetProfileStore(
		"PlayerData", -- Имя хранилища
		DefaultProfile -- Профиль по умолчанию
	)

	-- Подключаем события игроков
	self:ConnectEvent(Players.PlayerAdded, function(player)
		self:LoadPlayerData(player)
	end)

	self:ConnectEvent(Players.PlayerRemoving, function(player)
		self:SavePlayerData(player)
	end)

	-- Загружаем данные для уже подключенных игроков
	for _, player in ipairs(Players:GetPlayers()) do
		spawn(function()
			self:LoadPlayerData(player)
		end)
	end
end

function PlayerDataService:OnStart()
	-- Проверяем версию ProfileService
	print("[PLAYER DATA] ProfileService version: " .. (ProfileService.ServiceLocked and "etheroit" or "legacy"))

	-- Автосохранение каждые 5 минут
	spawn(function()
		while true do
			wait(300) -- 5 минут
			self:SaveAllPlayerData()
		end
	end)

	-- Обновление времени игры каждую секунду (БЕЗ СПАМ ЛОГОВ)
	self:ConnectEvent(RunService.Heartbeat, function()
		for _, profile in pairs(self.Profiles) do
			if profile and profile.Data then
				profile.Data.Statistics.TotalPlayTime = profile.Data.Statistics.TotalPlayTime + 1 / 60
			end
		end
	end)
end

-- Загрузка данных игрока
function PlayerDataService:LoadPlayerData(player)
	print("[PLAYER DATA] Loading data for " .. player.Name)

	local profileKey = "Player_" .. player.UserId
	local profile = self.ProfileStore:LoadProfileAsync(profileKey)

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- Соответствие GDPR
		profile:Reconcile() -- Добавляет недостающие поля из DefaultProfile

		-- НОВОЕ: Проверяем и исправляем опыт при загрузке
		self:ValidateAndFixExperience(profile.Data, player.Name)

		-- НОВОЕ: Валидация загруженных данных (ПОСЛЕ исправления опыта)
		local ServiceManager = require(script.Parent.Parent.ServiceManager)
		local ValidationService = ServiceManager:GetService("ValidationService")

		if ValidationService then
			local validationResult = ValidationService:ValidatePlayerData(profile.Data, player.UserId)
			if not validationResult.IsValid then
				warn(string.format("[PLAYER DATA] Invalid data for %s: %s", player.Name, validationResult.ErrorMessage))

				-- Сбрасываем на дефолтный профиль при критических ошибках
				if
					validationResult.ErrorCode == "MISSING_REQUIRED_FIELD"
					or validationResult.ErrorCode == "INVALID_TYPE"
				then
					warn("[PLAYER DATA] Resetting to default profile due to critical data corruption")
					profile.Data = PlayerTypes.CreateDefaultProfile()
				end
			else
				print("[PLAYER DATA] Data validation passed for " .. player.Name)
			end
		end

		profile:ListenToRelease(function()
			self.Profiles[player] = nil
			-- Более мягкое отключение
			if player.Parent == Players then
				player:Kick(
					"Данные освобождены. Переподключитесь через несколько секунд."
				)
			end
		end)

		if player.Parent == Players then
			self.Profiles[player] = profile
			self.LoadedProfiles[player] = true

			print("[PLAYER DATA] Successfully loaded data for " .. player.Name)
			print("[PLAYER DATA] Profile version: " .. (profile.GlobalUpdates and "New API" or "Legacy API"))

			-- Обновляем последний вход
			profile.Data.LastLogin = os.time()

			-- Уведомляем клиент о загрузке данных
			self:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, profile.Data)

			-- Инициализируем здоровье и ресурсы
			self:InitializePlayerResources(player)

			-- Выводим информацию о данных игрока
			self:PrintPlayerData(player)
		else
			profile:Release()
		end
	else
		warn("[PLAYER DATA] Failed to load profile for " .. player.Name)
		player:Kick(
			"Не удалось загрузить данные игрока. Попробуйте переподключиться."
		)
	end
end

-- НОВАЯ ФУНКЦИЯ: Проверка и исправление опыта
function PlayerDataService:ValidateAndFixExperience(data, playerName)
	-- Рассчитываем какой уровень должен быть при текущем опыте
	local calculatedLevel = self:CalculateLevelFromCurrentExperience(data.Experience)

	if calculatedLevel ~= data.Level then
		warn(
			string.format(
				"[PLAYER DATA] Experience mismatch for %s: Level %d with %d XP (should be level %d)",
				playerName,
				data.Level,
				data.Experience,
				calculatedLevel
			)
		)

		-- ИСПРАВЛЯЕМ: Конвертируем в правильную систему
		-- Вариант 1: Сохраняем уровень, корректируем опыт (БЕЗОПАСНЕЕ)
		data.Experience = 0 -- Сбрасываем к началу текущего уровня
		warn(string.format("[PLAYER DATA] Reset experience to 0 for level %d", data.Level))

		-- Вариант 2: Если хотим сохранить опыт и пересчитать уровень, раскомментируйте:
		-- data.Level = calculatedLevel
		-- warn(string.format("[PLAYER DATA] Corrected level to %d for %d XP", calculatedLevel, data.Experience))
	end

	-- Проверяем, что опыт не превышает требуемый для следующего уровня
	local requiredForNext = self:GetRequiredExperience(data.Level)
	if data.Experience >= requiredForNext then
		warn(
			string.format(
				"[PLAYER DATA] %s has too much XP for level %d (%d/%d), fixing...",
				playerName,
				data.Level,
				data.Experience,
				requiredForNext
			)
		)

		-- Автоматически повышаем уровень
		while data.Experience >= requiredForNext and data.Level < Constants.PLAYER.MAX_LEVEL do
			data.Experience = data.Experience - requiredForNext
			data.Level = data.Level + 1
			data.AttributePoints = data.AttributePoints + 5

			print(string.format("[PLAYER DATA] Auto level up for %s: Level %d", playerName, data.Level))

			requiredForNext = self:GetRequiredExperience(data.Level)
		end
	end
end

-- НОВАЯ ФУНКЦИЯ: Рассчитать уровень из ТЕКУЩЕГО опыта (не общего)
function PlayerDataService:CalculateLevelFromCurrentExperience(currentExperience)
	-- Если опыт отрицательный или 0, это уровень 1
	if currentExperience <= 0 then
		return 1
	end

	-- Ищем минимальный уровень, для которого требуется больше опыта чем у нас есть
	local level = 1
	while level < Constants.PLAYER.MAX_LEVEL do
		local requiredXP = self:GetRequiredExperience(level)
		if currentExperience < requiredXP then
			return level
		end
		level = level + 1
	end

	return Constants.PLAYER.MAX_LEVEL
end

-- Сохранение данных игрока
function PlayerDataService:SavePlayerData(player)
	local profile = self.Profiles[player]
	if profile then
		print("[PLAYER DATA] Saving data for " .. player.Name)

		-- Безопасное сохранение с обработкой ошибок
		local success, errorMessage = pcall(function()
			profile:Release()
		end)

		if success then
			print("[PLAYER DATA] Successfully saved data for " .. player.Name)
		else
			warn("[PLAYER DATA] Error saving data for " .. player.Name .. ": " .. tostring(errorMessage))
		end

		self.Profiles[player] = nil
		self.LoadedProfiles[player] = nil
	end
end

-- Сохранение данных всех игроков
function PlayerDataService:SaveAllPlayerData()
	print("[PLAYER DATA] Auto-saving all player data...")
	for player, _ in pairs(self.Profiles) do
		if player.Parent == Players then
			print("[PLAYER DATA] Auto-saved data for " .. player.Name)
		end
	end
end

-- Получить профиль игрока
function PlayerDataService:GetProfile(player)
	return self.Profiles[player]
end

-- Получить данные игрока
function PlayerDataService:GetData(player)
	local profile = self:GetProfile(player)
	return (profile and profile.Data) or nil
end

-- Проверить, загружены ли данные игрока
function PlayerDataService:IsDataLoaded(player)
	return self.LoadedProfiles[player] == true
end

-- Инициализация ресурсов игрока (здоровье, мана, стамина)
function PlayerDataService:InitializePlayerResources(player)
	local data = self:GetData(player)
	if not data then
		return
	end

	-- Рассчитываем максимальные значения на основе характеристик
	local maxHealth = Constants.PLAYER.BASE_HEALTH
		+ (data.Attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
	local maxMana = Constants.PLAYER.BASE_MANA + (data.Attributes.Intelligence * Constants.PLAYER.MANA_PER_INTELLIGENCE)
	local maxStamina = Constants.PLAYER.BASE_STAMINA
		+ (data.Attributes.Constitution * Constants.PLAYER.STAMINA_PER_CONSTITUTION)

	-- Устанавливаем текущие значения (при первом входе - максимальные)
	if data.Health <= 0 then
		data.Health = maxHealth
	end

	data.Health = math.min(data.Health, maxHealth)
	data.Mana = math.min(data.Mana, maxMana)
	data.Stamina = math.min(data.Stamina, maxStamina)

	-- ДОБАВЛЯЕМ максимальные значения в данные для синхронизации
	data.MaxHealth = maxHealth
	data.MaxMana = maxMana
	data.MaxStamina = maxStamina

	-- Уведомляем клиент об изменении ресурсов
	self:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_STATS_CHANGED, {
		Health = data.Health,
		MaxHealth = maxHealth,
		Mana = data.Mana,
		MaxMana = maxMana,
		Stamina = data.Stamina,
		MaxStamina = maxStamina,
	})

	-- ТАКЖЕ отправляем обновленные полные данные
	self:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)
end

-- ИСПРАВЛЕННАЯ ФУНКЦИЯ: Добавить опыт игроку
function PlayerDataService:AddExperience(player, amount)
	local data = self:GetData(player)
	if not data then
		return
	end

	-- НОВОЕ: Валидация изменения опыта
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local ValidationService = ServiceManager:GetService("ValidationService")

	if ValidationService then
		local validationResult = ValidationService:ValidateExperienceChange(data.Experience, amount, player.UserId)
		if not validationResult.IsValid then
			warn(
				string.format(
					"[PLAYER DATA] Invalid experience change for %s: %s",
					player.Name,
					validationResult.ErrorMessage
				)
			)
			return
		end
	end

	-- ИСПРАВЛЕНО: Правильно добавляем опыт
	data.Experience = data.Experience + amount

	-- ИСПРАВЛЕНО: Проверяем повышение уровня БЕЗ вычитания опыта
	local requiredXP = self:GetRequiredExperience(data.Level)
	local levelsGained = 0

	while data.Experience >= requiredXP and data.Level < Constants.PLAYER.MAX_LEVEL do
		-- ИСПРАВЛЕНО: Вычитаем только ЗАТРАЧЕННЫЙ опыт
		data.Experience = data.Experience - requiredXP
		data.Level = data.Level + 1
		data.AttributePoints = data.AttributePoints + 5 -- 5 очков за уровень
		levelsGained = levelsGained + 1

		print(
			string.format(
				"[PLAYER DATA] %s leveled up to %d! Remaining XP: %d",
				player.Name,
				data.Level,
				data.Experience
			)
		)

		-- НОВОЕ: Валидация изменения уровня
		if ValidationService then
			local levelValidation = ValidationService:ValidateLevelChange(data.Level - 1, data.Level, player.UserId)
			if not levelValidation.IsValid then
				warn(
					string.format(
						"[PLAYER DATA] Invalid level change for %s: %s",
						player.Name,
						levelValidation.ErrorMessage
					)
				)
				-- Откатываем изменения
				data.Level = data.Level - 1
				data.Experience = data.Experience + requiredXP
				data.AttributePoints = data.AttributePoints - 5
				break
			end
		end

		-- Уведомляем о повышении уровня
		self:FireClient(player, Constants.REMOTE_EVENTS.LEVEL_UP, {
			NewLevel = data.Level,
			AttributePoints = data.AttributePoints,
		})

		-- Получаем требуемый опыт для СЛЕДУЮЩЕГО уровня
		requiredXP = self:GetRequiredExperience(data.Level)
	end

	-- Уведомляем об изменении опыта
	self:FireClient(player, Constants.REMOTE_EVENTS.EXPERIENCE_CHANGED, {
		Experience = data.Experience,
		Level = data.Level,
		RequiredXP = requiredXP,
	})

	if levelsGained > 0 then
		print(string.format("[PLAYER DATA] %s gained %d levels and %d experience", player.Name, levelsGained, amount))
	else
		print(
			string.format(
				"[PLAYER DATA] %s gained %d experience (%d/%d for level %d)",
				player.Name,
				amount,
				data.Experience,
				requiredXP,
				data.Level + 1
			)
		)
	end
end

-- Рассчитать необходимый опыт для уровня
function PlayerDataService:GetRequiredExperience(level)
	return math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (level ^ Constants.EXPERIENCE.XP_MULTIPLIER))
end

-- ИСПРАВЛЕННАЯ ФУНКЦИЯ: Получить общий накопленный опыт игрока
function PlayerDataService:GetTotalExperience(player)
	local data = self:GetData(player)
	if not data then
		return 0
	end

	-- Суммируем весь опыт от предыдущих уровней + текущий остаток
	local totalExp = data.Experience -- Остаток для текущего уровня

	-- Добавляем опыт от всех предыдущих уровней
	for level = 1, data.Level - 1 do
		totalExp = totalExp + self:GetRequiredExperience(level)
	end

	return totalExp
end

-- Новый метод для валидации транзакций золота:
function PlayerDataService:AddGold(player, amount, transactionType)
	local data = self:GetData(player)
	if not data then
		return false
	end

	transactionType = transactionType or "UNKNOWN"

	-- Валидация транзакции золота
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local ValidationService = ServiceManager:GetService("ValidationService")

	if ValidationService then
		local validationResult =
			ValidationService:ValidateGoldTransaction(data.Currency.Gold, amount, transactionType, player.UserId)

		if not validationResult.IsValid then
			warn(
				string.format(
					"[PLAYER DATA] Invalid gold transaction for %s: %s",
					player.Name,
					validationResult.ErrorMessage
				)
			)
			return false
		end
	end

	local oldGold = data.Currency.Gold
	data.Currency.Gold = data.Currency.Gold + amount

	-- Уведомляем клиент об изменении данных
	self:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

	print(
		string.format(
			"[PLAYER DATA] %s %s %d gold (%d -> %d)",
			player.Name,
			amount > 0 and "gained" or "spent",
			math.abs(amount),
			oldGold,
			data.Currency.Gold
		)
	)

	return true
end

-- Новый метод для изменения характеристик с валидацией:
function PlayerDataService:ModifyAttributes(player, attributeChanges)
	local data = self:GetData(player)
	if not data then
		return false
	end

	-- Создаем копию атрибутов для проверки
	local newAttributes = {}
	for attr, value in pairs(data.Attributes) do
		newAttributes[attr] = value + (attributeChanges[attr] or 0)
	end

	-- Валидация новых атрибутов
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local ValidationService = ServiceManager:GetService("ValidationService")

	if ValidationService then
		local validationResult = ValidationUtils.ValidatePlayerAttributes(newAttributes)
		if not validationResult.IsValid then
			warn(
				string.format(
					"[PLAYER DATA] Invalid attribute change for %s: %s",
					player.Name,
					validationResult.ErrorMessage
				)
			)
			return false
		end
	end

	-- Применяем изменения
	local totalPointsUsed = 0
	for attr, change in pairs(attributeChanges) do
		if data.Attributes[attr] then
			data.Attributes[attr] = data.Attributes[attr] + change
			totalPointsUsed = totalPointsUsed + math.abs(change)
		end
	end

	-- Списываем очки атрибутов
	if totalPointsUsed > 0 then
		data.AttributePoints = math.max(0, data.AttributePoints - totalPointsUsed)
	end

	-- Пересчитываем ресурсы
	self:InitializePlayerResources(player)

	-- Уведомляем клиент
	self:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

	print(string.format("[PLAYER DATA] %s modified attributes, used %d points", player.Name, totalPointsUsed))
	return true
end

-- Вывести информацию о данных игрока
function PlayerDataService:PrintPlayerData(player)
	local data = self:GetData(player)
	if not data then
		return
	end

	print("[PLAYER DATA] === " .. player.Name .. " ===")
	print("  Level: " .. data.Level)
	print("  Experience: " .. data.Experience .. "/" .. self:GetRequiredExperience(data.Level))
	print("  Total Experience: " .. self:GetTotalExperience(player)) -- НОВОЕ: показываем общий опыт
	print("  Gold: " .. data.Currency.Gold)
	print("  Health: " .. data.Health)
	print("  Play Time: " .. math.floor(data.Statistics.TotalPlayTime / 60) .. " minutes")
	print("  Last Login: " .. os.date("%Y-%m-%d %H:%M:%S", data.LastLogin))
end

-- Событие для отправки данных клиенту
function PlayerDataService:FireClient(player, eventName, data)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local RemoteService = ServiceManager:GetService("RemoteService")

	if RemoteService ~= nil and RemoteService:IsReady() then
		RemoteService:FireClient(player, eventName, data)
	else
		print("[PLAYER DATA] RemoteService not ready, queuing: " .. eventName .. " for " .. player.Name)
	end
end

function PlayerDataService:OnCleanup()
	-- Сохраняем данные всех игроков перед закрытием
	for player, profile in pairs(self.Profiles) do
		if profile then
			profile:Release()
			print("[PLAYER DATA] Released profile for: " .. player.Name)
		end
	end

	self.Profiles = {}
	self.LoadedProfiles = {}
end

return PlayerDataService
