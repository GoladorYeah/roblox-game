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

	self:RegisterCommand("commands", "Показать команды по категориям", function(player, _)
		self:ShowCategorizedHelp(player)
	end)

	self:RegisterCommand("search", "Поиск команд: /search [слово]", function(player, args)
		local keyword = args[1]
		self:SearchCommands(player, keyword)
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
	print("[DEBUG SERVICE] Debug commands available: /help или /commands")
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
	if self.Commands[commandName] then
		warn("[DEBUG SERVICE] Command /" .. commandName .. " already exists! Overwriting...")
	end

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

-- Показать помощь (все команды списком)
function DebugService:ShowHelp(player)
	self:SendMessage(player, "=== ВСЕ ДОСТУПНЫЕ КОМАНДЫ ===")

	-- Получаем все команды и сортируем по алфавиту
	local commandsList = {}
	for commandName, command in pairs(self.Commands) do
		table.insert(commandsList, {
			name = commandName,
			description = command.Description,
		})
	end

	table.sort(commandsList, function(a, b)
		return a.name < b.name
	end)

	-- Выводим команды по 10 штук для удобства
	local count = 0
	for _, cmd in ipairs(commandsList) do
		self:SendMessage(player, "/" .. cmd.name .. " - " .. cmd.description)
		count = count + 1

		-- Каждые 15 команд делаем небольшую паузу
		if count % 15 == 0 then
			wait(0.1)
		end
	end

	self:SendMessage(player, "--- ИТОГО ---")
	self:SendMessage(player, "Всего команд: " .. #commandsList)
	self:SendMessage(player, "Используйте /commands для группировки по категориям")
end

-- Показать помощь по категориям
function DebugService:ShowCategorizedHelp(player)
	self:SendMessage(player, "=== КОМАНДЫ ПО КАТЕГОРИЯМ ===")

	-- Определяем категории команд на основе их названий и описаний
	local categories = {
		["🎮 Основные"] = {
			commands = { "help", "commands", "search" },
			description = "Базовые команды помощи и поиска",
		},

		["👤 Данные игрока"] = {
			commands = { "stats", "addgold", "setgold", "addattr", "resetattr", "savedata", "reloaddata" },
			description = "Управление данными и прогрессом игрока",
		},

		["❤️ Персонаж"] = {
			commands = {
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
				"godmode",
				"ghost",
			},
			description = "Управление персонажем и его состоянием",
		},

		["⭐ Опыт и уровни"] = {
			commands = { "addxp", "setexp", "settotalexp", "setlevel", "xpdiag", "fixexp", "xpcalc", "simulate" },
			description = "Система опыта и повышения уровня",
		},

		["🌍 Мир и время"] = {
			commands = {
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
			description = "Управление миром и временем",
		},

		["🔧 Валидация"] = {
			commands = { "valstats", "testval", "resetval", "valtest", "valdebug" },
			description = "Система валидации данных",
		},

		["🖥️ Система"] = {
			commands = { "perf", "memory", "services", "players", "gc", "benchmark", "network", "uptime" },
			description = "Мониторинг и производительность",
		},
	}

	for categoryName, categoryData in pairs(categories) do
		self:SendMessage(player, "")
		self:SendMessage(player, categoryName .. " - " .. categoryData.description)
		self:SendMessage(player, "─────────────────────")

		local foundCommands = 0
		for _, commandName in ipairs(categoryData.commands) do
			local command = self.Commands[commandName]
			if command then
				self:SendMessage(player, "  /" .. commandName .. " - " .. command.Description)
				foundCommands = foundCommands + 1
			end
		end

		if foundCommands == 0 then
			self:SendMessage(player, "  (Команды не найдены)")
		end

		-- Небольшая пауза между категориями
		wait(0.05)
	end

	self:SendMessage(player, "")
	self:SendMessage(player, "📝 Используйте /help для полного списка")

	-- Показываем статистику
	local totalCommands = 0
	for _ in pairs(self.Commands) do
		totalCommands = totalCommands + 1
	end
	self:SendMessage(player, "📊 Всего команд в системе: " .. totalCommands)
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

-- Поиск команд по ключевому слову
function DebugService:SearchCommands(player, keyword)
	if not keyword or keyword == "" then
		self:SendMessage(
			player,
			"❌ Укажите ключевое слово для поиска: /search <слово>"
		)
		return
	end

	keyword = keyword:lower()
	local foundCommands = {}

	for commandName, command in pairs(self.Commands) do
		if commandName:lower():find(keyword) or command.Description:lower():find(keyword) then
			table.insert(foundCommands, {
				name = commandName,
				description = command.Description,
			})
		end
	end

	if #foundCommands == 0 then
		self:SendMessage(
			player,
			"❌ Команды с ключевым словом '" .. keyword .. "' не найдены"
		)
		return
	end

	table.sort(foundCommands, function(a, b)
		return a.name < b.name
	end)

	self:SendMessage(player, "🔍 Найденные команды для '" .. keyword .. "':")
	for _, cmd in ipairs(foundCommands) do
		self:SendMessage(player, "  /" .. cmd.name .. " - " .. cmd.description)
	end
	self:SendMessage(player, "Найдено: " .. #foundCommands .. " команд")
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
