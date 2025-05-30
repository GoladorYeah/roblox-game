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

	-- Повышение уровня
	local levelUp = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.LEVEL_UP)
	self:ConnectEvent(levelUp.OnClientEvent, function(levelData)
		self:OnLevelUp(levelData)
	end)

	-- Изменение опыта
	local experienceChanged = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.EXPERIENCE_CHANGED)
	self:ConnectEvent(experienceChanged.OnClientEvent, function(xpData)
		self:OnExperienceChanged(xpData)
	end)

	-- Системные сообщения
	local systemMessage = remoteEvents:WaitForChild(Constants.REMOTE_EVENTS.SYSTEM_MESSAGE)
	self:ConnectEvent(systemMessage.OnClientEvent, function(messageData)
		self:OnSystemMessage(messageData)
	end)
end

-- Обработка загрузки данных игрока
function DataController:OnPlayerDataLoaded(data)
	print("[DATA CONTROLLER] Player data loaded/updated!")

	local isFirstLoad = self.PlayerData == nil
	self.PlayerData = data

	-- Вызываем callbacks только при ПЕРВОЙ загрузке
	if isFirstLoad and #self.DataLoadedCallbacks > 0 then
		for _, callback in ipairs(self.DataLoadedCallbacks) do
			spawn(function()
				callback(data)
			end)
		end
		self.DataLoadedCallbacks = {}

		-- Уведомляем о загрузке данных только при первой загрузке
		self.DataLoaded:Fire(data)
		self:PrintPlayerInfo()
	end

	-- Обновляем UI ТОЛЬКО если это первая загрузка или значительное изменение
	if isFirstLoad then
		self:UpdateUI()
	end
end

-- Обработка изменения статов
function DataController:OnStatsChanged(stats)
	print("[DATA CONTROLLER] Stats changed: Health=" .. stats.Health .. "/" .. stats.MaxHealth)

	-- Обновляем локальные данные если они загружены
	if self.PlayerData then
		self.PlayerData.Health = stats.Health
		self.PlayerData.Mana = stats.Mana
		self.PlayerData.Stamina = stats.Stamina
		self.PlayerData.MaxHealth = stats.MaxHealth
		self.PlayerData.MaxMana = stats.MaxMana
		self.PlayerData.MaxStamina = stats.MaxStamina
	end

	-- Уведомляем об изменении статов
	self.StatsChanged:Fire(stats)

	-- Обновляем UI (это обновление нужно для статов)
	self:UpdateUI()
end

-- Обработка системных сообщений
function DataController:OnSystemMessage(messageData)
	print("[SYSTEM] " .. messageData.Message)

	-- Здесь можно добавить обработку для UI уведомлений
end

-- Обработка повышения уровня
function DataController:OnLevelUp(levelData)
	print("[DATA CONTROLLER] LEVEL UP! New level: " .. levelData.NewLevel)

	if self.PlayerData then
		self.PlayerData.Level = levelData.NewLevel
		self.PlayerData.AttributePoints = levelData.AttributePoints
	end

	-- Уведомляем о повышении уровня
	self.LevelUp:Fire(levelData)

	-- Обновляем UI
	self:UpdateUI()
end

-- Обработка изменения опыта
function DataController:OnExperienceChanged(xpData)
	print("[DATA CONTROLLER] Experience changed: " .. xpData.Experience .. "/" .. xpData.RequiredXP)

	if self.PlayerData then
		self.PlayerData.Experience = xpData.Experience
		self.PlayerData.Level = xpData.Level
	end

	-- Уведомляем об изменении опыта
	self.ExperienceChanged:Fire(xpData)

	-- Обновляем UI
	self:UpdateUI()
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
	return (self.PlayerData and self.PlayerData.Level) or 1
end

-- Получить опыт игрока
function DataController:GetExperience()
	return (self.PlayerData and self.PlayerData.Experience) or 0
end

-- Получить характеристики игрока
function DataController:GetAttributes()
	return (self.PlayerData and self.PlayerData.Attributes) or Constants.PLAYER.BASE_ATTRIBUTES
end

-- Получить золото игрока
function DataController:GetGold()
	return (self.PlayerData and self.PlayerData.Currency.Gold) or 0
end

-- Получить статистику игрока
function DataController:GetStatistics()
	return (self.PlayerData and self.PlayerData.Statistics) or {}
end

-- Получить мастерство оружия
function DataController:GetWeaponMastery(weaponType)
	if self.PlayerData == nil or self.PlayerData.WeaponMastery == nil then
		return { Level = 1, Experience = 0 }
	end

	return self.PlayerData.WeaponMastery[weaponType] or { Level = 1, Experience = 0 }
end

-- Рассчитать максимальное здоровье (теперь берем с сервера)
function DataController:GetMaxHealth()
	if self.PlayerData and self.PlayerData.MaxHealth then
		-- Используем значение с сервера если доступно
		return self.PlayerData.MaxHealth
	end

	-- Fallback расчет если сервер не прислал
	local attributes = self:GetAttributes()
	return Constants.PLAYER.BASE_HEALTH + (attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
end

-- Рассчитать максимальную ману (теперь берем с сервера)
function DataController:GetMaxMana()
	if self.PlayerData and self.PlayerData.MaxMana then
		return self.PlayerData.MaxMana
	end

	local attributes = self:GetAttributes()
	return Constants.PLAYER.BASE_MANA + (attributes.Intelligence * Constants.PLAYER.MANA_PER_INTELLIGENCE)
end

-- Рассчитать максимальную выносливость (теперь берем с сервера)
function DataController:GetMaxStamina()
	if self.PlayerData and self.PlayerData.MaxStamina then
		return self.PlayerData.MaxStamina
	end

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

-- Обновить UI через UIController
function DataController:UpdateUI()
	if self.PlayerData == nil then
		return
	end

	local success, ControllerManager = pcall(require, script.Parent.Parent.ControllerManager)
	if not success then
		print("[DATA CONTROLLER] Could not access ControllerManager")
		return
	end

	local success2, UIController = pcall(function()
		return ControllerManager:GetController("UIController")
	end)

	if success2 and UIController ~= nil then
		UIController:UpdateStats(self.PlayerData)
		print("[DATA CONTROLLER] UI updated successfully")
	else
		print("[DATA CONTROLLER] UIController not available")
	end
end

-- Вывести информацию об игроке в консоль
function DataController:PrintPlayerInfo()
	if self.PlayerData == nil then
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
