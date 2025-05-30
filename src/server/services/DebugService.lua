-- src/server/services/DebugService.lua
-- Сервис для отладочных команд и тестирования

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	self:RegisterCommand("help", "Показать все команды", function(player, args)
		self:ShowHelp(player)
	end)

	self:RegisterCommand("addxp", "Добавить опыт: /addxp [количество]", function(player, args)
		local amount = tonumber(args[1]) or 100
		self:AddExperience(player, amount)
	end)

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

	self:RegisterCommand("stats", "Показать статистику игрока", function(player, args)
		self:ShowStats(player)
	end)

	self:RegisterCommand("heal", "Восстановить здоровье", function(player, args)
		self:HealPlayer(player)
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

-- Установить уровень
function DebugService:SetLevel(player, level)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		level = math.max(1, math.min(level, Constants.PLAYER.MAX_LEVEL))
		data.Level = level
		data.Experience = 0

		-- Пересчитываем ресурсы
		PlayerDataService:InitializePlayerResources(player)

		-- Отправляем обновленные данные клиенту
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		self:SendMessage(player, "Уровень установлен на " .. level .. "!")
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

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		data.Currency.Gold = data.Currency.Gold + amount

		-- Отправляем обновленные данные клиенту
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		self:SendMessage(player, "Добавлено " .. amount .. " золота! Всего: " .. data.Currency.Gold)
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
