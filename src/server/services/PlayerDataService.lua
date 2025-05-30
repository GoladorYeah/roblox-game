-- src/server/services/PlayerDataService.lua
-- Сервис для управления данными игроков с использованием ProfileService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)
local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)

local PlayerDataService = setmetatable({}, { __index = BaseService })
PlayerDataService.__index = PlayerDataService

-- Профиль по умолчанию
local DefaultProfile = {
	-- Основная информация
	Level = Constants.PLAYER.START_LEVEL,
	Experience = Constants.PLAYER.START_EXPERIENCE,

	-- Характеристики
	Attributes = {
		Strength = Constants.PLAYER.BASE_ATTRIBUTES.Strength,
		Dexterity = Constants.PLAYER.BASE_ATTRIBUTES.Dexterity,
		Intelligence = Constants.PLAYER.BASE_ATTRIBUTES.Intelligence,
		Constitution = Constants.PLAYER.BASE_ATTRIBUTES.Constitution,
		Focus = Constants.PLAYER.BASE_ATTRIBUTES.Focus,
	},

	-- Доступные очки характеристик
	AttributePoints = 0,

	-- Ресурсы
	Health = Constants.PLAYER.BASE_HEALTH,
	Mana = Constants.PLAYER.BASE_MANA,
	Stamina = Constants.PLAYER.BASE_STAMINA,

	-- Инвентарь
	Inventory = {},
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

	-- Валюта
	Currency = {
		Gold = Constants.PLAYER.START_GOLD,
	},

	-- Статистика
	Statistics = {
		TotalPlayTime = 0,
		MobsKilled = 0,
		QuestsCompleted = 0,
		ItemsCrafted = 0,
		Deaths = 0,
	},

	-- Мастерство оружия
	WeaponMastery = {
		Sword = { Level = 1, Experience = 0 },
		Axe = { Level = 1, Experience = 0 },
		Bow = { Level = 1, Experience = 0 },
		Staff = { Level = 1, Experience = 0 },
		Spear = { Level = 1, Experience = 0 },
	},

	-- Настройки
	Settings = {
		MusicVolume = 0.5,
		SFXVolume = 0.7,
		ShowDamageNumbers = true,
		AutoPickupItems = true,
	},

	-- Дата последнего входа
	LastLogin = os.time(),
}

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

	-- Обновление времени игры каждую секунду
	self:ConnectEvent(RunService.Heartbeat, function()
		for player, profile in pairs(self.Profiles) do
			if profile and profile.Data then
				profile.Data.Statistics.TotalPlayTime = profile.Data.Statistics.TotalPlayTime + 1 / 60 -- Добавляем время в секундах
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
			self:FireClient(player, "PlayerDataLoaded", profile.Data)

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
	return profile and profile.Data
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

	-- Уведомляем клиент об изменении ресурсов
	self:FireClient(player, "PlayerStatsChanged", {
		Health = data.Health,
		MaxHealth = maxHealth,
		Mana = data.Mana,
		MaxMana = maxMana,
		Stamina = data.Stamina,
		MaxStamina = maxStamina,
	})
end

-- Добавить опыт игроку
function PlayerDataService:AddExperience(player, amount)
	local data = self:GetData(player)
	if not data then
		return
	end

	data.Experience = data.Experience + amount

	-- Проверяем повышение уровня
	local requiredXP = self:GetRequiredExperience(data.Level)
	while data.Experience >= requiredXP and data.Level < Constants.PLAYER.MAX_LEVEL do
		data.Experience = data.Experience - requiredXP
		data.Level = data.Level + 1
		data.AttributePoints = data.AttributePoints + 5 -- 5 очков за уровень

		-- Уведомляем о повышении уровня
		self:FireClient(player, "LevelUp", {
			NewLevel = data.Level,
			AttributePoints = data.AttributePoints,
		})

		requiredXP = self:GetRequiredExperience(data.Level)
	end

	-- Уведомляем об изменении опыта
	self:FireClient(player, "ExperienceChanged", {
		Experience = data.Experience,
		Level = data.Level,
		RequiredXP = requiredXP,
	})
end

-- Рассчитать необходимый опыт для уровня
function PlayerDataService:GetRequiredExperience(level)
	return math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (level ^ Constants.EXPERIENCE.XP_MULTIPLIER))
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
	print("  Gold: " .. data.Currency.Gold)
	print("  Health: " .. data.Health)
	print("  Play Time: " .. math.floor(data.Statistics.TotalPlayTime / 60) .. " minutes")
	print("  Last Login: " .. os.date("%Y-%m-%d %H:%M:%S", data.LastLogin))
end

-- Событие для отправки данных клиенту
function PlayerDataService:FireClient(player, eventName, data)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local RemoteService = ServiceManager:GetService("RemoteService")

	if RemoteService and RemoteService:IsReady() then
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
		end
	end

	self.Profiles = {}
	self.LoadedProfiles = {}
end

return PlayerDataService
