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
	print("[DEBUG SERVICE] Registering Player commands...")
	self.PlayerCommands:RegisterCommands()

	print("[DEBUG SERVICE] Registering Experience commands...")
	self.ExperienceCommands:RegisterCommands()

	print("[DEBUG SERVICE] Registering Validation commands...")
	self.ValidationCommands:RegisterCommands()

	print("[DEBUG SERVICE] Registering System commands...")
	self.SystemCommands:RegisterCommands()

	print("[DEBUG SERVICE] Registering World commands...")
	self.WorldCommands:RegisterCommands()

	print("[DEBUG SERVICE] Registering Character commands...")
	self.CharacterCommands:RegisterCommands()

	print("[DEBUG SERVICE] All command modules registered successfully!")

	-- Выводим общее количество зарегистрированных команд
	local commandCount = 0
	for _ in pairs(self.Commands) do
		commandCount = commandCount + 1
	end
	print("[DEBUG SERVICE] Total commands registered: " .. commandCount)
end

function DebugService:OnStart()
	-- Подключаем обработчик чата
	self:SetupChatHandler()
	print("[DEBUG SERVICE] Chat handler ready")
	print("[DEBUG SERVICE] Debug commands available: /help")
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
		print("[DEBUG SERVICE] Connected to new TextChatService")
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
		print("[DEBUG SERVICE] Connected to legacy chat system")
	end
end

-- Регистрация команды
function DebugService:RegisterCommand(commandName, description, callback)
	self.Commands[commandName] = {
		Description = description,
		Callback = callback,
	}
	print("[DEBUG SERVICE] Registered command: /" .. commandName .. " - " .. description)
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
			"❌ Команда /"
				.. commandName
				.. " не найдена. Используйте /help для списка команд."
		)
		return
	end

	print("[DEBUG] " .. player.Name .. " executed command: /" .. commandName .. " " .. table.concat(args, " "))

	local success, result = pcall(command.Callback, player, args)
	if not success then
		warn("[DEBUG] Error executing command /" .. commandName .. ": " .. tostring(result))
		self:SendMessage(player, "❌ Ошибка выполнения команды: " .. tostring(result))
	end
end

-- Показать помощь
function DebugService:ShowHelp(player)
	self:SendMessage(player, "=== ДОСТУПНЫЕ КОМАНДЫ ===")

	-- Группируем команды по категориям (исправленная версия)
	local categories = {
		["Игрок"] = { "stats", "addgold", "setgold", "addattr", "resetattr" },
		["Персонаж"] = {
			"damage",
			"heal",
			"kill",
			"respawn",
			"invul",
			"regen",
			"sethealth",
			"setmana",
			"setstamina",
			"charinfo",
			"speed",
			"jump",
			"consumestamina",
			"teleport",
			"resetchar",
		},
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
			"resumetime",
			"fasttime",
			"normaltime",
			"worldinfo",
			"saveworld",
			"loadworld",
		},
		["Валидация"] = { "valstats", "testval", "resetval", "valtest", "valdebug" },
		["Система"] = { "perf", "memory", "services", "players", "gc", "benchmark", "network", "uptime", "help" },
	}

	for categoryName, commandList in pairs(categories) do
		local foundCommands = {}

		-- Проверяем какие команды из списка действительно зарегистрированы
		for _, commandName in ipairs(commandList) do
			if self.Commands[commandName] then
				table.insert(foundCommands, commandName)
			end
		end

		-- Показываем категорию только если есть команды
		if #foundCommands > 0 then
			self:SendMessage(player, "--- " .. categoryName .. " ---")
			for _, commandName in ipairs(foundCommands) do
				local command = self.Commands[commandName]
				self:SendMessage(player, "/" .. commandName .. " - " .. command.Description)
			end
		end
	end

	-- Показываем команды, которые не попали ни в одну категорию
	local categorizedCommands = {}
	for categoryName, commandList in pairs(categories) do
		for _, commandName in ipairs(commandList) do
			categorizedCommands[commandName] = true
		end
	end

	local uncategorizedCommands = {}
	for commandName, _ in pairs(self.Commands) do
		if not categorizedCommands[commandName] then
			table.insert(uncategorizedCommands, commandName)
		end
	end

	if #uncategorizedCommands > 0 then
		table.sort(uncategorizedCommands)
		self:SendMessage(player, "--- ПРОЧИЕ ---")
		for _, commandName in ipairs(uncategorizedCommands) do
			local command = self.Commands[commandName]
			self:SendMessage(player, "/" .. commandName .. " - " .. command.Description)
		end
	end

	-- Показываем общую статистику
	local totalCommands = 0
	for _ in pairs(self.Commands) do
		totalCommands = totalCommands + 1
	end

	self:SendMessage(player, "--- СТАТИСТИКА ---")
	self:SendMessage(player, "Всего команд: " .. totalCommands)
	self:SendMessage(player, "Используйте /<команда> для выполнения")

	-- Отладочная информация
	self:SendMessage(player, "--- ОТЛАДКА ---")
	self:SendMessage(player, "Для диагностики используйте: /services")
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

-- Получить список всех команд (для статистики)
function DebugService:GetCommandsList()
	local commandsList = {}
	for commandName, command in pairs(self.Commands) do
		table.insert(commandsList, {
			Name = commandName,
			Description = command.Description,
		})
	end

	-- Сортируем по алфавиту
	table.sort(commandsList, function(a, b)
		return a.Name < b.Name
	end)

	return commandsList
end

-- Проверка доступности команды
function DebugService:IsCommandAvailable(commandName)
	return self.Commands[commandName] ~= nil
end

-- Получить информацию о команде
function DebugService:GetCommandInfo(commandName)
	return self.Commands[commandName]
end

-- Получить статистику использования команд
function DebugService:GetCommandStats()
	return {
		TotalCommands = self:GetCommandCount(),
		RegisteredModules = {
			"PlayerCommands",
			"ExperienceCommands",
			"ValidationCommands",
			"SystemCommands",
			"WorldCommands",
			"CharacterCommands",
		},
		ChatSystemType = TextChatService.ChatVersion == Enum.ChatVersion.TextChatService and "New" or "Legacy",
	}
end

-- Получить количество команд
function DebugService:GetCommandCount()
	local count = 0
	for _ in pairs(self.Commands) do
		count = count + 1
	end
	return count
end

function DebugService:OnCleanup()
	-- Очищаем команды
	self.Commands = {}

	-- Очищаем модули
	self.PlayerCommands = nil
	self.ExperienceCommands = nil
	self.ValidationCommands = nil
	self.SystemCommands = nil
	self.WorldCommands = nil
	self.CharacterCommands = nil

	print("[DEBUG SERVICE] Debug service cleaned up")
end

return DebugService
