-- src/server/services/ValidationService.lua
-- Основной сервис валидации - координирует все типы проверок

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)

-- Импортируем модули валидаторов
local PlayerValidator = require(script.Parent.validation.PlayerValidator)
local ExperienceValidator = require(script.Parent.validation.ExperienceValidator)
local NetworkValidator = require(script.Parent.validation.NetworkValidator)
local GameRulesValidator = require(script.Parent.validation.GameRulesValidator)

local ValidationService = setmetatable({}, { __index = BaseService })
ValidationService.__index = ValidationService

function ValidationService.new()
	local self = setmetatable(BaseService.new("ValidationService"), ValidationService)

	-- Кэш для результатов валидации (для производительности)
	self.ValidationCache = {}
	self.CacheSize = 0
	self.MaxCacheSize = 1000

	-- Статистика валидации
	self.ValidationStats = {
		TotalValidations = 0,
		PassedValidations = 0,
		FailedValidations = 0,
		CacheHits = 0,
		MostCommonErrors = {},
		LastReset = os.time(),
	}

	-- Настройки валидации
	self.Settings = {
		EnableCaching = true,
		LogFailedValidations = true,
		LogLevel = "WARN", -- DEBUG, INFO, WARN, ERROR
		ThrowOnValidationError = false, -- Для разработки
	}

	-- Модули валидаторов
	self.PlayerValidator = PlayerValidator.new(self)
	self.ExperienceValidator = ExperienceValidator.new(self)
	self.NetworkValidator = NetworkValidator.new(self)
	self.GameRulesValidator = GameRulesValidator.new(self)

	return self
end

function ValidationService:OnInitialize()
	print("[VALIDATION SERVICE] Initializing validation rules...")

	-- Инициализируем все валидаторы
	self.PlayerValidator:Initialize()
	self.ExperienceValidator:Initialize()
	self.NetworkValidator:Initialize()
	self.GameRulesValidator:Initialize()

	print("[VALIDATION SERVICE] All validators initialized")
end

function ValidationService:OnStart()
	print("[VALIDATION SERVICE] Validation service ready!")

	-- Запускаем очистку кэша каждые 5 минут
	spawn(function()
		while true do
			wait(300) -- 5 минут
			self:CleanupCache()
		end
	end)
end

---[[ ОСНОВНЫЕ МЕТОДЫ ВАЛИДАЦИИ ]]---

-- Валидация данных игрока
function ValidationService:ValidatePlayerData(data: any, playerId: number?): ValidationUtils.ValidationResult
	local cacheKey = self:GenerateCacheKey("PlayerData", data)

	-- Проверяем кэш
	if self.Settings.EnableCaching then
		local cachedResult = self:GetFromCache(cacheKey)
		if cachedResult then
			self.ValidationStats.CacheHits = self.ValidationStats.CacheHits + 1
			return cachedResult
		end
	end

	-- Выполняем валидацию через PlayerValidator
	local result = self.PlayerValidator:ValidatePlayerProfile(data)

	-- Дополнительные проверки игровых правил
	if result.IsValid then
		result = self.GameRulesValidator:ValidateGameSpecificRules(data, playerId)
	end

	-- Сохраняем в кэш и обновляем статистику
	self:ProcessValidationResult(result, cacheKey, "PlayerData", playerId)

	return result
end

-- Валидация изменений уровня
function ValidationService:ValidateLevelChange(
	currentLevel: number,
	newLevel: number,
	playerId: number?
): ValidationUtils.ValidationResult
	local result = self.ExperienceValidator:ValidateLevelChange(currentLevel, newLevel, playerId)
	self:ProcessValidationResult(result, nil, "LevelChange", playerId)
	return result
end

-- Валидация изменений опыта
function ValidationService:ValidateExperienceChange(
	currentExp: number,
	addedExp: number,
	playerId: number?
): ValidationUtils.ValidationResult
	local result = self.ExperienceValidator:ValidateExperienceChange(currentExp, addedExp, playerId)
	self:ProcessValidationResult(result, nil, "ExperienceChange", playerId)
	return result
end

-- Валидация опыта для уровня
function ValidationService:ValidateExperienceForLevel(
	level: number,
	currentExperience: number
): ValidationUtils.ValidationResult
	local result = self.ExperienceValidator:ValidateExperienceForLevel(level, currentExperience)
	self:ProcessValidationResult(result, nil, "ExperienceForLevel")
	return result
end

-- Валидация транзакций с золотом
function ValidationService:ValidateGoldTransaction(
	currentGold: number,
	change: number,
	transactionType: string,
	playerId: number?
): ValidationUtils.ValidationResult
	local result = self.PlayerValidator:ValidateGoldTransaction(currentGold, change, transactionType, playerId)
	self:ProcessValidationResult(result, nil, "GoldTransaction", playerId)
	return result
end

-- Валидация сетевых запросов
function ValidationService:ValidateNetworkRequest(
	player: Player,
	requestEventName: string,
	data: any
): ValidationUtils.ValidationResult
	local result = self.NetworkValidator:ValidateNetworkRequest(player, requestEventName, data)
	self:ProcessValidationResult(result, nil, "NetworkRequest", player.UserId)
	return result
end

-- Валидация целостности данных
function ValidationService:ValidateDataIntegrity(data: any): ValidationUtils.ValidationResult
	local result = self.PlayerValidator:ValidateDataIntegrity(data)
	self:ProcessValidationResult(result, nil, "DataIntegrity")
	return result
end

-- Валидация для админских действий
function ValidationService:ValidateAdminAction(
	adminPlayer: Player,
	action: string,
	targetPlayer: Player?,
	data: any?
): ValidationUtils.ValidationResult
	local result = self.NetworkValidator:ValidateAdminAction(adminPlayer, action, targetPlayer, data)
	self:ProcessValidationResult(result, nil, "AdminAction", adminPlayer.UserId)
	return result
end

---[[ СЛУЖЕБНЫЕ МЕТОДЫ ]]---

-- Обработка результата валидации (кэш + статистика + логирование)
function ValidationService:ProcessValidationResult(
	result: ValidationUtils.ValidationResult,
	cacheKey: string?,
	validationType: string,
	playerId: number?
)
	-- Сохраняем в кэш
	if self.Settings.EnableCaching and cacheKey then
		self:SaveToCache(cacheKey, result)
	end

	-- Обновляем статистику
	self:UpdateValidationStats(result)

	-- Логируем при необходимости
	if not result.IsValid and self.Settings.LogFailedValidations then
		self:LogValidationFailure(validationType, result, playerId)
	end
end

---[[ КЭШИРОВАНИЕ ]]---

-- Генерация ключа для кэша
function ValidationService:GenerateCacheKey(validationType: string, data: any): string
	local success, dataString = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), data)
	if success then
		-- Используем простой хеш строки
		local hash = 0
		for i = 1, #dataString do
			hash = (hash * 31 + string.byte(dataString, i)) % 2147483647
		end
		return validationType .. "_" .. tostring(hash)
	else
		return validationType .. "_" .. tostring(data)
	end
end

-- Получение из кэша
function ValidationService:GetFromCache(key: string): ValidationUtils.ValidationResult?
	return self.ValidationCache[key]
end

-- Сохранение в кэш
function ValidationService:SaveToCache(key: string, result: ValidationUtils.ValidationResult)
	if self.CacheSize >= self.MaxCacheSize then
		self:CleanupCache()
	end

	self.ValidationCache[key] = result
	self.CacheSize = self.CacheSize + 1
end

-- Очистка кэша
function ValidationService:CleanupCache()
	self.ValidationCache = {}
	self.CacheSize = 0
	print("[VALIDATION SERVICE] Cache cleared")
end

---[[ СТАТИСТИКА И ЛОГИРОВАНИЕ ]]---

-- Обновление статистики валидации
function ValidationService:UpdateValidationStats(result: ValidationUtils.ValidationResult)
	self.ValidationStats.TotalValidations = self.ValidationStats.TotalValidations + 1

	if result.IsValid then
		self.ValidationStats.PassedValidations = self.ValidationStats.PassedValidations + 1
	else
		self.ValidationStats.FailedValidations = self.ValidationStats.FailedValidations + 1

		-- Отслеживаем частые ошибки
		if result.ErrorCode then
			local errorCode = result.ErrorCode
			self.ValidationStats.MostCommonErrors[errorCode] = (self.ValidationStats.MostCommonErrors[errorCode] or 0)
				+ 1
		end
	end
end

-- Логирование неудачной валидации
function ValidationService:LogValidationFailure(
	validationType: string,
	result: ValidationUtils.ValidationResult,
	playerId: number?
)
	local playerInfo = playerId and ("Player " .. playerId) or "Unknown Player"
	local errorMsg = string.format(
		"[VALIDATION FAILURE] %s - %s: %s (Code: %s, Field: %s)",
		validationType,
		playerInfo,
		result.ErrorMessage or "Unknown error",
		result.ErrorCode or "UNKNOWN",
		result.FieldName or "Unknown"
	)

	if self.Settings.LogLevel == "DEBUG" then
		print(errorMsg)
	else
		warn(errorMsg)
	end
end

-- Получение статистики валидации
function ValidationService:GetValidationStatistics(): {
	TotalValidations: number,
	PassedValidations: number,
	FailedValidations: number,
	SuccessRate: number,
	CacheHits: number,
	CacheHitRate: number,
	MostCommonErrors: { [string]: number },
	UptimeHours: number,
}
	local successRate = 0
	if self.ValidationStats.TotalValidations > 0 then
		successRate = (self.ValidationStats.PassedValidations / self.ValidationStats.TotalValidations) * 100
	end

	local cacheHitRate = 0
	if self.ValidationStats.TotalValidations > 0 then
		cacheHitRate = (self.ValidationStats.CacheHits / self.ValidationStats.TotalValidations) * 100
	end

	local uptimeHours = (os.time() - self.ValidationStats.LastReset) / 3600

	return {
		TotalValidations = self.ValidationStats.TotalValidations,
		PassedValidations = self.ValidationStats.PassedValidations,
		FailedValidations = self.ValidationStats.FailedValidations,
		SuccessRate = math.floor(successRate * 100) / 100,
		CacheHits = self.ValidationStats.CacheHits,
		CacheHitRate = math.floor(cacheHitRate * 100) / 100,
		MostCommonErrors = self.ValidationStats.MostCommonErrors,
		UptimeHours = math.floor(uptimeHours * 100) / 100,
	}
end

-- Сброс статистики
function ValidationService:ResetStatistics()
	self.ValidationStats = {
		TotalValidations = 0,
		PassedValidations = 0,
		FailedValidations = 0,
		CacheHits = 0,
		MostCommonErrors = {},
		LastReset = os.time(),
	}

	print("[VALIDATION SERVICE] Statistics reset")
end

---[[ НАСТРОЙКИ И КОНФИГУРАЦИЯ ]]---

-- Обновление настроек валидации
function ValidationService:UpdateSettings(newSettings: { [string]: any })
	for key, value in pairs(newSettings) do
		if self.Settings[key] ~= nil then
			self.Settings[key] = value
			print(string.format("[VALIDATION SERVICE] Setting %s updated to %s", key, tostring(value)))
		else
			warn(string.format("[VALIDATION SERVICE] Unknown setting: %s", key))
		end
	end
end

-- Получение текущих настроек
function ValidationService:GetSettings(): { [string]: any }
	return table.clone(self.Settings)
end

-- Валидация в режиме разработки (более строгая)
function ValidationService:SetDevelopmentMode(enabled: boolean)
	self.Settings.ThrowOnValidationError = enabled
	self.Settings.LogLevel = enabled and "DEBUG" or "WARN"
	self.Settings.LogFailedValidations = enabled

	print(string.format("[VALIDATION SERVICE] Development mode: %s", enabled and "ENABLED" or "DISABLED"))
end

---[[ МАССОВАЯ ВАЛИДАЦИЯ ]]---

-- Валидация множественных элементов
function ValidationService:ValidateMultiple(validations: { { ValidationType: string, Data: any, PlayerId: number? } }): {
	TotalValidations: number,
	PassedValidations: number,
	FailedValidations: number,
	Results: { ValidationUtils.ValidationResult },
	FirstFailure: ValidationUtils.ValidationResult?,
}
	local results = {
		TotalValidations = #validations,
		PassedValidations = 0,
		FailedValidations = 0,
		Results = {},
		FirstFailure = nil,
	}

	for _, validation in ipairs(validations) do
		local result: ValidationUtils.ValidationResult

		if validation.ValidationType == "PlayerData" then
			result = self:ValidatePlayerData(validation.Data, validation.PlayerId)
		elseif validation.ValidationType == "NetworkRequest" then
			-- Для сетевых запросов нужен player объект, пропускаем
			result = ValidationUtils.Success()
		else
			result = ValidationUtils.Failure(
				string.format("Unknown validation type: %s", validation.ValidationType),
				"UNKNOWN_VALIDATION_TYPE"
			)
		end

		table.insert(results.Results, result)

		if result.IsValid then
			results.PassedValidations = results.PassedValidations + 1
		else
			results.FailedValidations = results.FailedValidations + 1
			if not results.FirstFailure then
				results.FirstFailure = result
			end
		end
	end

	return results
end

function ValidationService:OnCleanup()
	-- Очищаем кэш и статистику
	self:CleanupCache()

	-- Выводим финальную статистику
	local stats = self:GetValidationStatistics()
	print("[VALIDATION SERVICE] Final statistics:")
	print(string.format("  Total validations: %d", stats.TotalValidations))
	print(string.format("  Success rate: %.2f%%", stats.SuccessRate))
	print(string.format("  Cache hit rate: %.2f%%", stats.CacheHitRate))
	print(string.format("  Uptime: %.2f hours", stats.UptimeHours))
end

return ValidationService
