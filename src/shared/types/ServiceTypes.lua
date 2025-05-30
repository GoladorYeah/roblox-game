-- src/shared/types/ServiceTypes.lua
-- Типы для сервисов и контроллеров

local ServiceTypes = {}

-- Базовые типы для сервисов
export type ServiceName = string
export type ServiceStatus = "Initializing" | "Ready" | "Starting" | "Started" | "Error" | "Stopped"

-- Интерфейс базового сервиса
export type IBaseService = {
	Name: ServiceName,
	IsInitialized: boolean,
	IsStarted: boolean,
	Connections: { RBXScriptConnection },

	-- Методы жизненного цикла
	Initialize: (self: IBaseService) -> (),
	Start: (self: IBaseService) -> (),
	Cleanup: (self: IBaseService) -> (),
	IsReady: (self: IBaseService) -> boolean,

	-- Управление событиями
	ConnectEvent: (self: IBaseService, event: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,

	-- Опциональные методы для переопределения
	OnInitialize: ((self: IBaseService) -> ())?,
	OnStart: ((self: IBaseService) -> ())?,
	OnCleanup: ((self: IBaseService) -> ())?,
}

-- Интерфейс базового контроллера (аналогично сервису, но для клиента)
export type IBaseController = {
	Name: ServiceName,
	IsInitialized: boolean,
	IsStarted: boolean,
	Connections: { RBXScriptConnection },

	Initialize: (self: IBaseController) -> (),
	Start: (self: IBaseController) -> (),
	Cleanup: (self: IBaseController) -> (),
	IsReady: (self: IBaseController) -> boolean,
	ConnectEvent: (self: IBaseController, event: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,

	OnInitialize: ((self: IBaseController) -> ())?,
	OnStart: ((self: IBaseController) -> ())?,
	OnCleanup: ((self: IBaseController) -> ())?,
}

-- Статус сервиса для мониторинга
export type ServiceStatusInfo = {
	Initialized: boolean,
	Started: boolean,
	Ready: boolean,
	LastError: string?,
	LastActivity: number, -- timestamp
}

-- Конфигурация менеджера сервисов
export type ServiceManagerConfig = {
	EnableLogging: boolean,
	LogLevel: "DEBUG" | "INFO" | "WARN" | "ERROR",
	StartupTimeout: number, -- секунды
	HealthCheckInterval: number, -- секунды
}

-- Результат операции сервиса
export type ServiceOperationResult = {
	Success: boolean,
	ErrorMessage: string?,
	ErrorCode: string?,
	Data: any?,
}

-- Rate limiting типы
export type RateLimitType = "CHAT" | "MOVEMENT" | "COMBAT" | "INVENTORY" | "TRADING" | "DEBUG"

export type RateLimitInfo = {
	LastRequest: number, -- timestamp
	RequestCount: number,
	IsBlocked: boolean,
	BlockExpiry: number?, -- timestamp когда разблокируется
}

export type PlayerRateLimits = {
	[string]: RateLimitInfo, -- ключ = имя события
}

-- Типы для RemoteService
export type RemoteEventCallback = (player: Player, ...any) -> ()
export type RemoteFunctionCallback = (player: Player, ...any) -> any

export type RemoteEventHandler = {
	Callback: RemoteEventCallback,
	RateLimitType: RateLimitType?,
	RequireValidPlayer: boolean,
}

export type RemoteFunctionHandler = {
	Callback: RemoteFunctionCallback,
	RateLimitType: RateLimitType?,
	RequireValidPlayer: boolean,
	Timeout: number?, -- секунды
}

-- Системное сообщение
export type SystemMessageType = "INFO" | "SUCCESS" | "WARNING" | "ERROR" | "CRITICAL"

export type SystemMessage = {
	Message: string,
	Type: SystemMessageType,
	Timestamp: number,
	Source: string?, -- какой сервис отправил
	PlayerId: number?, -- для персональных сообщений
}

-- Статистика сети
export type NetworkStatistics = {
	TotalRemoteEvents: number,
	TotalRemoteFunctions: number,
	ActiveRateLimits: number,
	MessagesPerSecond: number,
	AverageResponseTime: number, -- миллисекунды
	ErrorRate: number, -- процент ошибочных запросов
	LastReset: number, -- timestamp последнего сброса статистики
}

-- Типы для DebugService
export type DebugCommand = {
	Description: string,
	Callback: (player: Player, args: { string }) -> (),
	AdminOnly: boolean?,
	Cooldown: number?, -- секунды
	LastUsed: { [number]: number }?, -- [UserId] = timestamp
}

export type DebugCommandRegistry = {
	[string]: DebugCommand,
}

-- Уровни доступа для админ команд
export type AdminLevel = "NONE" | "MODERATOR" | "ADMIN" | "OWNER"

export type AdminPlayer = {
	UserId: number,
	Level: AdminLevel,
	GrantedBy: number?, -- кто выдал права
	GrantedAt: number, -- timestamp
	ExpiresAt: number?, -- timestamp окончания прав (nil = навсегда)
}

-- Типы для PlayerDataService
export type DataLoadResult = {
	Success: boolean,
	ProfileData: any?,
	ErrorMessage: string?,
	LoadTime: number, -- миллисекунды
}

export type DataSaveResult = {
	Success: boolean,
	ErrorMessage: string?,
	SaveTime: number, -- миллисекунды
}

-- Событие изменения данных игрока
export type PlayerDataEvent = {
	EventType: "DataLoaded" | "DataSaved" | "LevelUp" | "ExperienceGain" | "AttributeChange" | "ItemChange",
	PlayerId: number,
	OldValue: any?,
	NewValue: any?,
	Timestamp: number,
	Source: string, -- какой сервис инициировал изменение
}

-- Конфигурация для автосохранения
export type AutoSaveConfig = {
	Enabled: boolean,
	Interval: number, -- секунды между автосохранениями
	BackupCount: number, -- количество резервных копий
	SaveOnShutdown: boolean,
}

-- Статистика производительности сервиса
export type ServicePerformanceStats = {
	ServiceName: ServiceName,
	AverageInitTime: number, -- миллисекунды
	AverageStartTime: number, -- миллисекунды
	MethodCallCounts: { [string]: number }, -- количество вызовов методов
	ErrorCounts: { [string]: number }, -- количество ошибок по типам
	MemoryUsage: number?, -- байты (если доступно)
	LastPerformanceCheck: number, -- timestamp
}

-- Конфигурация логирования
export type LoggingConfig = {
	EnableConsoleLogging: boolean,
	EnableFileLogging: boolean?,
	LogLevel: "DEBUG" | "INFO" | "WARN" | "ERROR" | "CRITICAL",
	MaxLogFileSize: number?, -- байты
	LogRetentionDays: number?,
}

-- Запись лога
export type LogEntry = {
	Level: "DEBUG" | "INFO" | "WARN" | "ERROR" | "CRITICAL",
	Message: string,
	Source: string, -- имя сервиса/контроллера
	Timestamp: number,
	Data: any?, -- дополнительные данные
	StackTrace: string?, -- для ошибок
}

-- Healthcheck результат
export type HealthCheckResult = {
	ServiceName: ServiceName,
	IsHealthy: boolean,
	ResponseTime: number, -- миллисекунды
	ErrorMessage: string?,
	LastCheck: number, -- timestamp
	ConsecutiveFailures: number,
}

-- Валидация сервиса
function ServiceTypes.ValidateServiceName(name: any): boolean
	return type(name) == "string" and #name > 0 and #name <= 50
end

function ServiceTypes.ValidateServiceStatus(status: any): boolean
	local validStatuses = { "Initializing", "Ready", "Starting", "Started", "Error", "Stopped" }
	for _, validStatus in ipairs(validStatuses) do
		if status == validStatus then
			return true
		end
	end
	return false
end

function ServiceTypes.ValidateRateLimitType(limitType: any): boolean
	local validTypes = { "CHAT", "MOVEMENT", "COMBAT", "INVENTORY", "TRADING", "DEBUG" }
	for _, validType in ipairs(validTypes) do
		if limitType == validType then
			return true
		end
	end
	return false
end

function ServiceTypes.ValidateAdminLevel(level: any): boolean
	local validLevels = { "NONE", "MODERATOR", "ADMIN", "OWNER" }
	for _, validLevel in ipairs(validLevels) do
		if level == validLevel then
			return true
		end
	end
	return false
end

-- Создание дефолтного конфига менеджера
function ServiceTypes.CreateDefaultServiceManagerConfig(): ServiceManagerConfig
	return {
		EnableLogging = true,
		LogLevel = "INFO",
		StartupTimeout = 30,
		HealthCheckInterval = 60,
	}
end

-- Создание дефолтного конфига автосохранения
function ServiceTypes.CreateDefaultAutoSaveConfig(): AutoSaveConfig
	return {
		Enabled = true,
		Interval = 300, -- 5 минут
		BackupCount = 3,
		SaveOnShutdown = true,
	}
end

return ServiceTypes
