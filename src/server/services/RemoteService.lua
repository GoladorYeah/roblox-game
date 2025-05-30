-- src/server/services/RemoteService.lua
-- Сервис для управления RemoteEvent'ами и сетевой коммуникацией

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local RemoteService = setmetatable({}, { __index = BaseService })
RemoteService.__index = RemoteService

function RemoteService.new()
	local self = setmetatable(BaseService.new("RemoteService"), RemoteService)

	self.RemoteEvents = {}
	self.RemoteFunctions = {}
	self.RateLimits = {} -- [Player][EventName] = {LastRequest = tick(), RequestCount = 0}

	return self
end

function RemoteService:OnInitialize()
	-- Создаем папку для RemoteEvent'ов
	local remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage

	-- Создаем все RemoteEvent'ы из констант (используем значения, а не ключи)
	for eventKey, eventName in pairs(Constants.REMOTE_EVENTS) do
		self:CreateRemoteEvent(eventName)
		-- Используем eventKey для избежания warning об unused variable
		print("[REMOTE SERVICE] Processing event key: " .. eventKey .. " -> " .. eventName)
	end

	-- Инициализируем rate limiting для игроков
	self:ConnectEvent(Players.PlayerAdded, function(player)
		self.RateLimits[player] = {}
	end)

	self:ConnectEvent(Players.PlayerRemoving, function(player)
		self.RateLimits[player] = nil
	end)

	-- Очистка rate limits каждую секунду
	self:ConnectEvent(RunService.Heartbeat, function()
		self:CleanupRateLimits()
	end)
end

-- Создать RemoteEvent
function RemoteService:CreateRemoteEvent(eventName)
	if self.RemoteEvents[eventName] then
		warn("[REMOTE SERVICE] RemoteEvent " .. eventName .. " already exists!")
		return self.RemoteEvents[eventName]
	end

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = eventName
	remoteEvent.Parent = ReplicatedStorage.RemoteEvents

	self.RemoteEvents[eventName] = remoteEvent
	print("[REMOTE SERVICE] Created RemoteEvent: " .. eventName)

	return remoteEvent
end

-- Создать RemoteFunction
function RemoteService:CreateRemoteFunction(functionName)
	if self.RemoteFunctions[functionName] then
		warn("[REMOTE SERVICE] RemoteFunction " .. functionName .. " already exists!")
		return self.RemoteFunctions[functionName]
	end

	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = functionName
	remoteFunction.Parent = ReplicatedStorage.RemoteEvents

	self.RemoteFunctions[functionName] = remoteFunction
	print("[REMOTE SERVICE] Created RemoteFunction: " .. functionName)

	return remoteFunction
end

-- Отправить событие конкретному игроку
function RemoteService:FireClient(player, eventName, ...)
	local remoteEvent = self.RemoteEvents[eventName]
	if not remoteEvent then
		warn("[REMOTE SERVICE] RemoteEvent " .. eventName .. " not found!")
		return
	end

	remoteEvent:FireClient(player, ...)
end

-- Отправить событие всем игрокам
function RemoteService:FireAllClients(eventName, ...)
	local remoteEvent = self.RemoteEvents[eventName]
	if not remoteEvent then
		warn("[REMOTE SERVICE] RemoteEvent " .. eventName .. " not found!")
		return
	end

	remoteEvent:FireAllClients(...)
end

-- Отправить событие всем игрокам кроме одного
function RemoteService:FireAllClientsExcept(excludePlayer, eventName, ...)
	local remoteEvent = self.RemoteEvents[eventName]
	if not remoteEvent then
		warn("[REMOTE SERVICE] RemoteEvent " .. eventName .. " not found!")
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excludePlayer then
			remoteEvent:FireClient(player, ...)
		end
	end
end

-- Подключить обработчик события от клиента
function RemoteService:ConnectClientEvent(eventName, callback, rateLimitType)
	local remoteEvent = self.RemoteEvents[eventName]
	if not remoteEvent then
		warn("[REMOTE SERVICE] RemoteEvent " .. eventName .. " not found!")
		return
	end

	local connection = remoteEvent.OnServerEvent:Connect(function(player, ...)
		-- Проверяем rate limiting
		if rateLimitType and not self:CheckRateLimit(player, eventName, rateLimitType) then
			warn("[REMOTE SERVICE] Rate limit exceeded for " .. player.Name .. " on " .. eventName)
			return
		end

		-- Валидация игрока
		if not self:ValidatePlayer(player) then
			warn("[REMOTE SERVICE] Invalid player tried to fire " .. eventName)
			return
		end

		-- Вызываем callback с обработкой ошибок
		local success, result = pcall(callback, player, ...)
		if not success then
			warn("[REMOTE SERVICE] Error in " .. eventName .. " handler: " .. tostring(result))
		end
	end)

	table.insert(self.Connections, connection)
	print("[REMOTE SERVICE] Connected handler for: " .. eventName)

	return connection
end

-- Установить обработчик RemoteFunction
function RemoteService:SetFunctionHandler(functionName, handler, rateLimitType)
	local remoteFunction = self.RemoteFunctions[functionName]
	if not remoteFunction then
		warn("[REMOTE SERVICE] RemoteFunction " .. functionName .. " not found!")
		return
	end

	remoteFunction.OnServerInvoke = function(player, ...)
		-- Проверяем rate limiting
		if rateLimitType and not self:CheckRateLimit(player, functionName, rateLimitType) then
			warn("[REMOTE SERVICE] Rate limit exceeded for " .. player.Name .. " on " .. functionName)
			return nil
		end

		-- Валидация игрока
		if not self:ValidatePlayer(player) then
			warn("[REMOTE SERVICE] Invalid player tried to invoke " .. functionName)
			return nil
		end

		-- Вызываем handler с обработкой ошибок
		local success, result = pcall(handler, player, ...)
		if success then
			return result
		else
			warn("[REMOTE SERVICE] Error in " .. functionName .. " handler: " .. tostring(result))
			return nil
		end
	end

	print("[REMOTE SERVICE] Set handler for RemoteFunction: " .. functionName)
end

-- Проверка rate limiting
function RemoteService:CheckRateLimit(player, eventName, limitType)
	if not self.RateLimits[player] then
		self.RateLimits[player] = {}
	end

	local currentTime = tick()
	local playerLimits = self.RateLimits[player]

	if not playerLimits[eventName] then
		playerLimits[eventName] = {
			LastRequest = currentTime,
			RequestCount = 1,
		}
		return true
	end

	local limitData = playerLimits[eventName]
	local timeDiff = currentTime - limitData.LastRequest

	-- Получаем лимит для данного типа события
	local maxRequests = Constants.NETWORK.RATE_LIMITS[limitType] or 5

	if timeDiff >= 1.0 then
		-- Прошла секунда, сбрасываем счетчик
		limitData.LastRequest = currentTime
		limitData.RequestCount = 1
		return true
	else
		-- Проверяем, не превышен ли лимит
		limitData.RequestCount = limitData.RequestCount + 1
		return limitData.RequestCount <= maxRequests
	end
end

-- Валидация игрока
function RemoteService:ValidatePlayer(player)
	return player ~= nil and player.Parent == Players and player.Character ~= nil
end

-- Очистка старых записей rate limiting
function RemoteService:CleanupRateLimits()
	local currentTime = tick()
	local cleanedPlayers = 0

	for playerInstance, playerLimits in pairs(self.RateLimits) do
		local cleanedEvents = 0

		for eventName, limitData in pairs(playerLimits) do
			if currentTime - limitData.LastRequest > 60 then -- Удаляем записи старше минуты
				playerLimits[eventName] = nil
				cleanedEvents = cleanedEvents + 1
			end
		end

		-- Используем playerInstance для отслеживания очистки
		if cleanedEvents > 0 then
			print(
				string.format("[REMOTE SERVICE] Cleaned %d old rate limits for %s", cleanedEvents, playerInstance.Name)
			)
			cleanedPlayers = cleanedPlayers + 1
		end
	end

	-- Логируем общую статистику очистки если что-то было очищено
	if cleanedPlayers > 0 then
		print(string.format("[REMOTE SERVICE] Rate limit cleanup: processed %d players", cleanedPlayers))
	end
end

-- Отправить системное сообщение игроку
function RemoteService:SendSystemMessage(player, message, messageType)
	self:FireClient(player, Constants.REMOTE_EVENTS.SYSTEM_MESSAGE, {
		Message = message,
		Type = messageType or "INFO",
		Timestamp = os.time(),
	})
end

-- Отправить системное сообщение всем игрокам
function RemoteService:BroadcastSystemMessage(message, messageType)
	self:FireAllClients(Constants.REMOTE_EVENTS.SYSTEM_MESSAGE, {
		Message = message,
		Type = messageType or "INFO",
		Timestamp = os.time(),
	})
end

-- Получить статистику сети
function RemoteService:GetNetworkStats()
	local stats = {
		TotalRemoteEvents = 0,
		TotalRemoteFunctions = 0,
		ActiveRateLimits = 0,
	}

	for _ in pairs(self.RemoteEvents) do
		stats.TotalRemoteEvents = stats.TotalRemoteEvents + 1
	end

	for _ in pairs(self.RemoteFunctions) do
		stats.TotalRemoteFunctions = stats.TotalRemoteFunctions + 1
	end

	for _, playerLimits in pairs(self.RateLimits) do
		for _ in pairs(playerLimits) do
			stats.ActiveRateLimits = stats.ActiveRateLimits + 1
		end
	end

	return stats
end

return RemoteService
