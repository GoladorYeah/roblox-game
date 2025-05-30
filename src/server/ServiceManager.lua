-- src/server/ServiceManager.lua
-- Менеджер для управления всеми серверными сервисами

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseService = require(ReplicatedStorage.Shared.BaseService)

local ServiceManager = {}
ServiceManager.Services = {}
ServiceManager.IsInitialized = false

-- Регистрация нового сервиса
function ServiceManager:RegisterService(serviceClass, ...)
	if self.IsInitialized then
		error("Cannot register services after initialization!")
	end

	local service = serviceClass.new(...)

	if not service.Name then
		error("Service must have a Name property!")
	end

	if self.Services[service.Name] then
		error("Service " .. service.Name .. " already exists!")
	end

	self.Services[service.Name] = service
	print("[SERVICE MANAGER] Registered service: " .. service.Name)

	return service
end

-- Получить сервис по имени
function ServiceManager:GetService(serviceName)
	local service = self.Services[serviceName]
	if not service then
		error("Service " .. serviceName .. " not found!")
	end
	return service
end

-- Инициализация всех сервисов
function ServiceManager:Initialize()
	if self.IsInitialized then
		warn("ServiceManager already initialized!")
		return
	end

	print("[SERVICE MANAGER] Initializing all services...")

	-- Сначала инициализируем все сервисы
	for name, service in pairs(self.Services) do
		if service.Initialize then
			service:Initialize()
		end
	end

	self.IsInitialized = true
	print("[SERVICE MANAGER] All services initialized!")
end

-- Запуск всех сервисов
function ServiceManager:StartAll()
	if not self.IsInitialized then
		error("ServiceManager must be initialized before starting services!")
	end

	print("[SERVICE MANAGER] Starting all services...")

	-- Запускаем все сервисы после инициализации
	for name, service in pairs(self.Services) do
		if service.Start then
			service:Start()
		end
	end

	print("[SERVICE MANAGER] All services started!")
end

-- Получить статус всех сервисов
function ServiceManager:GetStatus()
	local status = {}

	for name, service in pairs(self.Services) do
		status[name] = {
			Initialized = service.IsInitialized,
			Started = service.IsStarted,
			Ready = service:IsReady(),
		}
	end

	return status
end

-- Cleanup всех сервисов
function ServiceManager:Cleanup()
	print("[SERVICE MANAGER] Cleaning up all services...")

	for name, service in pairs(self.Services) do
		if service.Cleanup then
			service:Cleanup()
		end
	end

	self.Services = {}
	self.IsInitialized = false
	print("[SERVICE MANAGER] Cleanup complete!")
end

-- Обработка отключения сервера
game:BindToClose(function()
	ServiceManager:Cleanup()
end)

return ServiceManager
