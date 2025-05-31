-- src/client/Main.client.lua
-- Главный клиентский скрипт - точка входа для клиента

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer").StarterPlayerScripts

-- Ждем загрузки персонажа
local LocalPlayer = Players.LocalPlayer
-- Убираем неиспользуемую переменную PlayerGui

-- Импорты
local ControllerManager = require(StarterPlayerScripts.Client.ControllerManager)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

print("=== " .. Constants.GAME_NAME .. " Client Starting ===")
print("Version: " .. Constants.VERSION)
print("Player: " .. LocalPlayer.Name)

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

-- Регистрация всех контроллеров
local function registerControllers()
	print("[MAIN] Registering controllers...")

	-- Регистрируем UIController первым
	local UIController = safeRequire(StarterPlayerScripts.Client.controllers.UIController, "UIController")
	if UIController then
		ControllerManager:RegisterController(UIController)
	end

	-- Регистрируем DataController
	local DataController = safeRequire(StarterPlayerScripts.Client.controllers.DataController, "DataController")
	if DataController then
		ControllerManager:RegisterController(DataController)
	end

	-- Регистрируем ResourceController
	local ResourceController =
		safeRequire(StarterPlayerScripts.Client.controllers.ResourceController, "ResourceController")
	if ResourceController then
		ControllerManager:RegisterController(ResourceController)
	end

	-- Регистрируем ResourceController
	local CameraController = safeRequire(StarterPlayerScripts.Client.controllers.CameraController, "CameraController")
	if CameraController then
		ControllerManager:RegisterController(CameraController)
	end

	print("[MAIN] All controllers registered!")
end

-- Ожидание загрузки ReplicatedStorage
local function waitForReplication()
	print("[MAIN] Waiting for replication...")

	-- Ждем пока загрузятся все необходимые модули
	ReplicatedStorage:WaitForChild("Shared")

	print("[MAIN] Replication complete!")
end

-- Основная функция запуска клиента
local function main()
	print("[MAIN] Starting client initialization...")

	-- Ждем репликации
	waitForReplication()

	-- Регистрируем все контроллеры
	registerControllers()

	-- Инициализируем все контроллеры
	ControllerManager:Initialize()

	-- Запускаем все контроллеры
	ControllerManager:StartAll()

	-- Выводим статус всех контроллеров
	local status = ControllerManager:GetStatus()
	print("[MAIN] Controller Status:")
	for controllerName, controllerStatus in pairs(status) do
		local statusText = controllerStatus.Ready and "✅ READY" or "❌ NOT READY"
		print("  " .. controllerName .. ": " .. statusText)
	end

	print("=== Client Started Successfully! ===")
end

-- Обработка ошибок при запуске
local success, errorMessage = pcall(main)
if not success then
	error("[MAIN] Client failed to start: " .. tostring(errorMessage))
end

-- Обработка отключения игрока
Players.PlayerRemoving:Connect(function(player)
	if player == LocalPlayer then
		ControllerManager:Cleanup()
	end
end)
