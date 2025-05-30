-- src/server/services/validation/PlayerValidator.lua
-- Валидация данных игрока, атрибутов, золота и инвентаря

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)

local PlayerValidator = {}
PlayerValidator.__index = PlayerValidator

function PlayerValidator.new(validationService)
	local self = setmetatable({}, PlayerValidator)
	self.ValidationService = validationService
	return self
end

function PlayerValidator:Initialize()
	-- Инициализация специфичных правил для игрока
	print("[PLAYER VALIDATOR] Player validation rules initialized")
end

---[[ ВАЛИДАЦИЯ ПРОФИЛЯ ИГРОКА ]]---

-- Валидация полного профиля игрока
function PlayerValidator:ValidatePlayerProfile(profile: any): ValidationUtils.ValidationResult
	-- Проверяем целостность данных
	local integrityResult = self:ValidateDataIntegrity(profile)
	if not integrityResult.IsValid then
		return integrityResult
	end

	-- Проверяем основные поля профиля
	local profileResult = ValidationUtils.ValidatePlayerProfile(profile)
	if not profileResult.IsValid then
		return profileResult
	end

	-- Дополнительные проверки
	local additionalChecks = {
		self:ValidatePlayerLevel(profile.Level),
		self:ValidatePlayerExperience(profile.Experience),
		self:ValidatePlayerAttributes(profile.Attributes),
		self:ValidatePlayerGold(profile.Currency and profile.Currency.Gold),
		self:ValidatePlayerResources(profile),
	}

	-- Проверяем все дополнительные валидации
	for _, result in ipairs(additionalChecks) do
		if not result.IsValid then
			return result
		end
	end

	return ValidationUtils.Success()
end

-- Проверка целостности данных
function PlayerValidator:ValidateDataIntegrity(data: any): ValidationUtils.ValidationResult
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
	local typeChecks = {
		{ field = "Level", expectedType = "number", value = data.Level },
		{ field = "Experience", expectedType = "number", value = data.Experience },
		{ field = "Attributes", expectedType = "table", value = data.Attributes },
		{ field = "Currency", expectedType = "table", value = data.Currency },
		{ field = "Statistics", expectedType = "table", value = data.Statistics },
	}

	for _, check in ipairs(typeChecks) do
		if type(check.value) ~= check.expectedType then
			return ValidationUtils.Failure(
				string.format("%s must be a %s", check.field, check.expectedType),
				string.format("INVALID_%s_TYPE", string.upper(check.field)),
				check.field
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ОТДЕЛЬНЫХ КОМПОНЕНТОВ ]]---

-- Валидация уровня игрока
function PlayerValidator:ValidatePlayerLevel(level: any): ValidationUtils.ValidationResult
	return ValidationUtils.ValidatePlayerLevel(level)
end

-- Валидация опыта игрока
function PlayerValidator:ValidatePlayerExperience(experience: any): ValidationUtils.ValidationResult
	return ValidationUtils.ValidateExperience(experience)
end

-- Валидация атрибутов игрока
function PlayerValidator:ValidatePlayerAttributes(attributes: any): ValidationUtils.ValidationResult
	return ValidationUtils.ValidatePlayerAttributes(attributes)
end

-- Валидация золота игрока
function PlayerValidator:ValidatePlayerGold(gold: any): ValidationUtils.ValidationResult
	if gold == nil then
		return ValidationUtils.Failure("Gold cannot be nil", "NIL_GOLD", "Gold")
	end
	return ValidationUtils.ValidateGold(gold)
end

-- Валидация ресурсов игрока (здоровье, мана, стамина)
function PlayerValidator:ValidatePlayerResources(profile: any): ValidationUtils.ValidationResult
	if not profile.Health then
		return ValidationUtils.Failure("Health is required", "MISSING_HEALTH", "Health")
	end

	-- Проверяем здоровье
	local maxHealth = profile.MaxHealth or 100
	local healthResult = ValidationUtils.ValidateHealth(profile.Health, maxHealth)
	if not healthResult.IsValid then
		return healthResult
	end

	-- Проверяем ману (если есть)
	if profile.Mana then
		local maxMana = profile.MaxMana or 50
		local manaResult = ValidationUtils.ValidateMana(profile.Mana, maxMana)
		if not manaResult.IsValid then
			return manaResult
		end
	end

	-- Проверяем стамину (если есть)
	if profile.Stamina then
		local maxStamina = profile.MaxStamina or 100
		local staminaResult = ValidationUtils.ValidateStamina(profile.Stamina, maxStamina)
		if not staminaResult.IsValid then
			return staminaResult
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ТРАНЗАКЦИЙ ]]---

-- Валидация транзакций с золотом
function PlayerValidator:ValidateGoldTransaction(
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

	-- Логируем валидацию золота если указан playerId
	if playerId then
		print(
			string.format(
				"[PLAYER VALIDATOR] Gold transaction validated for player %d: %s %d (%d -> %d)",
				playerId,
				transactionType,
				change,
				currentGold,
				newGold
			)
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ИНВЕНТАРЯ ]]---

-- Валидация операций инвентаря
function PlayerValidator:ValidateInventoryOperation(
	operation: string,
	itemData: any,
	playerId: number?
): ValidationUtils.ValidationResult
	local validOperations = { "ADD_ITEM", "REMOVE_ITEM", "MOVE_ITEM", "SPLIT_STACK", "MERGE_STACK" }
	local result = ValidationUtils.ValidateEnum(operation, validOperations, "InventoryOperation")

	if not result.IsValid then
		return result
	end

	-- Дополнительная валидация в зависимости от операции
	if operation == "ADD_ITEM" or operation == "REMOVE_ITEM" then
		if not itemData then
			return ValidationUtils.Failure("Item data is required for " .. operation, "MISSING_ITEM_DATA", "ItemData")
		end

		-- Базовая валидация данных предмета
		local itemResult = self:ValidateItemData(itemData)
		if not itemResult.IsValid then
			return itemResult
		end
	end

	-- Логируем для будущей реализации если указан playerId
	if playerId and itemData then
		print(string.format("[PLAYER VALIDATOR] Inventory operation validated for player %d: %s", playerId, operation))
	end

	return ValidationUtils.Success()
end

-- Валидация данных предмета (базовая)
function PlayerValidator:ValidateItemData(itemData: any): ValidationUtils.ValidationResult
	if type(itemData) ~= "table" then
		return ValidationUtils.Failure("Item data must be a table", "INVALID_ITEM_DATA_TYPE", "ItemData")
	end

	-- Проверяем обязательные поля предмета
	local requiredFields = { "Id", "Type", "Quantity" }
	for _, field in ipairs(requiredFields) do
		if itemData[field] == nil then
			return ValidationUtils.Failure(
				string.format("Item missing required field: %s", field),
				"MISSING_ITEM_FIELD",
				field
			)
		end
	end

	-- Проверяем типы полей
	if type(itemData.Id) ~= "string" then
		return ValidationUtils.Failure("Item Id must be a string", "INVALID_ITEM_ID_TYPE", "Id")
	end

	if type(itemData.Type) ~= "string" then
		return ValidationUtils.Failure("Item Type must be a string", "INVALID_ITEM_TYPE_TYPE", "Type")
	end

	if type(itemData.Quantity) ~= "number" or itemData.Quantity <= 0 then
		return ValidationUtils.Failure("Item Quantity must be a positive number", "INVALID_ITEM_QUANTITY", "Quantity")
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ НАСТРОЕК ]]---

-- Валидация настроек игрока
function PlayerValidator:ValidatePlayerSettings(settings: any): ValidationUtils.ValidationResult
	if type(settings) ~= "table" then
		return ValidationUtils.Failure("Settings must be a table", "INVALID_SETTINGS_TYPE", "Settings")
	end

	-- Проверяем настройки звука
	if settings.MusicVolume then
		local volumeResult = ValidationUtils.ValidateVolume(settings.MusicVolume, "MusicVolume")
		if not volumeResult.IsValid then
			return volumeResult
		end
	end

	if settings.SFXVolume then
		local volumeResult = ValidationUtils.ValidateVolume(settings.SFXVolume, "SFXVolume")
		if not volumeResult.IsValid then
			return volumeResult
		end
	end

	-- Проверяем булевые настройки
	local booleanSettings = { "ShowDamageNumbers", "AutoPickupItems", "ChatFilter", "ShowPlayerNames" }
	for _, setting in ipairs(booleanSettings) do
		if settings[setting] ~= nil and type(settings[setting]) ~= "boolean" then
			return ValidationUtils.Failure(
				string.format("%s must be a boolean", setting),
				"INVALID_BOOLEAN_SETTING",
				setting
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ СТАТИСТИКИ ]]---

-- Валидация статистики игрока
function PlayerValidator:ValidatePlayerStatistics(statistics: any): ValidationUtils.ValidationResult
	if type(statistics) ~= "table" then
		return ValidationUtils.Failure("Statistics must be a table", "INVALID_STATISTICS_TYPE", "Statistics")
	end

	-- Проверяем числовые статистики
	local numericStats = {
		"TotalPlayTime",
		"MobsKilled",
		"QuestsCompleted",
		"ItemsCrafted",
		"Deaths",
		"DamageDealt",
		"DamageTaken",
		"DistanceTraveled",
	}

	for _, stat in ipairs(numericStats) do
		if statistics[stat] ~= nil then
			if type(statistics[stat]) ~= "number" then
				return ValidationUtils.Failure(
					string.format("%s must be a number", stat),
					"INVALID_STATISTIC_TYPE",
					stat
				)
			end

			if statistics[stat] < 0 then
				return ValidationUtils.Failure(string.format("%s cannot be negative", stat), "NEGATIVE_STATISTIC", stat)
			end
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ЭКИПИРОВКИ ]]---

-- Валидация экипировки игрока
function PlayerValidator:ValidatePlayerEquipment(equipment: any): ValidationUtils.ValidationResult
	if type(equipment) ~= "table" then
		return ValidationUtils.Failure("Equipment must be a table", "INVALID_EQUIPMENT_TYPE", "Equipment")
	end

	-- Проверяем слоты экипировки
	local validSlots = { "MainHand", "OffHand", "Helmet", "Chest", "Legs", "Boots", "Ring1", "Ring2", "Amulet" }

	for slot, itemId in pairs(equipment) do
		-- Проверяем, что слот валидный
		if not table.find(validSlots, slot) then
			return ValidationUtils.Failure(
				string.format("Invalid equipment slot: %s", slot),
				"INVALID_EQUIPMENT_SLOT",
				slot
			)
		end

		-- Если в слоте есть предмет, проверяем его ID
		if itemId ~= nil then
			if type(itemId) ~= "string" then
				return ValidationUtils.Failure(
					string.format("Equipment item ID in slot %s must be a string", slot),
					"INVALID_EQUIPMENT_ITEM_ID",
					slot
				)
			end

			if #itemId == 0 then
				return ValidationUtils.Failure(
					string.format("Equipment item ID in slot %s cannot be empty", slot),
					"EMPTY_EQUIPMENT_ITEM_ID",
					slot
				)
			end
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ МАСТЕРСТВА ОРУЖИЯ ]]---

-- Валидация мастерства оружия
function PlayerValidator:ValidateWeaponMastery(weaponMastery: any): ValidationUtils.ValidationResult
	if type(weaponMastery) ~= "table" then
		return ValidationUtils.Failure("WeaponMastery must be a table", "INVALID_WEAPON_MASTERY_TYPE", "WeaponMastery")
	end

	-- Проверяем типы оружия
	local validWeaponTypes = { "Sword", "Axe", "Bow", "Staff", "Spear" }

	for weaponType, masteryData in pairs(weaponMastery) do
		-- Проверяем, что тип оружия валидный
		if not table.find(validWeaponTypes, weaponType) then
			return ValidationUtils.Failure(
				string.format("Invalid weapon type: %s", weaponType),
				"INVALID_WEAPON_TYPE",
				weaponType
			)
		end

		-- Проверяем данные мастерства
		if type(masteryData) ~= "table" then
			return ValidationUtils.Failure(
				string.format("Weapon mastery data for %s must be a table", weaponType),
				"INVALID_MASTERY_DATA_TYPE",
				weaponType
			)
		end

		-- Проверяем уровень мастерства
		if not masteryData.Level or type(masteryData.Level) ~= "number" then
			return ValidationUtils.Failure(
				string.format("Weapon mastery level for %s must be a number", weaponType),
				"INVALID_MASTERY_LEVEL",
				weaponType
			)
		end

		if masteryData.Level < 1 or masteryData.Level > 100 then
			return ValidationUtils.Failure(
				string.format("Weapon mastery level for %s must be between 1 and 100", weaponType),
				"MASTERY_LEVEL_OUT_OF_RANGE",
				weaponType
			)
		end

		-- Проверяем опыт мастерства
		if not masteryData.Experience or type(masteryData.Experience) ~= "number" then
			return ValidationUtils.Failure(
				string.format("Weapon mastery experience for %s must be a number", weaponType),
				"INVALID_MASTERY_EXPERIENCE",
				weaponType
			)
		end

		if masteryData.Experience < 0 then
			return ValidationUtils.Failure(
				string.format("Weapon mastery experience for %s cannot be negative", weaponType),
				"NEGATIVE_MASTERY_EXPERIENCE",
				weaponType
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ РАЗМЕРА ДАННЫХ ]]---

-- Валидация данных для сохранения
function PlayerValidator:ValidateDataForSave(data: any): ValidationUtils.ValidationResult
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

	-- Проверяем глубину вложенности (защита от циклических ссылок)
	local maxDepth = 20
	local function checkDepth(obj, depth)
		if depth > maxDepth then
			return false
		end

		if type(obj) == "table" then
			for _, value in pairs(obj) do
				if not checkDepth(value, depth + 1) then
					return false
				end
			end
		end

		return true
	end

	if not checkDepth(data, 0) then
		return ValidationUtils.Failure(
			string.format("Data nesting exceeds maximum depth of %d levels", maxDepth),
			"DATA_TOO_DEEP",
			"SaveData"
		)
	end

	return ValidationUtils.Success()
end

---[[ КОМПЛЕКСНАЯ ВАЛИДАЦИЯ ]]---

-- Валидация полной согласованности данных игрока
function PlayerValidator:ValidatePlayerDataConsistency(profile: any): ValidationUtils.ValidationResult
	-- Проверяем соответствие уровня и опыта
	if profile.Level and profile.Experience and profile.AttributePoints then
		-- Ожидаемые очки атрибутов для уровня
		local expectedAttributePoints = math.max(0, (profile.Level - 1) * 5)

		-- Проверяем максимальное количество очков
		if profile.AttributePoints > expectedAttributePoints then
			return ValidationUtils.Failure(
				string.format(
					"Too many attribute points: %d (max for level %d: %d)",
					profile.AttributePoints,
					profile.Level,
					expectedAttributePoints
				),
				"EXCESSIVE_ATTRIBUTE_POINTS",
				"AttributePoints"
			)
		end
	end

	-- Проверяем соответствие ресурсов и атрибутов
	if profile.Attributes and profile.Health and profile.MaxHealth then
		local Constants = require(ReplicatedStorage.Shared.constants.Constants)

		local expectedMaxHealth = Constants.PLAYER.BASE_HEALTH
			+ (profile.Attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)

		-- Допускаем небольшое отклонение для временных эффектов
		local tolerance = 50
		if math.abs(profile.MaxHealth - expectedMaxHealth) > tolerance then
			return ValidationUtils.Failure(
				string.format(
					"MaxHealth mismatch: %d (expected: %d based on Constitution %d)",
					profile.MaxHealth,
					expectedMaxHealth,
					profile.Attributes.Constitution
				),
				"MAX_HEALTH_MISMATCH",
				"MaxHealth"
			)
		end
	end

	-- Проверяем логичность статистики
	if profile.Statistics then
		-- Время игры не может быть больше времени существования аккаунта
		local maxReasonablePlayTime = 365 * 24 * 60 * 60 -- 1 год в секундах
		if profile.Statistics.TotalPlayTime and profile.Statistics.TotalPlayTime > maxReasonablePlayTime then
			return ValidationUtils.Failure(
				string.format(
					"Play time too high: %.2f hours (max reasonable: %.2f hours)",
					profile.Statistics.TotalPlayTime / 3600,
					maxReasonablePlayTime / 3600
				),
				"EXCESSIVE_PLAY_TIME",
				"TotalPlayTime"
			)
		end

		-- Убитые мобы не могут быть намного больше времени игры
		if profile.Statistics.MobsKilled and profile.Statistics.TotalPlayTime then
			local mobsPerSecond = profile.Statistics.MobsKilled / math.max(1, profile.Statistics.TotalPlayTime)
			if mobsPerSecond > 2 then -- Максимум 2 моба в секунду
				return ValidationUtils.Failure(
					string.format("Unrealistic mob kill rate: %.2f mobs/second", mobsPerSecond),
					"UNREALISTIC_MOB_KILL_RATE",
					"MobsKilled"
				)
			end
		end
	end

	return ValidationUtils.Success()
end

return PlayerValidator
