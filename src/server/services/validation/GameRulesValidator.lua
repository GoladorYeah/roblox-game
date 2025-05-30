-- src/server/services/validation/GameRulesValidator.lua
-- Валидация специфичных игровых правил и логики

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local GameRulesValidator = {}
GameRulesValidator.__index = GameRulesValidator

function GameRulesValidator.new(validationService)
	local self = setmetatable({}, GameRulesValidator)
	self.ValidationService = validationService
	return self
end

function GameRulesValidator:Initialize()
	-- Инициализация игровых правил
	print("[GAME RULES VALIDATOR] Game rules validation initialized")
end

---[[ ОСНОВНЫЕ ИГРОВЫЕ ПРАВИЛА ]]---

-- Валидация специфичных для игры правил
function GameRulesValidator:ValidateGameSpecificRules(data: any, playerId: number?): ValidationUtils.ValidationResult
	-- Проверяем, что опыт не превышает требуемый для следующего уровня
	if data.Level and data.Experience then
		local requiredXP =
			math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (data.Level ^ Constants.EXPERIENCE.XP_MULTIPLIER))

		if data.Experience >= requiredXP then
			return ValidationUtils.Failure(
				string.format(
					"Experience %d exceeds required for next level %d (max: %d)",
					data.Experience,
					data.Level + 1,
					requiredXP - 1
				),
				"EXPERIENCE_EXCEEDS_LEVEL_LIMIT",
				"GameRules"
			)
		end

		if data.Experience < 0 then
			return ValidationUtils.Failure("Experience cannot be negative", "NEGATIVE_EXPERIENCE", "GameRules")
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
		local statResult = self:ValidateStatisticsReasonableness(data.Statistics)
		if not statResult.IsValid then
			return statResult
		end
	end

	-- Проверяем соответствие очков атрибутов уровню
	if data.Level and data.AttributePoints then
		local attrResult = self:ValidateAttributePointsForLevel(data.Level, data.AttributePoints)
		if not attrResult.IsValid then
			return attrResult
		end
	end

	-- Проверяем валидность экипировки
	if data.Equipment then
		local equipResult = self:ValidateEquipmentRules(data.Equipment, data.Level)
		if not equipResult.IsValid then
			return equipResult
		end
	end

	-- Логируем успешную валидацию игровых правил если указан playerId
	if playerId then
		print(string.format("[GAME RULES VALIDATOR] Game rules validated for player %d", playerId))
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ АТРИБУТОВ И УРОВНЕЙ ]]---

-- Валидация очков атрибутов для уровня
function GameRulesValidator:ValidateAttributePointsForLevel(
	level: number,
	attributePoints: number
): ValidationUtils.ValidationResult
	local maxAttributePoints = math.max(0, (level - 1) * 5) -- 5 очков за каждый уровень после первого

	if attributePoints > maxAttributePoints then
		return ValidationUtils.Failure(
			string.format(
				"Attribute points %d exceed maximum for level %d (max: %d)",
				attributePoints,
				level,
				maxAttributePoints
			),
			"EXCESSIVE_ATTRIBUTE_POINTS",
			"GameRules"
		)
	end

	if attributePoints < 0 then
		return ValidationUtils.Failure("Attribute points cannot be negative", "NEGATIVE_ATTRIBUTE_POINTS", "GameRules")
	end

	return ValidationUtils.Success()
end

-- Валидация распределения атрибутов
function GameRulesValidator:ValidateAttributeDistribution(
	attributes: any,
	totalPointsSpent: number,
	playerLevel: number
): ValidationUtils.ValidationResult
	-- Базовые атрибуты
	local baseTotal = 0
	for _, baseValue in pairs(Constants.PLAYER.BASE_ATTRIBUTES) do
		baseTotal = baseTotal + baseValue
	end

	-- Текущие атрибуты
	local currentTotal = 0
	for _, currentValue in pairs(attributes) do
		currentTotal = currentTotal + currentValue
	end

	-- Очки потрачены
	local pointsSpent = currentTotal - baseTotal

	-- Проверяем соответствие
	if pointsSpent ~= totalPointsSpent then
		return ValidationUtils.Failure(
			string.format("Attribute points mismatch: spent %d, calculated %d", totalPointsSpent, pointsSpent),
			"ATTRIBUTE_POINTS_MISMATCH",
			"AttributeDistribution"
		)
	end

	-- Проверяем максимальные значения атрибутов
	local maxAttributeValue = 1000 -- Абсолютный максимум
	for attrName, attrValue in pairs(attributes) do
		if attrValue > maxAttributeValue then
			return ValidationUtils.Failure(
				string.format("Attribute %s value %d exceeds maximum %d", attrName, attrValue, maxAttributeValue),
				"ATTRIBUTE_VALUE_TOO_HIGH",
				attrName
			)
		end

		-- Проверяем разумное соотношение с уровнем
		local reasonableMax = Constants.PLAYER.BASE_ATTRIBUTES[attrName] + (playerLevel * 10)
		if attrValue > reasonableMax then
			return ValidationUtils.Failure(
				string.format(
					"Attribute %s value %d unreasonable for level %d (max reasonable: %d)",
					attrName,
					attrValue,
					playerLevel,
					reasonableMax
				),
				"ATTRIBUTE_VALUE_UNREASONABLE",
				attrName
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ СТАТИСТИКИ ]]---

-- Валидация разумности статистики
function GameRulesValidator:ValidateStatisticsReasonableness(statistics: any): ValidationUtils.ValidationResult
	-- Время игры не может быть отрицательным
	if statistics.TotalPlayTime and statistics.TotalPlayTime < 0 then
		return ValidationUtils.Failure("Play time cannot be negative", "NEGATIVE_PLAY_TIME", "GameRules")
	end

	-- Убитые мобы не могут быть отрицательными
	if statistics.MobsKilled and statistics.MobsKilled < 0 then
		return ValidationUtils.Failure("Mobs killed cannot be negative", "NEGATIVE_MOBS_KILLED", "GameRules")
	end

	-- Проверяем разумные соотношения
	if statistics.TotalPlayTime and statistics.MobsKilled then
		-- Максимум 2 моба в секунду (очень активная игра)
		local maxMobsPerSecond = 2
		local maxPossibleMobs = statistics.TotalPlayTime * maxMobsPerSecond

		if statistics.MobsKilled > maxPossibleMobs then
			return ValidationUtils.Failure(
				string.format(
					"Too many mobs killed for play time: %d mobs in %.2f hours (max reasonable: %.0f)",
					statistics.MobsKilled,
					statistics.TotalPlayTime / 3600,
					maxPossibleMobs
				),
				"UNREALISTIC_MOB_KILL_RATE",
				"GameRules"
			)
		end
	end

	-- Проверяем соотношение смертей и времени игры
	if statistics.Deaths and statistics.TotalPlayTime then
		-- Максимум 1 смерть в 30 секунд (очень сложная игра)
		local maxDeathsPerSecond = 1.0 / 30.0
		local maxPossibleDeaths = statistics.TotalPlayTime * maxDeathsPerSecond

		if statistics.Deaths > maxPossibleDeaths then
			return ValidationUtils.Failure(
				string.format(
					"Too many deaths for play time: %d deaths in %.2f hours",
					statistics.Deaths,
					statistics.TotalPlayTime / 3600
				),
				"UNREALISTIC_DEATH_RATE",
				"GameRules"
			)
		end
	end

	-- Проверяем соотношение урона и убитых мобов
	if statistics.DamageDealt and statistics.MobsKilled then
		-- Минимум 10 урона на моба (очень слабые мобы)
		local minDamagePerMob = 10
		local minExpectedDamage = statistics.MobsKilled * minDamagePerMob

		if statistics.DamageDealt < minExpectedDamage then
			return ValidationUtils.Failure(
				string.format(
					"Too little damage for mobs killed: %d damage for %d mobs (min expected: %d)",
					statistics.DamageDealt,
					statistics.MobsKilled,
					minExpectedDamage
				),
				"UNREALISTIC_DAMAGE_TO_MOBS_RATIO",
				"GameRules"
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ЭКИПИРОВКИ ]]---

-- Валидация правил экипировки
function GameRulesValidator:ValidateEquipmentRules(
	equipment: any,
	playerLevel: number
): ValidationUtils.ValidationResult
	-- Проверяем, что в каждом слоте не более одного предмета
	local occupiedSlots = {}
	for slot, itemId in pairs(equipment) do
		if itemId ~= nil then
			if occupiedSlots[slot] then
				return ValidationUtils.Failure(
					string.format("Slot %s already occupied", slot),
					"DUPLICATE_EQUIPMENT_SLOT",
					"EquipmentRules"
				)
			end
			occupiedSlots[slot] = true
		end
	end

	-- Проверяем правила для колец (максимум 2)
	local ringCount = 0
	if equipment.Ring1 then
		ringCount = ringCount + 1
	end
	if equipment.Ring2 then
		ringCount = ringCount + 1
	end

	if ringCount > 2 then
		return ValidationUtils.Failure("Cannot equip more than 2 rings", "TOO_MANY_RINGS", "EquipmentRules")
	end

	-- Проверяем правило двуручного оружия
	if equipment.MainHand then
		local weaponResult = self:ValidateTwoHandedWeaponRules(equipment.MainHand, equipment.OffHand)
		if not weaponResult.IsValid then
			return weaponResult
		end
	end

	-- Используем playerLevel для проверки требований к уровню (если нужно)
	-- Это заглушка для будущих проверок уровня экипировки
	if playerLevel < 1 then
		return ValidationUtils.Failure("Player level too low for any equipment", "LEVEL_TOO_LOW", "EquipmentRules")
	end

	return ValidationUtils.Success()
end

-- Валидация правил двуручного оружия
function GameRulesValidator:ValidateTwoHandedWeaponRules(
	mainHandItem: string,
	offHandItem: string?
): ValidationUtils.ValidationResult
	-- Простая проверка: если в основной руке двуручное оружие, то в неосновной руке ничего быть не должно
	-- Предполагаем, что двуручное оружие содержит "TwoHanded" в названии
	if string.find(mainHandItem, "TwoHanded") and offHandItem ~= nil then
		return ValidationUtils.Failure(
			"Cannot equip off-hand item with two-handed weapon",
			"TWO_HANDED_WEAPON_CONFLICT",
			"EquipmentRules"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ИНВЕНТАРЯ ]]---

-- Валидация правил инвентаря
function GameRulesValidator:ValidateInventoryRules(inventory: any, maxSlots: number): ValidationUtils.ValidationResult
	if type(inventory) ~= "table" then
		return ValidationUtils.Failure("Inventory must be a table", "INVALID_INVENTORY_TYPE", "InventoryRules")
	end

	-- Проверяем количество слотов
	local usedSlots = 0
	for _ in pairs(inventory) do
		usedSlots = usedSlots + 1
	end

	if usedSlots > maxSlots then
		return ValidationUtils.Failure(
			string.format("Too many items in inventory: %d (max: %d)", usedSlots, maxSlots),
			"INVENTORY_OVERFLOW",
			"InventoryRules"
		)
	end

	-- Проверяем каждый предмет в инвентаре
	for slotIndex, item in pairs(inventory) do
		local itemResult = self:ValidateInventoryItem(item, slotIndex)
		if not itemResult.IsValid then
			return itemResult
		end
	end

	return ValidationUtils.Success()
end

-- Валидация предмета в инвентаре
function GameRulesValidator:ValidateInventoryItem(item: any, slotIndex: any): ValidationUtils.ValidationResult
	if type(item) ~= "table" then
		return ValidationUtils.Failure(
			string.format("Item in slot %s must be a table", tostring(slotIndex)),
			"INVALID_ITEM_TYPE",
			"InventoryItem"
		)
	end

	-- Проверяем обязательные поля
	if not item.Id or type(item.Id) ~= "string" then
		return ValidationUtils.Failure(
			string.format("Item in slot %s missing valid Id", tostring(slotIndex)),
			"MISSING_ITEM_ID",
			"InventoryItem"
		)
	end

	if not item.Quantity or type(item.Quantity) ~= "number" or item.Quantity <= 0 then
		return ValidationUtils.Failure(
			string.format("Item in slot %s has invalid quantity", tostring(slotIndex)),
			"INVALID_ITEM_QUANTITY",
			"InventoryItem"
		)
	end

	-- Проверяем максимальный размер стека
	local maxStackSize = Constants.INVENTORY.MAX_STACK_SIZE
	if item.Quantity > maxStackSize then
		return ValidationUtils.Failure(
			string.format("Item stack size %d exceeds maximum %d", item.Quantity, maxStackSize),
			"ITEM_STACK_TOO_LARGE",
			"InventoryItem"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ЭКОНОМИКИ ]]---

-- Валидация экономических правил
function GameRulesValidator:ValidateEconomicRules(playerData: any): ValidationUtils.ValidationResult
	if not playerData.Currency then
		return ValidationUtils.Success() -- Валюта необязательна
	end

	-- Проверяем разумность количества золота для уровня
	if playerData.Currency.Gold and playerData.Level then
		local reasonableGoldForLevel = playerData.Level * 1000 -- 1000 золота за уровень
		local maxReasonableGold = reasonableGoldForLevel * 10 -- До 10x от разумного

		if playerData.Currency.Gold > maxReasonableGold then
			return ValidationUtils.Failure(
				string.format(
					"Gold amount %d unreasonable for level %d (max reasonable: %d)",
					playerData.Currency.Gold,
					playerData.Level,
					maxReasonableGold
				),
				"UNREASONABLE_GOLD_FOR_LEVEL",
				"EconomicRules"
			)
		end
	end

	return ValidationUtils.Success()
end

-- Валидация торговых операций
function GameRulesValidator:ValidateTradeRules(trade: any): ValidationUtils.ValidationResult
	if type(trade) ~= "table" then
		return ValidationUtils.Failure("Trade data must be a table", "INVALID_TRADE_TYPE", "TradeRules")
	end

	-- Проверяем участников торговли
	if not trade.Player1 or not trade.Player2 then
		return ValidationUtils.Failure("Trade must have two participants", "MISSING_TRADE_PARTICIPANTS", "TradeRules")
	end

	if trade.Player1 == trade.Player2 then
		return ValidationUtils.Failure("Cannot trade with yourself", "SELF_TRADE_FORBIDDEN", "TradeRules")
	end

	-- Проверяем предметы торговли
	if trade.Player1Items then
		for _, item in ipairs(trade.Player1Items) do
			local itemResult = self:ValidateTradeItem(item)
			if not itemResult.IsValid then
				return itemResult
			end
		end
	end

	if trade.Player2Items then
		for _, item in ipairs(trade.Player2Items) do
			local itemResult = self:ValidateTradeItem(item)
			if not itemResult.IsValid then
				return itemResult
			end
		end
	end

	-- Проверяем справедливость торговли (примерная оценка)
	local fairnessResult = self:ValidateTradeFairness(trade)
	if not fairnessResult.IsValid then
		return fairnessResult
	end

	return ValidationUtils.Success()
end

-- Валидация предмета в торговле
function GameRulesValidator:ValidateTradeItem(item: any): ValidationUtils.ValidationResult
	if type(item) ~= "table" then
		return ValidationUtils.Failure("Trade item must be a table", "INVALID_TRADE_ITEM_TYPE", "TradeItem")
	end

	if not item.Id or type(item.Id) ~= "string" then
		return ValidationUtils.Failure("Trade item missing valid Id", "MISSING_TRADE_ITEM_ID", "TradeItem")
	end

	if not item.Quantity or type(item.Quantity) ~= "number" or item.Quantity <= 0 then
		return ValidationUtils.Failure("Trade item has invalid quantity", "INVALID_TRADE_ITEM_QUANTITY", "TradeItem")
	end

	-- Проверяем, что предмет можно торговать
	if item.Properties and item.Properties.NoTrade then
		return ValidationUtils.Failure("Item cannot be traded", "ITEM_NOT_TRADEABLE", "TradeItem")
	end

	return ValidationUtils.Success()
end

-- Валидация справедливости торговли
function GameRulesValidator:ValidateTradeFairness(trade: any): ValidationUtils.ValidationResult
	-- Простая проверка на подозрительно несправедливую торговлю
	-- В реальной игре здесь была бы более сложная оценка стоимости предметов

	local function estimateItemValue(items)
		if not items then
			return 0
		end

		local totalValue = 0
		for _, item in ipairs(items) do
			-- Примерная оценка: редкие предметы дороже
			local baseValue = 100
			if item.Rarity == "Uncommon" then
				baseValue = 200
			elseif item.Rarity == "Rare" then
				baseValue = 500
			elseif item.Rarity == "Epic" then
				baseValue = 1000
			elseif item.Rarity == "Legendary" then
				baseValue = 5000
			end

			totalValue = totalValue + (baseValue * (item.Quantity or 1))
		end

		return totalValue
	end

	local player1Value = estimateItemValue(trade.Player1Items)
	local player2Value = estimateItemValue(trade.Player2Items)

	-- Если одна сторона дает в 20 раз больше, это подозрительно
	if player1Value > 0 and player2Value > 0 then
		local ratio = math.max(player1Value / player2Value, player2Value / player1Value)
		if ratio > 20 then
			return ValidationUtils.Failure(
				string.format("Trade appears unfair: value ratio %.1f:1", ratio),
				"UNFAIR_TRADE_RATIO",
				"TradeFairness"
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ВРЕМЕННЫХ ОГРАНИЧЕНИЙ ]]---

-- Валидация временных ограничений
function GameRulesValidator:ValidateTimeConstraints(
	action: string,
	lastActionTime: number,
	cooldown: number
): ValidationUtils.ValidationResult
	local currentTime = tick()
	local timeSinceLastAction = currentTime - lastActionTime

	if timeSinceLastAction < cooldown then
		local remainingCooldown = cooldown - timeSinceLastAction
		return ValidationUtils.Failure(
			string.format("Action %s on cooldown for %.1f more seconds", action, remainingCooldown),
			"ACTION_ON_COOLDOWN",
			"TimeConstraints"
		)
	end

	return ValidationUtils.Success()
end

-- Валидация дневных лимитов
function GameRulesValidator:ValidateDailyLimits(
	action: string,
	todayCount: number,
	dailyLimit: number
): ValidationUtils.ValidationResult
	if todayCount >= dailyLimit then
		return ValidationUtils.Failure(
			string.format("Daily limit reached for %s: %d/%d", action, todayCount, dailyLimit),
			"DAILY_LIMIT_REACHED",
			"DailyLimits"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ СОСТОЯНИЯ ИГРОКА ]]---

-- Валидация состояния игрока для действия
function GameRulesValidator:ValidatePlayerStateForAction(
	playerState: any,
	action: string
): ValidationUtils.ValidationResult
	-- Проверяем, что игрок жив
	if playerState.Health <= 0 and action ~= "RESPAWN" then
		return ValidationUtils.Failure(
			string.format("Cannot perform %s while dead", action),
			"PLAYER_IS_DEAD",
			"PlayerState"
		)
	end

	-- Проверяем ману для магических действий
	local magicActions = { "CAST_SPELL", "USE_STAFF", "ENCHANT_ITEM" }
	if table.find(magicActions, action) then
		if not playerState.Mana or playerState.Mana <= 0 then
			return ValidationUtils.Failure(
				string.format("Not enough mana for %s", action),
				"INSUFFICIENT_MANA",
				"PlayerState"
			)
		end
	end

	-- Проверяем стамину для физических действий
	local staminaActions = { "SPRINT", "DODGE", "HEAVY_ATTACK", "BLOCK" }
	if table.find(staminaActions, action) then
		if not playerState.Stamina or playerState.Stamina <= 0 then
			return ValidationUtils.Failure(
				string.format("Not enough stamina for %s", action),
				"INSUFFICIENT_STAMINA",
				"PlayerState"
			)
		end
	end

	-- Проверяем состояние "в бою"
	local nonCombatActions = { "FAST_TRAVEL", "LOGOUT", "CHANGE_EQUIPMENT" }
	if table.find(nonCombatActions, action) and playerState.InCombat then
		return ValidationUtils.Failure(
			string.format("Cannot %s while in combat", action),
			"CANNOT_ACTION_IN_COMBAT",
			"PlayerState"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ГРУППОВЫХ ДЕЙСТВИЙ ]]---

-- Валидация групповых правил
function GameRulesValidator:ValidatePartyRules(party: any, action: string): ValidationUtils.ValidationResult
	if not party then
		return ValidationUtils.Success() -- Не в группе - всё ок
	end

	-- Проверяем размер группы
	local maxPartySize = 6
	if #party.Members > maxPartySize then
		return ValidationUtils.Failure(
			string.format("Party size %d exceeds maximum %d", #party.Members, maxPartySize),
			"PARTY_TOO_LARGE",
			"PartyRules"
		)
	end

	-- Проверяем права на действие
	local leaderOnlyActions = { "KICK_MEMBER", "INVITE_PLAYER", "CHANGE_LOOT_RULES" }
	if table.find(leaderOnlyActions, action) and party.Leader ~= party.CurrentPlayer then
		return ValidationUtils.Failure(
			string.format("Only party leader can perform %s", action),
			"LEADER_ONLY_ACTION",
			"PartyRules"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ГИЛЬДИЙ ]]---

-- Валидация правил гильдии
function GameRulesValidator:ValidateGuildRules(
	guild: any,
	playerRank: string,
	action: string
): ValidationUtils.ValidationResult
	if not guild then
		return ValidationUtils.Success() -- Не в гильдии - всё ок
	end

	-- Проверяем права на действие
	local rankPermissions = {
		MEMBER = { "CHAT", "VIEW_INFO" },
		OFFICER = { "CHAT", "VIEW_INFO", "INVITE_PLAYER", "KICK_MEMBER" },
		LEADER = { "CHAT", "VIEW_INFO", "INVITE_PLAYER", "KICK_MEMBER", "DISBAND_GUILD", "CHANGE_SETTINGS" },
	}

	local playerPermissions = rankPermissions[playerRank] or {}
	if not table.find(playerPermissions, action) then
		return ValidationUtils.Failure(
			string.format("Insufficient guild rank for %s (current: %s)", action, playerRank),
			"INSUFFICIENT_GUILD_RANK",
			"GuildRules"
		)
	end

	return ValidationUtils.Success()
end

return GameRulesValidator
