-- src/server/Main.server.lua
-- Главный серверный скрипт - точка входа для сервера

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Импорты
local ServiceManager = require(ServerScriptService.Server.ServiceManager)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

print("=== " .. Constants.GAME_NAME .. " Server Starting ===")
print("Version: " .. Constants.VERSION)

-- Функция для безопасного require модулей
local function safeRequire(module, moduleName)
	local success, result = pcall(require, module)
	if success then
		print("[MAIN] Successfully loaded " .. moduleName)
		return result
	else
		warn("[MAIN] Failed to load " .. moduleName .. ": " .. tostring(result))
		return nil
	end
end

-- Регистрация всех сервисов
local function registerServices()
	print("[MAIN] Registering services...")

	-- Регистрируем ValidationService первым (нужен для других сервисов)
	local ValidationService = safeRequire(ServerScriptService.Server.services.ValidationService, "ValidationService")
	if ValidationService then
		ServiceManager:RegisterService(ValidationService)
	end

	-- Регистрируем RemoteService вторым (нужен для других сервисов)
	local RemoteService = safeRequire(ServerScriptService.Server.services.RemoteService, "RemoteService")
	if RemoteService then
		ServiceManager:RegisterService(RemoteService)
	end

	-- Регистрируем WorldService третьим (управление миром)
	local WorldService = safeRequire(ServerScriptService.Server.services.WorldService, "WorldService")
	if WorldService then
		ServiceManager:RegisterService(WorldService)
	end

	-- Пробуем ProfileService, если не работает - используем SimpleDataService
	local PlayerDataService = safeRequire(ServerScriptService.Server.services.PlayerDataService, "PlayerDataService")
	if not PlayerDataService then
		print("[MAIN] ProfileService failed, using SimpleDataService as fallback")
		PlayerDataService = safeRequire(ServerScriptService.Server.services.SimpleDataService, "SimpleDataService")
	end

	if PlayerDataService then
		ServiceManager:RegisterService(PlayerDataService)
	end

	-- Регистрируем DebugService (для тестирования)
	local DebugService = safeRequire(ServerScriptService.Server.services.DebugService, "DebugService")
	if DebugService then
		ServiceManager:RegisterService(DebugService)
	end

	print("[MAIN] All services registered!")
end

-- Основная функция запуска сервера
local function main()
	print("[MAIN] Starting server initialization...")

	-- Регистрируем все сервисы
	registerServices()

	-- Инициализируем все сервисы
	ServiceManager:Initialize()

	-- Запускаем все сервисы
	ServiceManager:StartAll()

	-- Выводим статус всех сервисов
	local status = ServiceManager:GetStatus()
	print("[MAIN] Service Status:")
	for serviceName, serviceStatus in pairs(status) do
		local statusText = serviceStatus.Ready and "✅ READY" or "❌ NOT READY"
		print("  " .. serviceName .. ": " .. statusText)
	end

	print("=== Server Started Successfully! ===")
	print("[MAIN] 🌍 World systems initialized")
	print("[MAIN] 🕐 Day/Night cycle started")
	print("[MAIN] 📡 Network systems ready")
	print("[MAIN] 👥 Player systems ready")
end

-- Обработка ошибок при запуске
local success, errorMessage = pcall(main)
if not success then
	error("[MAIN] Server failed to start: " .. tostring(errorMessage))
end

-- Heartbeat для отладки (каждые 30 секунд)
spawn(function()
	while true do
		wait(Constants.NETWORK.HEARTBEAT_INTERVAL)

		local status = ServiceManager:GetStatus()
		local readyServices = 0
		local totalServices = 0

		for _, serviceStatus in pairs(status) do
			totalServices = totalServices + 1
			if serviceStatus.Ready then
				readyServices = readyServices + 1
			end
		end

		-- Получаем информацию о времени мира
		local worldService = ServiceManager:GetService("WorldService")
		local timeInfo = ""
		if worldService then
			local info = worldService:GetTimeInfo()
			timeInfo = string.format(" | World: %s (%s)", worldService:GetFormattedTime(), info.TimeOfDay)
		end

		print("[HEARTBEAT] Services: " .. readyServices .. "/" .. totalServices .. " ready" .. timeInfo)
	end
end)
