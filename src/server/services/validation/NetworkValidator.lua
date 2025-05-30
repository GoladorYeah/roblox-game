-- src/server/services/validation/NetworkValidator.lua
-- Валидация сетевых запросов и админских действий

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local NetworkValidator = {}
NetworkValidator.__index = NetworkValidator

function NetworkValidator.new(validationService)
	local self = setmetatable({}, NetworkValidator)
	self.ValidationService = validationService
	return self
end

function NetworkValidator:Initialize()
	-- Инициализация правил валидации сети
	print("[NETWORK VALIDATOR] Network validation rules initialized")
end

---[[ ВАЛИДАЦИЯ СЕТЕВЫХ ЗАПРОСОВ ]]---

-- Валидация сетевых запросов
function NetworkValidator:ValidateNetworkRequest(
	player: Player,
	requestEventName: string,
	data: any
): ValidationUtils.ValidationResult
	-- Проверяем игрока
	if not player or player.Parent ~= Players then
		return ValidationUtils.Failure("Invalid player", "INVALID_PLAYER", "NetworkRequest")
	end

	-- Проверяем имя события
	local eventNameResult = ValidationUtils.ValidateNonEmptyString(requestEventName, "EventName")
	if not eventNameResult.IsValid then
		return eventNameResult
	end

	-- Проверяем, что событие существует
	local validEvents = {}
	for _, eventName in pairs(Constants.REMOTE_EVENTS) do
		validEvents[eventName] = true
	end

	if not validEvents[requestEventName] then
		return ValidationUtils.Failure(
			string.format("Unknown event: %s", requestEventName),
			"UNKNOWN_EVENT",
			"NetworkRequest"
		)
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
		else
			return ValidationUtils.Failure(
				"Request data cannot be serialized",
				"INVALID_REQUEST_DATA",
				"NetworkRequest"
			)
		end
	end

	-- Проверяем подозрительные паттерны
	local suspiciousResult = self:CheckSuspiciousPatterns(player, requestEventName, data)
	if not suspiciousResult.IsValid then
		return suspiciousResult
	end

	return ValidationUtils.Success()
end

-- Проверка подозрительных паттернов в запросах
function NetworkValidator:CheckSuspiciousPatterns(
	player: Player,
	eventName: string,
	data: any
): ValidationUtils.ValidationResult
	-- Проверяем на SQL injection паттерны в строковых данных
	if data and type(data) == "table" then
		local function checkSqlInjection(value)
			if type(value) == "string" then
				local suspiciousPatterns = {
					"['\"];",
					"union%s+select",
					"drop%s+table",
					"insert%s+into",
					"delete%s+from",
					"update%s+.*%s+set",
					"script%s*:",
					"javascript%s*:",
				}

				local lowerValue = string.lower(value)
				for _, pattern in ipairs(suspiciousPatterns) do
					if string.find(lowerValue, pattern) then
						return false
					end
				end
			elseif type(value) == "table" then
				for _, subValue in pairs(value) do
					if not checkSqlInjection(subValue) then
						return false
					end
				end
			end
			return true
		end

		if not checkSqlInjection(data) then
			return ValidationUtils.Failure(
				"Suspicious patterns detected in request data",
				"SUSPICIOUS_REQUEST_PATTERNS",
				"NetworkRequest"
			)
		end
	end

	-- Проверяем на чрезмерно длинные строки
	if data and type(data) == "table" then
		local function checkStringLength(value, maxLength)
			maxLength = maxLength or 1000
			if type(value) == "string" and #value > maxLength then
				return false
			elseif type(value) == "table" then
				for _, subValue in pairs(value) do
					if not checkStringLength(subValue, maxLength) then
						return false
					end
				end
			end
			return true
		end

		if not checkStringLength(data) then
			return ValidationUtils.Failure(
				"Request contains excessively long strings",
				"EXCESSIVE_STRING_LENGTH",
				"NetworkRequest"
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ RATE LIMITING ]]---

-- Валидация типа rate limit
function NetworkValidator:ValidateRateLimitType(limitType: any): ValidationUtils.ValidationResult
	local validTypes = { "CHAT", "MOVEMENT", "COMBAT", "INVENTORY", "TRADING", "DEBUG" }
	return ValidationUtils.ValidateEnum(limitType, validTypes, "RateLimitType")
end

-- Валидация параметров rate limiting
function NetworkValidator:ValidateRateLimitConfig(config: any): ValidationUtils.ValidationResult
	if type(config) ~= "table" then
		return ValidationUtils.Failure(
			"Rate limit config must be a table",
			"INVALID_RATE_LIMIT_CONFIG_TYPE",
			"RateLimitConfig"
		)
	end

	-- Проверяем обязательные поля
	if not config.MaxRequests or type(config.MaxRequests) ~= "number" then
		return ValidationUtils.Failure("MaxRequests must be a number", "INVALID_MAX_REQUESTS", "RateLimitConfig")
	end

	if config.MaxRequests <= 0 or config.MaxRequests > 1000 then
		return ValidationUtils.Failure(
			string.format("MaxRequests must be between 1 and 1000, got %d", config.MaxRequests),
			"MAX_REQUESTS_OUT_OF_RANGE",
			"RateLimitConfig"
		)
	end

	if not config.TimeWindow or type(config.TimeWindow) ~= "number" then
		return ValidationUtils.Failure("TimeWindow must be a number", "INVALID_TIME_WINDOW", "RateLimitConfig")
	end

	if config.TimeWindow <= 0 or config.TimeWindow > 3600 then
		return ValidationUtils.Failure(
			string.format("TimeWindow must be between 1 and 3600 seconds, got %d", config.TimeWindow),
			"TIME_WINDOW_OUT_OF_RANGE",
			"RateLimitConfig"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ АДМИНСКИХ ДЕЙСТВИЙ ]]---

-- Валидация для админских действий
function NetworkValidator:ValidateAdminAction(
	adminPlayer: Player,
	action: string,
	targetPlayer: Player?,
	data: any?
): ValidationUtils.ValidationResult
	-- Проверяем права администратора (placeholder для будущей реализации)
	local adminResult = self:ValidateAdminPermissions(adminPlayer, action)
	if not adminResult.IsValid then
		return adminResult
	end

	-- Проверяем валидность действия
	local validAdminActions = {
		"GRANT_EXP",
		"GRANT_GOLD",
		"SET_LEVEL",
		"HEAL_PLAYER",
		"TELEPORT_PLAYER",
		"BAN_PLAYER",
		"KICK_PLAYER",
		"MUTE_PLAYER",
		"WARN_PLAYER",
		"RESET_DATA",
	}

	local actionResult = ValidationUtils.ValidateEnum(action, validAdminActions, "AdminAction")
	if not actionResult.IsValid then
		return actionResult
	end

	-- Проверяем целевого игрока для действий, которые его требуют
	local actionsRequiringTarget = {
		"GRANT_EXP",
		"GRANT_GOLD",
		"SET_LEVEL",
		"HEAL_PLAYER",
		"TELEPORT_PLAYER",
		"BAN_PLAYER",
		"KICK_PLAYER",
		"MUTE_PLAYER",
		"WARN_PLAYER",
		"RESET_DATA",
	}

	if table.find(actionsRequiringTarget, action) and not targetPlayer then
		return ValidationUtils.Failure(
			string.format("Action %s requires a target player", action),
			"MISSING_TARGET_PLAYER",
			"AdminAction"
		)
	end

	-- Проверяем данные для действий, которые их требуют
	local actionsRequiringData = { "GRANT_EXP", "GRANT_GOLD", "SET_LEVEL", "TELEPORT_PLAYER", "WARN_PLAYER" }
	if table.find(actionsRequiringData, action) then
		if not data then
			return ValidationUtils.Failure(
				string.format("Action %s requires data", action),
				"MISSING_ACTION_DATA",
				"AdminAction"
			)
		end

		-- Специфичная валидация по типу действия
		local dataResult = self:ValidateAdminActionData(action, data)
		if not dataResult.IsValid then
			return dataResult
		end
	end

	-- Проверяем, что админ не воздействует сам на себя в некоторых действиях
	local selfTargetForbidden = { "BAN_PLAYER", "KICK_PLAYER", "RESET_DATA" }
	if table.find(selfTargetForbidden, action) and targetPlayer == adminPlayer then
		return ValidationUtils.Failure(
			string.format("Cannot perform %s on yourself", action),
			"CANNOT_TARGET_SELF",
			"AdminAction"
		)
	end

	-- Логируем админское действие
	print(string.format("[NETWORK VALIDATOR] Admin action validated: %s by %s", action, adminPlayer.Name))

	return ValidationUtils.Success()
end

-- Валидация прав администратора
function NetworkValidator:ValidateAdminPermissions(
	adminPlayer: Player,
	action: string
): ValidationUtils.ValidationResult
	-- Placeholder для системы прав администратора
	-- В реальной игре здесь была бы проверка уровня прав администратора

	-- Для примера, проверяем по группе в Roblox (если нужно)
	if adminPlayer:GetRankInGroup(0) < 100 then -- Пример: группа и ранг
		-- В разработке разрешаем всё для тестирования
		if game:GetService("RunService"):IsStudio() then
			return ValidationUtils.Success()
		end

		return ValidationUtils.Failure(
			string.format("Insufficient permissions for action %s", action),
			"INSUFFICIENT_ADMIN_PERMISSIONS",
			"AdminPermissions"
		)
	end

	return ValidationUtils.Success()
end

-- Валидация данных админского действия
function NetworkValidator:ValidateAdminActionData(action: string, data: any): ValidationUtils.ValidationResult
	if action == "GRANT_EXP" or action == "GRANT_GOLD" then
		local amountResult = ValidationUtils.ValidateType(data, "number", "Amount")
		if not amountResult.IsValid then
			return amountResult
		end

		if data <= 0 or data > 1000000 then
			return ValidationUtils.Failure("Amount must be between 1 and 1,000,000", "INVALID_AMOUNT_RANGE", "Amount")
		end
	elseif action == "SET_LEVEL" then
		local levelResult = ValidationUtils.ValidatePlayerLevel(data)
		if not levelResult.IsValid then
			return levelResult
		end
	elseif action == "TELEPORT_PLAYER" then
		if type(data) ~= "table" then
			return ValidationUtils.Failure(
				"Teleport data must be a table",
				"INVALID_TELEPORT_DATA_TYPE",
				"TeleportData"
			)
		end

		-- Проверяем координаты
		if not data.Position or type(data.Position) ~= "userdata" then
			return ValidationUtils.Failure(
				"Teleport position must be a Vector3",
				"INVALID_TELEPORT_POSITION",
				"TeleportData"
			)
		end

		-- Проверяем разумность координат
		local pos = data.Position
		if math.abs(pos.X) > 10000 or math.abs(pos.Y) > 1000 or math.abs(pos.Z) > 10000 then
			return ValidationUtils.Failure(
				"Teleport coordinates are outside reasonable bounds",
				"TELEPORT_OUT_OF_BOUNDS",
				"TeleportData"
			)
		end
	elseif action == "WARN_PLAYER" then
		if type(data) ~= "table" or not data.Reason then
			return ValidationUtils.Failure("Warning must include a reason", "MISSING_WARNING_REASON", "WarningData")
		end

		local reasonResult = ValidationUtils.ValidateStringLength(data.Reason, 1, 500, "WarningReason")
		if not reasonResult.IsValid then
			return reasonResult
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ СИСТЕМНЫХ СООБЩЕНИЙ ]]---

-- Валидация системного сообщения
function NetworkValidator:ValidateSystemMessage(messageData: any): ValidationUtils.ValidationResult
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

	-- Проверяем временную метку
	if messageData.Timestamp then
		if type(messageData.Timestamp) ~= "number" then
			return ValidationUtils.Failure("Timestamp must be a number", "INVALID_TIMESTAMP_TYPE", "Timestamp")
		end

		local currentTime = os.time()
		if messageData.Timestamp > currentTime + 60 then -- Не может быть из будущего больше чем на минуту
			return ValidationUtils.Failure("Timestamp is too far in the future", "TIMESTAMP_TOO_FUTURE", "Timestamp")
		end

		if messageData.Timestamp < currentTime - 86400 then -- Не может быть старше суток
			return ValidationUtils.Failure("Timestamp is too old", "TIMESTAMP_TOO_OLD", "Timestamp")
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ЧАТА ]]---

-- Валидация сообщения чата
function NetworkValidator:ValidateChatMessage(player: Player, message: string): ValidationUtils.ValidationResult
	-- Проверяем базовую валидность сообщения
	local messageResult = ValidationUtils.ValidateChatMessage(message)
	if not messageResult.IsValid then
		return messageResult
	end

	-- Дополнительные проверки для сетевого контекста

	-- Проверяем на спам (повторяющиеся сообщения)
	local spamResult = self:CheckChatSpam(player, message)
	if not spamResult.IsValid then
		return spamResult
	end

	-- Проверяем на флуд (слишком частые сообщения)
	local floodResult = self:CheckChatFlood(player)
	if not floodResult.IsValid then
		return floodResult
	end

	-- Проверяем на неподобающий контент
	local contentResult = self:CheckChatContent(message)
	if not contentResult.IsValid then
		return contentResult
	end

	return ValidationUtils.Success()
end

-- Проверка на спам в чате
function NetworkValidator:CheckChatSpam(player: Player, message: string): ValidationUtils.ValidationResult
	-- Простая проверка на повторяющиеся символы
	local repeatedCharPattern = "(..)%1%1%1%1+" -- 5+ повторяющихся символов
	if string.find(message, repeatedCharPattern) then
		return ValidationUtils.Failure(
			"Message contains excessive repeated characters",
			"CHAT_SPAM_REPEATED_CHARS",
			"ChatMessage"
		)
	end

	-- Проверка на капс
	local upperCount = 0
	local letterCount = 0
	for i = 1, #message do
		local char = string.sub(message, i, i)
		if string.match(char, "%a") then
			letterCount = letterCount + 1
			if string.match(char, "%u") then
				upperCount = upperCount + 1
			end
		end
	end

	if letterCount > 10 and upperCount / letterCount > 0.8 then
		return ValidationUtils.Failure(
			"Message contains excessive capital letters",
			"CHAT_EXCESSIVE_CAPS",
			"ChatMessage"
		)
	end

	return ValidationUtils.Success()
end

-- Проверка на флуд в чате
function NetworkValidator:CheckChatFlood(player: Player): ValidationUtils.ValidationResult
	-- Эта проверка должна интегрироваться с системой rate limiting
	-- Пока что возвращаем успех, так как rate limiting обрабатывается отдельно
	return ValidationUtils.Success()
end

-- Проверка контента чата
function NetworkValidator:CheckChatContent(message: string): ValidationUtils.ValidationResult
	-- Проверяем на подозрительные URL
	local urlPattern = "https?://[%w%.%-_]+%.%w+"
	if string.find(string.lower(message), urlPattern) then
		return ValidationUtils.Failure("URLs are not allowed in chat", "CHAT_URL_NOT_ALLOWED", "ChatMessage")
	end

	-- Проверяем на попытки обхода фильтров
	local filterBypassPatterns = {
		"[%a%d]%s*[%a%d]%s*[%a%d]%s*[%a%d]", -- Р а з р я ж е н н ы е буквы
		"[%a%d][^%a%d%s][%a%d][^%a%d%s][%a%d]", -- Б@н и тд
	}

	for _, pattern in ipairs(filterBypassPatterns) do
		if string.find(message, pattern) then
			return ValidationUtils.Failure(
				"Suspicious character patterns detected",
				"CHAT_FILTER_BYPASS_ATTEMPT",
				"ChatMessage"
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ БЕЗОПАСНОСТИ ]]---

-- Валидация попыток эксплойтов
function NetworkValidator:ValidateExploitAttempt(player: Player, suspiciousData: any): ValidationUtils.ValidationResult
	-- Проверяем на подозрительные данные игрока
	if suspiciousData.Speed and suspiciousData.Speed > 100 then
		return ValidationUtils.Failure(
			string.format("Suspicious movement speed: %d", suspiciousData.Speed),
			"SUSPICIOUS_MOVEMENT_SPEED",
			"ExploitDetection"
		)
	end

	if suspiciousData.Position then
		local pos = suspiciousData.Position
		if math.abs(pos.Y) > 5000 then -- Подозрительная высота
			return ValidationUtils.Failure(
				string.format("Suspicious position height: %d", pos.Y),
				"SUSPICIOUS_POSITION_HEIGHT",
				"ExploitDetection"
			)
		end
	end

	if suspiciousData.Damage and suspiciousData.Damage > 10000 then
		return ValidationUtils.Failure(
			string.format("Suspicious damage amount: %d", suspiciousData.Damage),
			"SUSPICIOUS_DAMAGE_AMOUNT",
			"ExploitDetection"
		)
	end

	return ValidationUtils.Success()
end

-- Валидация целостности данных клиента
function NetworkValidator:ValidateClientIntegrity(player: Player, clientData: any): ValidationUtils.ValidationResult
	-- Проверяем временные метки
	if clientData.Timestamp then
		local serverTime = tick()
		local timeDifference = math.abs(serverTime - clientData.Timestamp)

		if timeDifference > 5 then -- Больше 5 секунд разницы подозрительно
			return ValidationUtils.Failure(
				string.format("Client timestamp too far from server time: %.2f seconds", timeDifference),
				"CLIENT_TIME_DESYNC",
				"ClientIntegrity"
			)
		end
	end

	-- Проверяем последовательность действий
	if clientData.ActionSequence then
		-- Простая проверка на разумность последовательности
		if type(clientData.ActionSequence) ~= "number" then
			return ValidationUtils.Failure(
				"Action sequence must be a number",
				"INVALID_ACTION_SEQUENCE",
				"ClientIntegrity"
			)
		end

		if clientData.ActionSequence < 0 or clientData.ActionSequence > 1000000 then
			return ValidationUtils.Failure(
				"Action sequence out of reasonable range",
				"ACTION_SEQUENCE_OUT_OF_RANGE",
				"ClientIntegrity"
			)
		end
	end

	return ValidationUtils.Success()
end

return NetworkValidator
