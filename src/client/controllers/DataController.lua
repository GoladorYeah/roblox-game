-- src/client/controllers/DataController.lua
-- Клиентский контроллер для управления данными игрока

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseController = require(ReplicatedStorage.Shared.BaseController)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local DataController = setmetatable({}, { __index = BaseController })
DataController.__index = DataController

function DataController.new()
	local self = setmetatable(BaseController.new("DataController"), DataController)

	self.LocalPlayer = Players.LocalPlayer
	self.PlayerData = nil
	self.DataLoadedCallbacks = {}

	-- События
	self.DataLoaded = Instance.new("BindableEvent")
	self.StatsChanged = Instance.new("BindableEvent")
	self.ExperienceChanged = Instance.new("BindableEvent")
	self.LevelUp = Instance.new("BindableEvent")

	return self
end

function DataController:OnInitialize()
	-- Ждем загрузки RemoteEvents
	ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Подключаем обработчики событий от сервера
	self:ConnectServerEvents()
end

function DataController:OnStart()
	print("[DATA CONTROLLER] Waiting for player data...")
end

-- Подключение событий от сервера
function DataController:ConnectServerEvents()
	local remoteEvents = ReplicatedStorage.RemoteEvents

	-- Загрузка данных игрока
	local playerDataLoaded = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED)
	self:ConnectEvent(playerDataLoaded.OnClientEvent, function(data)
		self:OnPlayerDataLoaded(data)
	end)

	-- Изменение статов
	local playerStatsChanged = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.PLAYER_STATS_CHANGED)
	self:ConnectEvent(playerStatsChanged.OnClientEvent, function(stats)
		self:OnStatsChanged(stats)
	end)

	-- Системные сообщения
	local systemMessage = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.SYSTEM_MESSAGE)
	self:ConnectEvent(systemMessage.OnClientEvent, function(messageData)
		self:OnSystemMessage(messageData)
	end)
end

-- Обработка загрузки данных игрока
function DataController:OnPlayerDataLoaded(data)
	print("[DATA CONTROLLER] Player data loaded!")

	self.PlayerData = data

	-- Вызываем все отложенные callbacks
	for _, callback in ipairs(self.DataLoadedCallbacks) do
		spawn(function()
			callback(data)
		end)
	end
	self.DataLoadedCallbacks = {}

	-- Уведомляем о загрузке данных
	self.DataLoaded:Fire(data)

	self:PrintPlayerInfo()
end

-- Обработка изменения статов
function DataController:OnStatsChanged(stats)
	print("[DATA CONTROLLER] Stats changed: Health=" .. stats.Health .. "/" .. stats.MaxHealth)

	-- Обновляем локальные данные если они загружены
	if self.PlayerData then
		self.PlayerData.Health = stats.Health
		self.PlayerData.Mana = stats.Mana
		self.PlayerData.Stamina = stats.Stamina
	end

	-- Уведомляем об изменении статов
	self.StatsChanged:Fire(stats)
end

-- Обработка системных сообщений
function DataController:OnSystemMessage(messageData)
	print("[SYSTEM] " .. messageData.Message)

	-- Здесь можно добавить обработку для UI уведомлений
end

-- Получить данные игрока
function DataController:GetPlayerData()
	return self.PlayerData
end

-- Проверить, загружены ли данные
function DataController:IsDataLoaded()
	return self.PlayerData ~= nil
end

-- Выполнить функцию после загрузки данных
function DataController:WhenDataLoaded(callback)
	if self.PlayerData then
		callback(self.PlayerData)
	else
		table.insert(self.DataLoadedCallbacks, callback)
	end
end

-- Получить уровень игрока
function DataController:GetLevel()
	return self.PlayerData and self.PlayerData.Level or 1
end

-- Получить опыт игрока
function DataController:GetExperience()
	return self.PlayerData and self.PlayerData.Experience or 0
end

-- Получить характеристики игрока
function DataController:GetAttributes()
	return self.PlayerData and self.PlayerData.Attributes or Constants.PLAYER.BASE_ATTRIBUTES
end

-- Получить золото игрока
function DataController:GetGold()
	return self.PlayerData and self.PlayerData.Currency.Gold or 0
end

-- Получить статистику игрока
function DataController:GetStatistics()
	return self.PlayerData and self.PlayerData.Statistics or {}
end

-- Получить мастерство оружия
function DataController:GetWeaponMastery(weaponType)
	if not self.PlayerData or not self.PlayerData.WeaponMastery then
		return { Level = 1, Experience = 0 }
	end

	return self.PlayerData.WeaponMastery[weaponType] or { Level = 1, Experience = 0 }
end

-- Рассчитать максимальное здоровье
function DataController:GetMaxHealth()
	local attributes = self:GetAttributes()
	return Constants.PLAYER.BASE_HEALTH + (attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
end

-- Рассчитать максимальную ману
function DataController:GetMaxMana()
	local attributes = self:GetAttributes()
	return Constants.PLAYER.BASE_MANA + (attributes.Intelligence * Constants.PLAYER.MANA_PER_INTELLIGENCE)
end

-- Рассчитать максимальную выносливость
function DataController:GetMaxStamina()
	local attributes = self:GetAttributes()
	return Constants.PLAYER.BASE_STAMINA + (attributes.Constitution * Constants.PLAYER.STAMINA_PER_CONSTITUTION)
end

-- Рассчитать необходимый опыт для следующего уровня
function DataController:GetRequiredExperience(level)
	level = level or self:GetLevel()
	return math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (level ^ Constants.EXPERIENCE.XP_MULTIPLIER))
end

-- Рассчитать прогресс опыта в процентах
function DataController:GetExperienceProgress()
	local currentXP = self:GetExperience()
	local requiredXP = self:GetRequiredExperience()

	if requiredXP == 0 then
		return 100
	end

	return math.min((currentXP / requiredXP) * 100, 100)
end

-- Вывести информацию об игроке в консоль
function DataController:PrintPlayerInfo()
	if not self.PlayerData then
		print("[DATA CONTROLLER] No player data available")
		return
	end

	local data = self.PlayerData

	print("=== PLAYER INFO ===")
	print("Level: " .. data.Level)
	print("Experience: " .. data.Experience .. "/" .. self:GetRequiredExperience())
	print("Gold: " .. data.Currency.Gold)

	print("Attributes:")
	for attr, value in pairs(data.Attributes) do
		print("  " .. attr .. ": " .. value)
	end

	print("Resources:")
	print("  Health: " .. data.Health .. "/" .. self:GetMaxHealth())
	print("  Mana: " .. data.Mana .. "/" .. self:GetMaxMana())
	print("  Stamina: " .. data.Stamina .. "/" .. self:GetMaxStamina())

	print("Play Time: " .. math.floor(data.Statistics.TotalPlayTime / 60) .. " minutes")
	print("==================")
end

function DataController:OnCleanup()
	-- Очищаем события
	if self.DataLoaded then
		self.DataLoaded:Destroy()
	end
	if self.StatsChanged then
		self.StatsChanged:Destroy()
	end
	if self.ExperienceChanged then
		self.ExperienceChanged:Destroy()
	end
	if self.LevelUp then
		self.LevelUp:Destroy()
	end

	self.PlayerData = nil
	self.DataLoadedCallbacks = {}
end

return DataController
