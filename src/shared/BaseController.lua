-- src/shared/BaseController.lua
-- Базовый класс для всех клиентских контроллеров

local BaseController = {}
BaseController.__index = BaseController

function BaseController.new(name)
	local self = setmetatable({}, BaseController)

	self.Name = name or "BaseController"
	self.IsInitialized = false
	self.IsStarted = false
	self.Connections = {}

	return self
end

-- Инициализация контроллера (вызывается один раз при создании)
function BaseController:Initialize()
	if self.IsInitialized then
		warn(self.Name .. " already initialized!")
		return
	end

	print("[CONTROLLER] Initializing " .. self.Name)
	self.IsInitialized = true

	-- Переопределить в дочерних классах
	if self.OnInitialize then
		self:OnInitialize()
	end
end

-- Запуск контроллера (вызывается после инициализации всех контроллеров)
function BaseController:Start()
	if not self.IsInitialized then
		error(self.Name .. " must be initialized before starting!")
	end

	if self.IsStarted then
		warn(self.Name .. " already started!")
		return
	end

	print("[CONTROLLER] Starting " .. self.Name)
	self.IsStarted = true

	-- Переопределить в дочерних классах
	if self.OnStart then
		self:OnStart()
	end
end

-- Безопасное подключение событий
function BaseController:ConnectEvent(event, callback)
	local connection = event:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

-- Отключение всех событий при cleanup
function BaseController:Cleanup()
	print("[CONTROLLER] Cleaning up " .. self.Name)

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

-- Получить статус контроллера
function BaseController:IsReady()
	return self.IsInitialized and self.IsStarted
end

return BaseController
