-- src/shared/utils/ValidationUtils.lua
-- Утилиты для валидации данных

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local ValidationUtils = {}

-- Результат валидации
export type ValidationResult = {
	IsValid: boolean,
	ErrorMessage: string?,
	ErrorCode: string?,
	FieldName: string?,
}

-- Создание результата валидации
function ValidationUtils.CreateResult(
	isValid: boolean,
	errorMessage: string?,
	errorCode: string?,
	fieldName: string?
): ValidationResult
	return {
		IsValid = isValid,
		ErrorMessage = errorMessage,
		ErrorCode = errorCode,
		FieldName = fieldName,
	}
end

-- Успешный результат
function ValidationUtils.Success(): ValidationResult
	return ValidationUtils.CreateResult(true)
end

-- Неуспешный результат
function ValidationUtils.Failure(errorMessage: string, errorCode: string?, fieldName: string?): ValidationResult
	return ValidationUtils.CreateResult(false, errorMessage, errorCode, fieldName)
end

---[[ БАЗОВЫЕ ВАЛИДАТОРЫ ]]---

-- Проверка типа
function ValidationUtils.ValidateType(value: any, expectedType: string, fieldName: string?): ValidationResult
	local actualType = type(value)
	if actualType ~= expectedType then
		return ValidationUtils.Failure(
			string.format("Expected %s, got %s", expectedType, actualType),
			"INVALID_TYPE",
			fieldName
		)
	end
	return ValidationUtils.Success()
end

-- Проверка что значение не nil
function ValidationUtils.ValidateNotNil(value: any, fieldName: string?): ValidationResult
	if value == nil then
		return ValidationUtils.Failure("Value cannot be nil", "NIL_VALUE", fieldName)
	end
	return ValidationUtils.Success()
end

-- Проверка диапазона чисел
function ValidationUtils.ValidateNumberRange(value: any, min: number, max: number, fieldName: string?): ValidationResult
	local typeResult = ValidationUtils.ValidateType(value, "number", fieldName)
	if not typeResult.IsValid then
		return typeResult
	end

	if value < min or value > max then
		return ValidationUtils.Failure(
			string.format("Value must be between %s and %s, got %s", tostring(min), tostring(max), tostring(value)),
			"OUT_OF_RANGE",
			fieldName
		)
	end

	return ValidationUtils.Success()
end

-- Проверка что число целое
function ValidationUtils.ValidateInteger(value: any, fieldName: string?): ValidationResult
	local typeResult = ValidationUtils.ValidateType(value, "number", fieldName)
	if not typeResult.IsValid then
		return typeResult
	end

	if value ~= math.floor(value) then
		return ValidationUtils.Failure("Value must be an integer", "NOT_INTEGER", fieldName)
	end

	return ValidationUtils.Success()
end

-- Проверка длины строки
function ValidationUtils.ValidateStringLength(
	value: any,
	minLength: number,
	maxLength: number,
	fieldName: string?
): ValidationResult
	local typeResult = ValidationUtils.ValidateType(value, "string", fieldName)
	if not typeResult.IsValid then
		return typeResult
	end

	local length = #value
	if length < minLength or length > maxLength then
		return ValidationUtils.Failure(
			string.format(
				"String length must be between %s and %s, got %s",
				tostring(minLength),
				tostring(maxLength),
				tostring(length)
			),
			"INVALID_STRING_LENGTH",
			fieldName
		)
	end

	return ValidationUtils.Success()
end

-- Проверка что строка не пустая
function ValidationUtils.ValidateNonEmptyString(value: any, fieldName: string?): ValidationResult
	local typeResult = ValidationUtils.ValidateType(value, "string", fieldName)
	if not typeResult.IsValid then
		return typeResult
	end

	if #value == 0 then
		return ValidationUtils.Failure("String cannot be empty", "EMPTY_STRING", fieldName)
	end

	return ValidationUtils.Success()
end

-- Проверка что значение в списке допустимых
function ValidationUtils.ValidateEnum(value: any, validValues: { any }, fieldName: string?): ValidationResult
	for _, validValue in ipairs(validValues) do
		if value == validValue then
			return ValidationUtils.Success()
		end
	end

	local validValuesStr = table.concat(validValues, ", ")
	return ValidationUtils.Failure(
		string.format("Value must be one of: %s, got %s", validValuesStr, tostring(value)),
		"INVALID_ENUM_VALUE",
		fieldName
	)
end

-- Проверка массива
function ValidationUtils.ValidateArray(
	value: any,
	elementValidator: (any, number) -> ValidationResult,
	fieldName: string?
): ValidationResult
	local typeResult = ValidationUtils.ValidateType(value, "table", fieldName)
	if not typeResult.IsValid then
		return typeResult
	end

	for i, element in ipairs(value) do
		local elementResult = elementValidator(element, i)
		if not elementResult.IsValid then
			elementResult.FieldName = string.format("%s[%s]", fieldName or "array", i)
			return elementResult
		end
	end

	return ValidationUtils.Success()
end

---[[ ИГРОВЫЕ ВАЛИДАТОРЫ ]]---

-- Проверка UserId
function ValidationUtils.ValidateUserId(userId: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(userId, "number", "UserId")
	if not typeResult.IsValid then
		return typeResult
	end

	local intResult = ValidationUtils.ValidateInteger(userId, "UserId")
	if not intResult.IsValid then
		return intResult
	end

	if userId <= 0 then
		return ValidationUtils.Failure("UserId must be positive", "INVALID_USER_ID", "UserId")
	end

	return ValidationUtils.Success()
end

-- Проверка уровня игрока
function ValidationUtils.ValidatePlayerLevel(level: any): ValidationResult
	return ValidationUtils.ValidateNumberRange(level, 1, Constants.PLAYER.MAX_LEVEL, "Level")
end

-- Проверка опыта
function ValidationUtils.ValidateExperience(experience: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(experience, "number", "Experience")
	if not typeResult.IsValid then
		return typeResult
	end

	local intResult = ValidationUtils.ValidateInteger(experience, "Experience")
	if not intResult.IsValid then
		return intResult
	end

	if experience < 0 then
		return ValidationUtils.Failure("Experience cannot be negative", "NEGATIVE_EXPERIENCE", "Experience")
	end

	return ValidationUtils.Success()
end

-- Проверка характеристик игрока
function ValidationUtils.ValidatePlayerAttributes(attributes: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(attributes, "table", "Attributes")
	if not typeResult.IsValid then
		return typeResult
	end

	local requiredAttributes = { "Strength", "Dexterity", "Intelligence", "Constitution", "Focus" }
	local attributeMin = 1
	local attributeMax = 1000
	local totalMax = 5000

	local total = 0

	-- Проверяем каждый атрибут
	for _, attrName in ipairs(requiredAttributes) do
		local attrValue = attributes[attrName]

		if attrValue == nil then
			return ValidationUtils.Failure(
				string.format("Missing required attribute: %s", attrName),
				"MISSING_ATTRIBUTE",
				attrName
			)
		end

		local attrResult = ValidationUtils.ValidateNumberRange(attrValue, attributeMin, attributeMax, attrName)
		if not attrResult.IsValid then
			return attrResult
		end

		local intResult = ValidationUtils.ValidateInteger(attrValue, attrName)
		if not intResult.IsValid then
			return intResult
		end

		total = total + attrValue
	end

	-- Проверяем общую сумму
	if total > totalMax then
		return ValidationUtils.Failure(
			string.format("Total attributes cannot exceed %s, got %s", tostring(totalMax), tostring(total)),
			"ATTRIBUTES_TOTAL_TOO_HIGH",
			"Attributes"
		)
	end

	return ValidationUtils.Success()
end

-- Проверка золота
function ValidationUtils.ValidateGold(gold: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(gold, "number", "Gold")
	if not typeResult.IsValid then
		return typeResult
	end

	local intResult = ValidationUtils.ValidateInteger(gold, "Gold")
	if not intResult.IsValid then
		return intResult
	end

	return ValidationUtils.ValidateNumberRange(gold, 0, 1000000000, "Gold")
end

-- Проверка здоровья
function ValidationUtils.ValidateHealth(health: any, maxHealth: number?): ValidationResult
	local typeResult = ValidationUtils.ValidateType(health, "number", "Health")
	if not typeResult.IsValid then
		return typeResult
	end

	local max = maxHealth or 50000
	return ValidationUtils.ValidateNumberRange(health, 0, max, "Health")
end

-- Проверка маны
function ValidationUtils.ValidateMana(mana: any, maxMana: number?): ValidationResult
	local typeResult = ValidationUtils.ValidateType(mana, "number", "Mana")
	if not typeResult.IsValid then
		return typeResult
	end

	local max = maxMana or 10000
	return ValidationUtils.ValidateNumberRange(mana, 0, max, "Mana")
end

-- Проверка стамины
function ValidationUtils.ValidateStamina(stamina: any, maxStamina: number?): ValidationResult
	local typeResult = ValidationUtils.ValidateType(stamina, "number", "Stamina")
	if not typeResult.IsValid then
		return typeResult
	end

	local max = maxStamina or 5000
	return ValidationUtils.ValidateNumberRange(stamina, 0, max, "Stamina")
end

-- Проверка настроек громкости
function ValidationUtils.ValidateVolume(volume: any, fieldName: string?): ValidationResult
	return ValidationUtils.ValidateNumberRange(volume, 0.0, 1.0, fieldName)
end

-- Проверка имени игрока (для чата, гильдий и т.д.)
function ValidationUtils.ValidatePlayerName(name: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(name, "string", "PlayerName")
	if not typeResult.IsValid then
		return typeResult
	end

	local lengthResult = ValidationUtils.ValidateStringLength(name, 1, 20, "PlayerName")
	if not lengthResult.IsValid then
		return lengthResult
	end

	-- Проверка на недопустимые символы
	if string.match(name, "[^%w_%-]") then
		return ValidationUtils.Failure(
			"Player name can only contain letters, numbers, underscore and dash",
			"INVALID_PLAYER_NAME_CHARACTERS",
			"PlayerName"
		)
	end

	return ValidationUtils.Success()
end

-- Проверка сообщения чата
function ValidationUtils.ValidateChatMessage(message: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(message, "string", "ChatMessage")
	if not typeResult.IsValid then
		return typeResult
	end

	local lengthResult = ValidationUtils.ValidateStringLength(message, 1, 200, "ChatMessage")
	if not lengthResult.IsValid then
		return lengthResult
	end

	-- Проверка на недопустимый контент (базовая)
	local lowerMessage = string.lower(message)
	local bannedWords = { "admin", "hack", "exploit", "script" } -- Примеры

	for _, word in ipairs(bannedWords) do
		if string.find(lowerMessage, word) then
			return ValidationUtils.Failure(
				"Message contains inappropriate content",
				"INAPPROPRIATE_CONTENT",
				"ChatMessage"
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ КОМПЛЕКСНЫЕ ВАЛИДАТОРЫ ]]---

-- Проверка полного профиля игрока
function ValidationUtils.ValidatePlayerProfile(profile: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(profile, "table", "PlayerProfile")
	if not typeResult.IsValid then
		return typeResult
	end

	-- Проверяем уровень
	local levelResult = ValidationUtils.ValidatePlayerLevel(profile.Level)
	if not levelResult.IsValid then
		return levelResult
	end

	-- Проверяем опыт
	local expResult = ValidationUtils.ValidateExperience(profile.Experience)
	if not expResult.IsValid then
		return expResult
	end

	-- Проверяем характеристики
	if profile.Attributes then
		local attrResult = ValidationUtils.ValidatePlayerAttributes(profile.Attributes)
		if not attrResult.IsValid then
			return attrResult
		end
	end

	-- Проверяем валюту
	if profile.Currency and profile.Currency.Gold then
		local goldResult = ValidationUtils.ValidateGold(profile.Currency.Gold)
		if not goldResult.IsValid then
			return goldResult
		end
	end

	-- Проверяем ресурсы
	if profile.Health then
		local healthResult = ValidationUtils.ValidateHealth(profile.Health)
		if not healthResult.IsValid then
			return healthResult
		end
	end

	if profile.Mana then
		local manaResult = ValidationUtils.ValidateMana(profile.Mana)
		if not manaResult.IsValid then
			return manaResult
		end
	end

	if profile.Stamina then
		local staminaResult = ValidationUtils.ValidateStamina(profile.Stamina)
		if not staminaResult.IsValid then
			return staminaResult
		end
	end

	return ValidationUtils.Success()
end

-- Проверка данных для сохранения
function ValidationUtils.ValidateDataForSave(data: any): ValidationResult
	-- Проверяем размер данных (не более 4MB для ProfileService)
	local success, dataString = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), data)
	if not success then
		return ValidationUtils.Failure("Data cannot be encoded to JSON", "JSON_ENCODE_ERROR", "SaveData")
	end

	local dataSize = #dataString
	local maxSize = 4 * 1024 * 1024 -- 4MB

	if dataSize > maxSize then
		return ValidationUtils.Failure(
			string.format("Data size (%s bytes) exceeds maximum (%s bytes)", dataSize, maxSize),
			"DATA_TOO_LARGE",
			"SaveData"
		)
	end

	return ValidationUtils.Success()
end

---[[ СЕТЕВЫЕ ВАЛИДАТОРЫ ]]---

-- Проверка rate limit типа
function ValidationUtils.ValidateRateLimitType(limitType: any): ValidationResult
	local validTypes = { "CHAT", "MOVEMENT", "COMBAT", "INVENTORY", "TRADING", "DEBUG" }
	return ValidationUtils.ValidateEnum(limitType, validTypes, "RateLimitType")
end

-- Проверка системного сообщения
function ValidationUtils.ValidateSystemMessage(messageData: any): ValidationResult
	local typeResult = ValidationUtils.ValidateType(messageData, "table", "SystemMessage")
	if not typeResult.IsValid then
		return typeResult
	end

	-- Проверяем обязательные поля
	if not messageData.Message then
		return ValidationUtils.Failure("System message must have Message field", "MISSING_MESSAGE", "SystemMessage")
	end

	local messageResult = ValidationUtils.ValidateStringLength(messageData.Message, 1, 500, "Message")
	if not messageResult.IsValid then
		return messageResult
	end

	-- Проверяем тип сообщения
	if messageData.Type then
		local validTypes = { "INFO", "SUCCESS", "WARNING", "ERROR", "CRITICAL" }
		local msgTypeResult = ValidationUtils.ValidateEnum(messageData.Type, validTypes, "MessageType")
		if not msgTypeResult.IsValid then
			return msgTypeResult
		end
	end

	return ValidationUtils.Success()
end

---[[ УТИЛИТЫ ДЛЯ МАССОВОЙ ВАЛИДАЦИИ ]]---

-- Валидация списка результатов
function ValidationUtils.ValidateMultiple(results: { ValidationResult }): ValidationResult
	for _, result in ipairs(results) do
		if not result.IsValid then
			-- Возвращаем первую найденную ошибку
			return result
		end
	end
	return ValidationUtils.Success()
end

-- Безопасная валидация с логированием
function ValidationUtils.SafeValidate(validator: () -> ValidationResult, context: string?): ValidationResult
	local success, result = pcall(validator)

	if not success then
		warn(string.format("[VALIDATION ERROR] %s: %s", context or "Unknown", tostring(result)))
		return ValidationUtils.Failure("Validation function error", "VALIDATOR_ERROR", context)
	end

	return result
end

-- Создание валидатора с кэшированием для производительности
function ValidationUtils.CreateCachedValidator(validator: (any) -> ValidationResult)
	local cache = {}

	return function(value: any): ValidationResult
		local valueStr = tostring(value)

		if cache[valueStr] then
			return cache[valueStr]
		end

		local result = validator(value)
		cache[valueStr] = result

		-- Ограничиваем размер кэша
		if #cache > 1000 then
			cache = {}
		end

		return result
	end
end

-- Дебаг информация о валидации
function ValidationUtils.CreateValidationSummary(results: { ValidationResult }): {
	TotalChecks: number,
	PassedChecks: number,
	FailedChecks: number,
	ErrorCodes: { string },
	FirstError: ValidationResult?,
}
	local summary = {
		TotalChecks = #results,
		PassedChecks = 0,
		FailedChecks = 0,
		ErrorCodes = {},
		FirstError = nil,
	}

	for _, result in ipairs(results) do
		if result.IsValid then
			summary.PassedChecks = summary.PassedChecks + 1
		else
			summary.FailedChecks = summary.FailedChecks + 1

			if result.ErrorCode then
				table.insert(summary.ErrorCodes, result.ErrorCode)
			end

			if not summary.FirstError then
				summary.FirstError = result
			end
		end
	end

	return summary
end

return ValidationUtils
