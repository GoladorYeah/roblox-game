-- src/shared/BaseService.lua
-- Базовый класс для всех серверных сервисов

local BaseService = {}
BaseService.__index = BaseService

function BaseService.new(name)
	local self = setmetatable({}, BaseService)

	self.Name = name or "BaseService"
	self.IsInitialized = false
	self.IsStarted = false
	self.Connections = {}

	return self
end

-- Инициализация сервиса (вызывается один раз при создании)
function BaseService:Initialize()
	if self.IsInitialized then
		warn(self.Name .. " already initialized!")
		return
	end

	print("[SERVICE] Initializing " .. self.Name)
	self.IsInitialized = true

	-- Переопределить в дочерних классах
	if self.OnInitialize then
		self:OnInitialize()
	end
end

-- Запуск сервиса (вызывается после инициализации всех сервисов)
function BaseService:Start()
	if not self.IsInitialized then
		error(self.Name .. " must be initialized before starting!")
	end

	if self.IsStarted then
		warn(self.Name .. " already started!")
		return
	end

	print("[SERVICE] Starting " .. self.Name)
	self.IsStarted = true

	-- Переопределить в дочерних классах
	if self.OnStart then
		self:OnStart()
	end
end

-- Безопасное подключение событий
function BaseService:ConnectEvent(event, callback)
	local connection = event:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

-- Отключение всех событий при cleanup
function BaseService:Cleanup()
	print("[SERVICE] Cleaning up " .. self.Name)

	for _, connection in ipairs(self.Connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	self.Connections = {}

	-- Переопределить в дочерних классах
	if self.OnCleanup then
		self:OnCleanup()
	end
end

-- Получить статус сервиса
function BaseService:IsReady()
	return self.IsInitialized and self.IsStarted
end

return BaseService
