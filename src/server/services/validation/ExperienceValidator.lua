-- src/server/services/validation/ExperienceValidator.lua
-- Валидация системы опыта и уровней

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ValidationUtils = require(ReplicatedStorage.Shared.utils.ValidationUtils)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local ExperienceValidator = {}
ExperienceValidator.__index = ExperienceValidator

function ExperienceValidator.new(validationService)
	local self = setmetatable({}, ExperienceValidator)
	self.ValidationService = validationService
	return self
end

function ExperienceValidator:Initialize()
	-- Инициализация правил валидации опыта
	print("[EXPERIENCE VALIDATOR] Experience validation rules initialized")
end

---[[ ВАЛИДАЦИЯ ИЗМЕНЕНИЙ УРОВНЯ ]]---

-- Валидация изменений уровня
function ExperienceValidator:ValidateLevelChange(
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

	-- Логируем валидацию уровня если указан playerId
	if playerId then
		print(
			string.format(
				"[EXPERIENCE VALIDATOR] Level change validated for player %d: %d -> %d",
				playerId,
				currentLevel,
				newLevel
			)
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ИЗМЕНЕНИЙ ОПЫТА ]]---

-- Валидация изменений опыта
function ExperienceValidator:ValidateExperienceChange(
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

	-- Проверяем итоговое значение опыта
	local totalExp = currentExp + addedExp
	if totalExp > 1000000000 then -- 1 миллиард - абсолютный максимум
		return ValidationUtils.Failure(
			string.format("Total experience would exceed maximum: %d", totalExp),
			"EXPERIENCE_OVERFLOW",
			"ExperienceChange"
		)
	end

	-- Логируем валидацию опыта если указан playerId
	if playerId then
		print(
			string.format(
				"[EXPERIENCE VALIDATOR] Experience change validated for player %d: +%d (current: %d)",
				playerId,
				addedExp,
				currentExp
			)
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ОПЫТА ДЛЯ УРОВНЯ ]]---

-- Валидация правильности опыта для уровня
function ExperienceValidator:ValidateExperienceForLevel(
	level: number,
	currentExperience: number
): ValidationUtils.ValidationResult
	if level < 1 or level > Constants.PLAYER.MAX_LEVEL then
		return ValidationUtils.Failure(
			string.format("Invalid level: %d", level),
			"INVALID_LEVEL",
			"ExperienceValidation"
		)
	end

	if currentExperience < 0 then
		return ValidationUtils.Failure("Experience cannot be negative", "NEGATIVE_EXPERIENCE", "ExperienceValidation")
	end

	-- Рассчитываем максимально допустимый опыт для этого уровня
	local maxExperienceForLevel =
		math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (level ^ Constants.EXPERIENCE.XP_MULTIPLIER))

	if currentExperience >= maxExperienceForLevel then
		return ValidationUtils.Failure(
			string.format(
				"Experience %d too high for level %d (max: %d)",
				currentExperience,
				level,
				maxExperienceForLevel - 1
			),
			"EXPERIENCE_TOO_HIGH_FOR_LEVEL",
			"ExperienceValidation"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ИСТОЧНИКОВ ОПЫТА ]]---

-- Валидация получения опыта от различных источников
function ExperienceValidator:ValidateExperienceSource(
	source: string,
	amount: number,
	context: any?
): ValidationUtils.ValidationResult
	-- Проверяем валидность источника
	local validSources = {
		"KILL_MOB",
		"COMPLETE_QUEST",
		"CRAFT_ITEM",
		"DISCOVER_LOCATION",
		"SKILL_USE",
		"ADMIN_GRANT",
		"EVENT_BONUS",
		"DAILY_BONUS",
	}

	local sourceResult = ValidationUtils.ValidateEnum(source, validSources, "ExperienceSource")
	if not sourceResult.IsValid then
		return sourceResult
	end

	-- Проверяем разумность количества опыта для источника
	local sourceExpLimits = {
		KILL_MOB = { min = 1, max = 1000 },
		COMPLETE_QUEST = { min = 10, max = 5000 },
		CRAFT_ITEM = { min = 1, max = 100 },
		DISCOVER_LOCATION = { min = 50, max = 500 },
		SKILL_USE = { min = 1, max = 50 },
		ADMIN_GRANT = { min = 1, max = 100000 },
		EVENT_BONUS = { min = 10, max = 10000 },
		DAILY_BONUS = { min = 100, max = 1000 },
	}

	local limits = sourceExpLimits[source]
	if limits and (amount < limits.min or amount > limits.max) then
		return ValidationUtils.Failure(
			string.format(
				"Experience amount %d invalid for source %s (range: %d-%d)",
				amount,
				source,
				limits.min,
				limits.max
			),
			"INVALID_EXPERIENCE_FOR_SOURCE",
			"ExperienceSource"
		)
	end

	-- Дополнительная валидация по контексту
	if context then
		local contextResult = self:ValidateExperienceContext(source, amount, context)
		if not contextResult.IsValid then
			return contextResult
		end
	end

	return ValidationUtils.Success()
end

-- Валидация контекста получения опыта
function ExperienceValidator:ValidateExperienceContext(
	source: string,
	amount: number,
	context: any
): ValidationUtils.ValidationResult
	if source == "KILL_MOB" and context.mobLevel then
		-- Опыт за убийство моба должен соответствовать его уровню
		local expectedExp = math.max(1, context.mobLevel * 5)
		local tolerance = expectedExp * 0.5 -- 50% допуск

		if math.abs(amount - expectedExp) > tolerance then
			return ValidationUtils.Failure(
				string.format(
					"Experience %d doesn't match mob level %d (expected: ~%d)",
					amount,
					context.mobLevel,
					expectedExp
				),
				"EXPERIENCE_MOB_LEVEL_MISMATCH",
				"ExperienceContext"
			)
		end
	end

	if source == "COMPLETE_QUEST" and context.questDifficulty then
		-- Опыт за квест должен соответствовать сложности
		local difficultyMultipliers = { Easy = 1, Normal = 2, Hard = 4, Epic = 8 }
		local multiplier = difficultyMultipliers[context.questDifficulty]

		if not multiplier then
			return ValidationUtils.Failure(
				string.format("Invalid quest difficulty: %s", context.questDifficulty),
				"INVALID_QUEST_DIFFICULTY",
				"ExperienceContext"
			)
		end

		local baseExp = 50
		local expectedExp = baseExp * multiplier
		local tolerance = expectedExp * 0.3 -- 30% допуск

		if math.abs(amount - expectedExp) > tolerance then
			return ValidationUtils.Failure(
				string.format(
					"Experience %d doesn't match quest difficulty %s (expected: ~%d)",
					amount,
					context.questDifficulty,
					expectedExp
				),
				"EXPERIENCE_QUEST_DIFFICULTY_MISMATCH",
				"ExperienceContext"
			)
		end
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ МАСТЕРСТВА ОРУЖИЯ ]]---

-- Валидация опыта мастерства оружия
function ExperienceValidator:ValidateWeaponMasteryExperience(
	weaponType: string,
	currentExp: number,
	addedExp: number
): ValidationUtils.ValidationResult
	-- Проверяем тип оружия
	local validWeaponTypes = { "Sword", "Axe", "Bow", "Staff", "Spear" }
	local weaponResult = ValidationUtils.ValidateEnum(weaponType, validWeaponTypes, "WeaponType")
	if not weaponResult.IsValid then
		return weaponResult
	end

	-- Проверяем текущий опыт
	if currentExp < 0 then
		return ValidationUtils.Failure(
			"Weapon mastery experience cannot be negative",
			"NEGATIVE_MASTERY_EXPERIENCE",
			"WeaponMasteryExperience"
		)
	end

	-- Проверяем добавляемый опыт
	if addedExp <= 0 then
		return ValidationUtils.Failure(
			"Added weapon mastery experience must be positive",
			"INVALID_MASTERY_EXPERIENCE_AMOUNT",
			"WeaponMasteryExperience"
		)
	end

	-- Максимальный опыт мастерства за одно действие
	local maxMasteryExpPerAction = 100
	if addedExp > maxMasteryExpPerAction then
		return ValidationUtils.Failure(
			string.format("Weapon mastery experience gain too large: %d (max: %d)", addedExp, maxMasteryExpPerAction),
			"EXCESSIVE_MASTERY_EXPERIENCE_GAIN",
			"WeaponMasteryExperience"
		)
	end

	return ValidationUtils.Success()
end

-- Валидация уровня мастерства оружия
function ExperienceValidator:ValidateWeaponMasteryLevel(
	weaponType: string,
	level: number,
	experience: number
): ValidationUtils.ValidationResult
	-- Проверяем тип оружия
	local validWeaponTypes = { "Sword", "Axe", "Bow", "Staff", "Spear" }
	local weaponResult = ValidationUtils.ValidateEnum(weaponType, validWeaponTypes, "WeaponType")
	if not weaponResult.IsValid then
		return weaponResult
	end

	-- Проверяем уровень мастерства
	if level < 1 or level > 100 then
		return ValidationUtils.Failure(
			string.format("Weapon mastery level must be between 1 and 100, got %d", level),
			"INVALID_MASTERY_LEVEL",
			"WeaponMasteryLevel"
		)
	end

	-- Проверяем соответствие опыта уровню
	local expRequiredForLevel = level * 100 -- Простая формула: 100 опыта за уровень
	if experience >= expRequiredForLevel then
		return ValidationUtils.Failure(
			string.format(
				"Weapon mastery experience %d too high for level %d (max: %d)",
				experience,
				level,
				expRequiredForLevel - 1
			),
			"MASTERY_EXPERIENCE_TOO_HIGH_FOR_LEVEL",
			"WeaponMasteryLevel"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ БОНУСОВ ОПЫТА ]]---

-- Валидация бонусов к опыту
function ExperienceValidator:ValidateExperienceBonus(
	bonusType: string,
	multiplier: number
): ValidationUtils.ValidationResult
	-- Проверяем тип бонуса
	local validBonusTypes = {
		"GUILD_BONUS",
		"PREMIUM_BONUS",
		"EVENT_BONUS",
		"ITEM_BONUS",
		"SKILL_BONUS",
		"PARTY_BONUS",
		"LOCATION_BONUS",
	}

	local bonusResult = ValidationUtils.ValidateEnum(bonusType, validBonusTypes, "ExperienceBonusType")
	if not bonusResult.IsValid then
		return bonusResult
	end

	-- Проверяем множитель
	if multiplier <= 0 then
		return ValidationUtils.Failure(
			"Experience bonus multiplier must be positive",
			"INVALID_BONUS_MULTIPLIER",
			"ExperienceBonus"
		)
	end

	-- Ограничиваем максимальный бонус
	local maxMultiplier = 10.0 -- Максимум 1000% бонуса
	if multiplier > maxMultiplier then
		return ValidationUtils.Failure(
			string.format("Experience bonus multiplier too high: %.2f (max: %.2f)", multiplier, maxMultiplier),
			"EXCESSIVE_BONUS_MULTIPLIER",
			"ExperienceBonus"
		)
	end

	-- Проверяем разумность для разных типов бонусов
	local reasonableLimits = {
		GUILD_BONUS = 2.0, -- 100% макс
		PREMIUM_BONUS = 2.0, -- 100% макс
		EVENT_BONUS = 5.0, -- 400% макс
		ITEM_BONUS = 3.0, -- 200% макс
		SKILL_BONUS = 1.5, -- 50% макс
		PARTY_BONUS = 2.5, -- 150% макс
		LOCATION_BONUS = 2.0, -- 100% макс
	}

	local reasonableLimit = reasonableLimits[bonusType]
	if reasonableLimit and multiplier > reasonableLimit then
		return ValidationUtils.Failure(
			string.format(
				"Experience bonus multiplier %.2f unreasonable for type %s (max reasonable: %.2f)",
				multiplier,
				bonusType,
				reasonableLimit
			),
			"UNREASONABLE_BONUS_MULTIPLIER",
			"ExperienceBonus"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ПЕНАЛЬТИ ОПЫТА ]]---

-- Валидация штрафов к опыту
function ExperienceValidator:ValidateExperiencePenalty(
	penaltyType: string,
	multiplier: number
): ValidationUtils.ValidationResult
	-- Проверяем тип штрафа
	local validPenaltyTypes = { "DEATH_PENALTY", "FATIGUE_PENALTY", "DEBUFF_PENALTY", "LEVEL_DIFFERENCE_PENALTY" }

	local penaltyResult = ValidationUtils.ValidateEnum(penaltyType, validPenaltyTypes, "ExperiencePenaltyType")
	if not penaltyResult.IsValid then
		return penaltyResult
	end

	-- Проверяем множитель (для штрафов должен быть меньше 1.0)
	if multiplier < 0 or multiplier > 1.0 then
		return ValidationUtils.Failure(
			string.format("Experience penalty multiplier must be between 0 and 1, got %.2f", multiplier),
			"INVALID_PENALTY_MULTIPLIER",
			"ExperiencePenalty"
		)
	end

	-- Проверяем минимальный штраф (не может снижать опыт более чем на 90%)
	local minMultiplier = 0.1
	if multiplier < minMultiplier then
		return ValidationUtils.Failure(
			string.format("Experience penalty multiplier too low: %.2f (min: %.2f)", multiplier, minMultiplier),
			"EXCESSIVE_PENALTY_MULTIPLIER",
			"ExperiencePenalty"
		)
	end

	return ValidationUtils.Success()
end

---[[ ВАЛИДАЦИЯ ПРОГРЕССА ОПЫТА ]]---

-- Валидация прогресса опыта игрока
function ExperienceValidator:ValidateExperienceProgress(
	totalExperience: number,
	currentLevel: number
): ValidationUtils.ValidationResult
	-- Рассчитываем ожидаемый уровень из общего опыта
	local calculatedLevel = 1
	local remainingExp = totalExperience

	while calculatedLevel < Constants.PLAYER.MAX_LEVEL do
		local expRequired =
			math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (calculatedLevel ^ Constants.EXPERIENCE.XP_MULTIPLIER))
		if remainingExp < expRequired then
			break
		end
		remainingExp = remainingExp - expRequired
		calculatedLevel = calculatedLevel + 1
	end

	-- Проверяем соответствие
	if calculatedLevel ~= currentLevel then
		return ValidationUtils.Failure(
			string.format(
				"Level %d doesn't match total experience %d (should be level %d)",
				currentLevel,
				totalExperience,
				calculatedLevel
			),
			"LEVEL_EXPERIENCE_MISMATCH",
			"ExperienceProgress"
		)
	end

	return ValidationUtils.Success()
end

return ExperienceValidator
