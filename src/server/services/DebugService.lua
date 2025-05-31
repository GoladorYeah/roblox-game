-- src/server/services/DebugService.lua
-- Основной сервис для отладочных команд

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local BaseService = require(ReplicatedStorage.Shared.BaseService)

-- Импортируем модули команд
local PlayerCommands = require(script.Parent.debug.PlayerCommands)
local ExperienceCommands = require(script.Parent.debug.ExperienceCommands)
local ValidationCommands = require(script.Parent.debug.ValidationCommands)
local SystemCommands = require(script.Parent.debug.SystemCommands)
local WorldCommands = require(script.Parent.debug.WorldCommands)
local CharacterCommands = require(script.Parent.debug.CharacterCommands)

local DebugService = setmetatable({}, { __index = BaseService })
DebugService.__index = DebugService

function DebugService.new()
	local self = setmetatable(BaseService.new("DebugService"), DebugService)

	self.Commands = {}
	self.AdminPlayers = {} -- Здесь можно добавить admin player ID's

	-- Модули команд
	self.PlayerCommands = PlayerCommands.new(self)
	self.ExperienceCommands = ExperienceCommands.new(self)
	self.ValidationCommands = ValidationCommands.new(self)
	self.SystemCommands = SystemCommands.new(self)
	self.WorldCommands = WorldCommands.new(self)
	self.CharacterCommands = CharacterCommands.new(self)

	return self
end

function DebugService:OnInitialize()
	-- Регистрируем базовые команды
	self:RegisterCommand("help", "Показать все команды", function(player, _)
		self:ShowHelp(player)
	end)

	-- Регистрируем команды из модулей
	self.PlayerCommands:RegisterCommands()
	self.ExperienceCommands:RegisterCommands()
	self.ValidationCommands:RegisterCommands()
	self.SystemCommands:RegisterCommands()
	self.WorldCommands:RegisterCommands()
	self.CharacterCommands:RegisterCommands()

	print("[DEBUG SERVICE] All command modules registered (including WorldCommands)")
end

function DebugService:OnStart()
	-- Подключаем обработчик чата
	self:SetupChatHandler()
	print("[DEBUG SERVICE] Chat handler ready")
end

-- Настройка обработчика чата
function DebugService:SetupChatHandler()
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

	-- Группируем команды по категориям
	local categories = {
		["Игрок"] = { "stats", "heal", "addgold" },
		["Опыт"] = { "addxp", "setexp", "settotalexp", "setlevel", "xpdiag", "fixexp", "xpcalc", "simulate" },
		["Мир"] = {
			"time",
			"settime",
			"day",
			"night",
			"dawn",
			"dusk",
			"timespeed",
			"pausetime",
			"fasttime",
			"worldinfo",
		},
		["Валидация"] = { "valstats", "testval", "resetval" },
		["Система"] = { "perf", "help" },
	}

	for categoryName, commandList in pairs(categories) do
		self:SendMessage(player, "--- " .. categoryName .. " ---")
		for _, commandName in ipairs(commandList) do
			local command = self.Commands[commandName]
			if command then
				self:SendMessage(player, "/" .. commandName .. " - " .. command.Description)
			end
		end
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

-- Получить ServiceManager (для модулей)
function DebugService:GetServiceManager()
	return require(script.Parent.Parent.ServiceManager)
end

return DebugService
