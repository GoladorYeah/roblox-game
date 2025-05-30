-- src/client/ControllerManager.lua
-- Менеджер для управления всеми клиентскими контроллерами

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseController = require(ReplicatedStorage.Shared.BaseController)

local ControllerManager = {}
ControllerManager.Controllers = {}
ControllerManager.IsInitialized = false

-- Регистрация нового контроллера
function ControllerManager:RegisterController(controllerClass, ...)
	if self.IsInitialized then
		error("Cannot register controllers after initialization!")
	end

	local controller = controllerClass.new(...)

	if not controller.Name then
		error("Controller must have a Name property!")
	end

	if self.Controllers[controller.Name] then
		error("Controller " .. controller.Name .. " already exists!")
	end

	self.Controllers[controller.Name] = controller
	print("[CONTROLLER MANAGER] Registered controller: " .. controller.Name)

	return controller
end

-- Получить контроллер по имени
function ControllerManager:GetController(controllerName)
	local controller = self.Controllers[controllerName]
	if not controller then
		error("Controller " .. controllerName .. " not found!")
	end
	return controller
end

-- Инициализация всех контроллеров
function ControllerManager:Initialize()
	if self.IsInitialized then
		warn("ControllerManager already initialized!")
		return
	end

	print("[CONTROLLER MANAGER] Initializing all controllers...")

	-- Сначала инициализируем все контроллеры
	for name, controller in pairs(self.Controllers) do
		if controller.Initialize then
			controller:Initialize()
		end
	end

	self.IsInitialized = true
	print("[CONTROLLER MANAGER] All controllers initialized!")
end

-- Запуск всех контроллеров
function ControllerManager:StartAll()
	if not self.IsInitialized then
		error("ControllerManager must be initialized before starting controllers!")
	end

	print("[CONTROLLER MANAGER] Starting all controllers...")

	-- Запускаем все контроллеры после инициализации
	for name, controller in pairs(self.Controllers) do
		if controller.Start then
			controller:Start()
		end
	end

	print("[CONTROLLER MANAGER] All controllers started!")
end

-- Получить статус всех контроллеров
function ControllerManager:GetStatus()
	local status = {}

	for name, controller in pairs(self.Controllers) do
		status[name] = {
			Initialized = controller.IsInitialized,
			Started = controller.IsStarted,
			Ready = controller:IsReady(),
		}
	end

	return status
end

-- Cleanup всех контроллеров
function ControllerManager:Cleanup()
	print("[CONTROLLER MANAGER] Cleaning up all controllers...")

	for name, controller in pairs(self.Controllers) do
		if controller.Cleanup then
			controller:Cleanup()
		end
	end

	self.Controllers = {}
	self.IsInitialized = false
	print("[CONTROLLER MANAGER] Cleanup complete!")
end

return ControllerManager
