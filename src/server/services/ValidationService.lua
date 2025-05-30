-- src/server/services/ValidationService.lua
-- Централизованный сервис для валидации всех данных

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

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

	return self
end

function ValidationService:OnInitialize()
	print("[VALIDATION SERVICE] Initializing validation rules...")
	self:InitializeValidationRules()
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

-- Инициализация правил валидации
function ValidationService:InitializeValidationRules()
	-- Здесь можно добавить специфичные для игры правила валидации
	print("[VALIDATION SERVICE] Validation rules initialized")
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

	-- Выполняем валидацию
	local result = ValidationUtils.ValidatePlayerProfile(data)

	-- Дополнительные проверки для игровых данных
	if result.IsValid then
		result = self:ValidateGameSpecificRules(data, playerId)
	end

	-- Сохраняем в кэш
	if self.Settings.EnableCaching then
		self:SaveToCache(cacheKey, result)
	end

	-- Обновляем статистику
	self:UpdateValidationStats(result)

	-- Логируем при необходимости
	if not result.IsValid and self.Settings.LogFailedValidations then
		self:LogValidationFailure("PlayerData", result, playerId)
	end

	return result
end

-- Валидация изменений уровня
function ValidationService:ValidateLevelChange(
	currentLevel: number,
	newLevel: number,
	playerId: number?
): ValidationUtils.ValidationResult
	-- Проверяем базовую валидность уровней
	local currentLevelResult = ValidationUtils.ValidatePlayerLevel(currentLevel)
	if not currentLevelResult.IsValid then
		return currentLevelResult
	end

	local newLevelResult = ValidationUtils.ValidatePlayerLevel(newLevel)
	if not newLevelResult.IsValid then
		return newLevelResult
	end

	-- Проверяем логику изменения уровня
	if newLevel < currentLevel then
		return ValidationUtils.Failure("Level cannot decrease", "INVALID_LEVEL_DECREASE", "LevelChange")
	end

	if newLevel > currentLevel + 1 then
		return ValidationUtils.Failure("Level can only increase by 1 at a time", "INVALID_LEVEL_JUMP", "LevelChange")
	end

	return ValidationUtils.Success()
end

-- Валидация изменений опыта
function ValidationService:ValidateExperienceChange(
	currentExp: number,
	addedExp: number,
	playerId: number?
): ValidationUtils.ValidationResult
	-- Проверяем базовую валидность опыта
	local currentExpResult = ValidationUtils.ValidateExperience(currentExp)
	if not currentExpResult.IsValid then
		return currentExpResult
	end

	local addedExpResult = ValidationUtils.ValidateExperience(addedExp)
	if not addedExpResult.IsValid then
		return addedExpResult
	end

	-- Проверяем разумность добавляемого опыта
	if addedExp <= 0 then
		return ValidationUtils.Failure(
			"Added experience must be positive",
			"INVALID_EXPERIENCE_AMOUNT",
			"ExperienceChange"
		)
	end

	-- Проверяем максимальный опыт за раз (защита от читов)
	local maxExpPerAction = 10000 -- Максимум 10k опыта за одно действие
	if addedExp > maxExpPerAction then
		return ValidationUtils.Failure(
			string.format("Experience gain too large: %d (max: %d)", addedExp, maxExpPerAction),
			"EXCESSIVE_EXPERIENCE_GAIN",
			"ExperienceChange"
		)
	end

	return ValidationUtils.Success()
end

-- Валидация транзакций с золотом
function ValidationService:ValidateGoldTransaction(
	currentGold: number,
	change: number,
	transactionType: string,
	playerId: number?
): ValidationUtils.ValidationResult
	-- Проверяем текущее золото
	local currentGoldResult = ValidationUtils.ValidateGold(currentGold)
	if not currentGoldResult.IsValid then
		return currentGoldResult
	end

	-- Проверяем новое количество золота
	local newGold = currentGold + change
	local newGoldResult = ValidationUtils.ValidateGold(newGold)
	if not newGoldResult.IsValid then
		return newGoldResult
	end

	-- Проверяем тип транзакции
	local validTransactionTypes =
		{ "QUEST_REWARD", "ITEM_SALE", "ITEM_PURCHASE", "TRADE", "ADMIN_GRANT", "REPAIR_COST" }
	local typeResult = ValidationUtils.ValidateEnum(transactionType, validTransactionTypes, "TransactionType")
	if not typeResult.IsValid then
		return typeResult
	end

	-- Проверяем разумность изменения
	local maxChange = 1000000 -- Максимальное изменение золота за раз
	if math.abs(change) > maxChange then
		return ValidationUtils.Failure(
			string.format("Gold change too large: %d (max: %d)", math.abs(change), maxChange),
			"EXCESSIVE_GOLD_CHANGE",
			"GoldTransaction"
		)
	end

	-- Проверяем, что у игрока достаточно золота для трат
	if change < 0 and currentGold < math.abs(change) then
		return ValidationUtils.Failure(
			string.format("Insufficient gold: has %d, needs %d", currentGold, math.abs(change)),
			"INSUFFICIENT_GOLD",
			"GoldTransaction"
		)
	end

	return ValidationUtils.Success()
end

-- Валидация сетевых запросов
function ValidationService:ValidateNetworkRequest(
	player: Player,
	eventName: string,
	data: any
): ValidationUtils.ValidationResult
	-- Проверяем игрока
	if not player or player.Parent ~= game:GetService("Players") then
		return ValidationUtils.Failure("Invalid player", "INVALID_PLAYER", "NetworkRequest")
	end

	-- Проверяем имя события
	local eventNameResult = ValidationUtils.ValidateNonEmptyString(eventName, "EventName")
	if not eventNameResult.IsValid then
		return eventNameResult
	end

	-- Проверяем, что событие существует
	local validEvents = {}
	for _, eventName in pairs(Constants.REMOTE_EVENTS) do
		validEvents[eventName] = true
	end

	if not validEvents[eventName] then
		return ValidationUtils.Failure(string.format("Unknown event: %s", eventName), "UNKNOWN_EVENT", "NetworkRequest")
	end

	-- Проверяем размер данных
	if data then
		local success, dataString =
			pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), data)
		if success then
			local dataSize = #dataString
			local maxDataSize = 100 * 1024 -- 100KB максимум для сетевых запросов

			if dataSize > maxDataSize then
				return ValidationUtils.Failure(
					string.format("Request data too large: %d bytes (max: %d)", dataSize, maxDataSize),
					"REQUEST_DATA_TOO_LARGE",
					"NetworkRequest"
				)
			end
		end
	end

	return ValidationUtils.Success()
end

-- Валидация инвентаря (будущая функция)
function ValidationService:ValidateInventoryOperation(
	operation: string,
	itemData: any,
	playerId: number?
): ValidationUtils.ValidationResult
	-- Placeholder for inventory validation
	-- Будет реализовано при создании системы инвентаря

	local validOperations = { "ADD_ITEM", "REMOVE_ITEM", "MOVE_ITEM", "SPLIT_STACK", "MERGE_STACK" }
	return ValidationUtils.ValidateEnum(operation, validOperations, "InventoryOperation")
end

---[[ ИГРОВЫЕ ПРАВИЛА ]]---

-- Проверка специфичных для игры правил
function ValidationService:ValidateGameSpecificRules(data: any, playerId: number?): ValidationUtils.ValidationResult
	-- Проверяем соответствие уровня и опыта
	if data.Level and data.Experience then
		local calculatedLevel = self:CalculateLevelFromTotalExperience(data.Experience, data.Level)
		if calculatedLevel ~= data.Level then
			return ValidationUtils.Failure(
				string.format(
					"Level %d doesn't match experience %d (should be %d)",
					data.Level,
					data.Experience,
					calculatedLevel
				),
				"LEVEL_EXPERIENCE_MISMATCH",
				"GameRules"
			)
		end
	end

	-- Проверяем соответствие характеристик и ресурсов
	if data.Attributes and data.Health then
		local maxHealth = Constants.PLAYER.BASE_HEALTH
			+ (data.Attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
		if data.Health > maxHealth then
			return ValidationUtils.Failure(
				string.format("Health %d exceeds maximum %d", data.Health, maxHealth),
				"HEALTH_EXCEEDS_MAXIMUM",
				"GameRules"
			)
		end
	end

	-- Проверяем разумность статистики
	if data.Statistics then
		if data.Statistics.TotalPlayTime and data.Statistics.TotalPlayTime < 0 then
			return ValidationUtils.Failure("Play time cannot be negative", "NEGATIVE_PLAY_TIME", "GameRules")
		end

		if data.Statistics.MobsKilled and data.Statistics.MobsKilled < 0 then
			return ValidationUtils.Failure("Mobs killed cannot be negative", "NEGATIVE_MOBS_KILLED", "GameRules")
		end
	end

	return ValidationUtils.Success()
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

---[[ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ]]---

-- Расчет уровня из общего опыта (для проверки соответствия)
function ValidationService:CalculateLevelFromTotalExperience(totalExperience: number, currentLevel: number): number
	-- Проверяем, соответствует ли текущий уровень опыту
	local expForCurrentLevel = 0
	for level = 1, currentLevel - 1 do
		expForCurrentLevel = expForCurrentLevel
			+ math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (level ^ Constants.EXPERIENCE.XP_MULTIPLIER))
	end

	local expForNextLevel = expForCurrentLevel
		+ math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (currentLevel ^ Constants.EXPERIENCE.XP_MULTIPLIER))

	-- Если опыт находится в правильном диапазоне, уровень корректный
	if totalExperience >= expForCurrentLevel and totalExperience < expForNextLevel then
		return currentLevel
	end

	-- Иначе пересчитываем уровень с самого начала
	local level = 1
	local currentExp = totalExperience

	while level < Constants.PLAYER.MAX_LEVEL do
		local expRequired =
			math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (level ^ Constants.EXPERIENCE.XP_MULTIPLIER))
		if currentExp < expRequired then
			break
		end
		currentExp = currentExp - expRequired
		level = level + 1
	end

	return level
end

-- Проверка целостности данных игрока
function ValidationService:ValidateDataIntegrity(data: any): ValidationUtils.ValidationResult
	-- Проверяем наличие обязательных полей
	local requiredFields = { "Level", "Experience", "Attributes", "Currency", "Statistics" }

	for _, field in ipairs(requiredFields) do
		if data[field] == nil then
			return ValidationUtils.Failure(
				string.format("Missing required field: %s", field),
				"MISSING_REQUIRED_FIELD",
				field
			)
		end
	end

	-- Проверяем типы данных
	if type(data.Level) ~= "number" then
		return ValidationUtils.Failure("Level must be a number", "INVALID_LEVEL_TYPE", "Level")
	end

	if type(data.Experience) ~= "number" then
		return ValidationUtils.Failure("Experience must be a number", "INVALID_EXPERIENCE_TYPE", "Experience")
	end

	if type(data.Attributes) ~= "table" then
		return ValidationUtils.Failure("Attributes must be a table", "INVALID_ATTRIBUTES_TYPE", "Attributes")
	end

	if type(data.Currency) ~= "table" then
		return ValidationUtils.Failure("Currency must be a table", "INVALID_CURRENCY_TYPE", "Currency")
	end

	if type(data.Statistics) ~= "table" then
		return ValidationUtils.Failure("Statistics must be a table", "INVALID_STATISTICS_TYPE", "Statistics")
	end

	return ValidationUtils.Success()
end

-- Валидация для админских действий
function ValidationService:ValidateAdminAction(
	adminPlayer: Player,
	action: string,
	targetPlayer: Player?,
	data: any?
): ValidationUtils.ValidationResult
	-- Проверяем права администратора (placeholder)
	-- В реальной игре здесь была бы проверка admin уровня

	local validAdminActions =
		{ "GRANT_EXP", "GRANT_GOLD", "SET_LEVEL", "HEAL_PLAYER", "TELEPORT_PLAYER", "BAN_PLAYER", "KICK_PLAYER" }
	local actionResult = ValidationUtils.ValidateEnum(action, validAdminActions, "AdminAction")
	if not actionResult.IsValid then
		return actionResult
	end

	-- Проверяем целевого игрока для действий, которые его требуют
	local actionsRequiringTarget =
		{ "GRANT_EXP", "GRANT_GOLD", "SET_LEVEL", "HEAL_PLAYER", "TELEPORT_PLAYER", "BAN_PLAYER", "KICK_PLAYER" }
	if table.find(actionsRequiringTarget, action) and not targetPlayer then
		return ValidationUtils.Failure(
			string.format("Action %s requires a target player", action),
			"MISSING_TARGET_PLAYER",
			"AdminAction"
		)
	end

	-- Проверяем данные для действий, которые их требуют
	local actionsRequiringData = { "GRANT_EXP", "GRANT_GOLD", "SET_LEVEL" }
	if table.find(actionsRequiringData, action) then
		if not data then
			return ValidationUtils.Failure(
				string.format("Action %s requires data", action),
				"MISSING_ACTION_DATA",
				"AdminAction"
			)
		end

		-- Специфичная валидация по типу действия
		if action == "GRANT_EXP" or action == "GRANT_GOLD" then
			local amountResult = ValidationUtils.ValidateType(data, "number", "Amount")
			if not amountResult.IsValid then
				return amountResult
			end

			if data <= 0 or data > 1000000 then
				return ValidationUtils.Failure(
					"Amount must be between 1 and 1,000,000",
					"INVALID_AMOUNT_RANGE",
					"Amount"
				)
			end
		elseif action == "SET_LEVEL" then
			local levelResult = ValidationUtils.ValidatePlayerLevel(data)
			if not levelResult.IsValid then
				return levelResult
			end
		end
	end

	return ValidationUtils.Success()
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
