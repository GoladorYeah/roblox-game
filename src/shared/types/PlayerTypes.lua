-- src/shared/types/PlayerTypes.lua
-- Типы данных для игрока и связанных систем

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local PlayerTypes = {}

-- Основные типы данных
export type UserId = number
export type Timestamp = number
export type Experience = number
export type Level = number
export type Gold = number

-- Характеристики игрока
export type PlayerAttributes = {
	Strength: number,
	Dexterity: number,
	Intelligence: number,
	Constitution: number,
	Focus: number,
}

-- Ресурсы игрока (здоровье, мана, стамина)
export type PlayerResources = {
	Health: number,
	MaxHealth: number,
	Mana: number,
	MaxMana: number,
	Stamina: number,
	MaxStamina: number,
}

-- Валюта игрока
export type PlayerCurrency = {
	Gold: Gold,
}

-- Статистика игрока
export type PlayerStatistics = {
	TotalPlayTime: number, -- в секундах
	MobsKilled: number,
	QuestsCompleted: number,
	ItemsCrafted: number,
	Deaths: number,
	DamageDealt: number,
	DamageTaken: number,
	DistanceTraveled: number,
}

-- Мастерство оружия
export type WeaponMasteryData = {
	Level: Level,
	Experience: Experience,
}

export type PlayerWeaponMastery = {
	Sword: WeaponMasteryData,
	Axe: WeaponMasteryData,
	Bow: WeaponMasteryData,
	Staff: WeaponMasteryData,
	Spear: WeaponMasteryData,
}

-- Настройки игрока
export type PlayerSettings = {
	MusicVolume: number, -- 0.0 - 1.0
	SFXVolume: number, -- 0.0 - 1.0
	ShowDamageNumbers: boolean,
	AutoPickupItems: boolean,
	ChatFilter: boolean,
	ShowPlayerNames: boolean,
}

-- Слот экипировки
export type EquipmentSlot = "MainHand" | "OffHand" | "Helmet" | "Chest" | "Legs" | "Boots" | "Ring1" | "Ring2" | "Amulet"

-- Экипировка игрока
export type PlayerEquipment = {
	MainHand: string?, -- ItemId
	OffHand: string?, -- ItemId
	Helmet: string?, -- ItemId
	Chest: string?, -- ItemId
	Legs: string?, -- ItemId
	Boots: string?, -- ItemId
	Ring1: string?, -- ItemId
	Ring2: string?, -- ItemId
	Amulet: string?, -- ItemId
}

-- Полный профиль игрока (соответствует DefaultProfile)
export type PlayerProfile = {
	-- Основная информация
	Level: Level,
	Experience: Experience,

	-- Характеристики
	Attributes: PlayerAttributes,
	AttributePoints: number,

	-- Ресурсы
	Health: number,
	Mana: number,
	Stamina: number,

	-- Инвентарь и экипировка
	Inventory: { any }, -- Будет детализировано в ItemTypes
	Equipment: PlayerEquipment,

	-- Валюта
	Currency: PlayerCurrency,

	-- Статистика
	Statistics: PlayerStatistics,

	-- Мастерство оружия
	WeaponMastery: PlayerWeaponMastery,

	-- Настройки
	Settings: PlayerSettings,

	-- Метаданные
	LastLogin: Timestamp,
}

-- Состояние игрока (для runtime данных)
export type PlayerState = {
	UserId: UserId,
	IsDataLoaded: boolean,
	IsOnline: boolean,
	CurrentHealth: number,
	CurrentMana: number,
	CurrentStamina: number,
	LastActivity: Timestamp,
	Position: Vector3?,
	InCombat: boolean,
	IsTrading: boolean,
	PartyId: string?,
	GuildId: string?,
}

-- События изменения данных
export type PlayerDataChangeEvent = {
	PlayerId: UserId,
	ChangeType: "LevelUp" | "ExperienceGain" | "AttributeChange" | "ResourceChange" | "ItemGain" | "ItemLoss",
	OldValue: any,
	NewValue: any,
	Timestamp: Timestamp,
}

-- Результат валидации данных
export type ValidationResult = {
	IsValid: boolean,
	ErrorMessage: string?,
	ErrorCode: string?,
}

-- Диапазоны валидации для характеристик
PlayerTypes.VALIDATION_RANGES = {
	Level = { Min = 1, Max = Constants.PLAYER.MAX_LEVEL },
	Experience = { Min = 0, Max = math.huge },
	Attributes = {
		Min = 1,
		Max = 1000,
		StartingTotal = 50, -- Общая сумма стартовых атрибутов
		MaxTotal = 5000, -- Максимальная сумма всех атрибутов
	},
	Health = { Min = 1, Max = 50000 },
	Mana = { Min = 0, Max = 10000 },
	Stamina = { Min = 0, Max = 5000 },
	Gold = { Min = 0, Max = 1000000000 }, -- 1 миллиард максимум
	Volume = { Min = 0.0, Max = 1.0 },
}

-- Функции валидации типов
function PlayerTypes.ValidateUserId(userId: any): boolean
	return type(userId) == "number" and userId > 0 and userId == math.floor(userId)
end

function PlayerTypes.ValidateLevel(level: any): boolean
	if type(level) ~= "number" then
		return false
	end
	local range = PlayerTypes.VALIDATION_RANGES.Level
	return level >= range.Min and level <= range.Max and level == math.floor(level)
end

function PlayerTypes.ValidateExperience(experience: any): boolean
	if type(experience) ~= "number" then
		return false
	end
	local range = PlayerTypes.VALIDATION_RANGES.Experience
	return experience >= range.Min and experience <= range.Max and experience == math.floor(experience)
end

function PlayerTypes.ValidateAttributes(attributes: any): ValidationResult
	if type(attributes) ~= "table" then
		return { IsValid = false, ErrorMessage = "Attributes must be a table", ErrorCode = "INVALID_TYPE" }
	end

	local requiredAttributes = { "Strength", "Dexterity", "Intelligence", "Constitution", "Focus" }
	local range = PlayerTypes.VALIDATION_RANGES.Attributes
	local total = 0

	-- Проверяем наличие всех обязательных атрибутов
	for _, attr in ipairs(requiredAttributes) do
		local value = attributes[attr]
		if type(value) ~= "number" then
			return {
				IsValid = false,
				ErrorMessage = attr .. " must be a number",
				ErrorCode = "INVALID_ATTRIBUTE_TYPE",
			}
		end

		if value < range.Min or value > range.Max then
			return {
				IsValid = false,
				ErrorMessage = attr .. " must be between " .. range.Min .. " and " .. range.Max,
				ErrorCode = "ATTRIBUTE_OUT_OF_RANGE",
			}
		end

		total = total + value
	end

	-- Проверяем общую сумму атрибутов
	if total > range.MaxTotal then
		return {
			IsValid = false,
			ErrorMessage = "Total attributes cannot exceed " .. range.MaxTotal,
			ErrorCode = "ATTRIBUTES_TOTAL_TOO_HIGH",
		}
	end

	return { IsValid = true }
end

function PlayerTypes.ValidateGold(gold: any): boolean
	if type(gold) ~= "number" then
		return false
	end
	local range = PlayerTypes.VALIDATION_RANGES.Gold
	return gold >= range.Min and gold <= range.Max and gold == math.floor(gold)
end

function PlayerTypes.ValidateHealth(health: any, maxHealth: number?): boolean
	if type(health) ~= "number" then
		return false
	end
	local range = PlayerTypes.VALIDATION_RANGES.Health
	local max = maxHealth or range.Max
	return health >= 0 and health <= max
end

-- Функция для создания дефолтного профиля с валидацией
function PlayerTypes.CreateDefaultProfile(): PlayerProfile
	return {
		Level = Constants.PLAYER.START_LEVEL,
		Experience = Constants.PLAYER.START_EXPERIENCE,

		Attributes = {
			Strength = Constants.PLAYER.BASE_ATTRIBUTES.Strength,
			Dexterity = Constants.PLAYER.BASE_ATTRIBUTES.Dexterity,
			Intelligence = Constants.PLAYER.BASE_ATTRIBUTES.Intelligence,
			Constitution = Constants.PLAYER.BASE_ATTRIBUTES.Constitution,
			Focus = Constants.PLAYER.BASE_ATTRIBUTES.Focus,
		},

		AttributePoints = 0,

		Health = Constants.PLAYER.BASE_HEALTH,
		Mana = Constants.PLAYER.BASE_MANA,
		Stamina = Constants.PLAYER.BASE_STAMINA,

		Inventory = {},
		Equipment = {
			MainHand = nil,
			OffHand = nil,
			Helmet = nil,
			Chest = nil,
			Legs = nil,
			Boots = nil,
			Ring1 = nil,
			Ring2 = nil,
			Amulet = nil,
		},

		Currency = {
			Gold = Constants.PLAYER.START_GOLD,
		},

		Statistics = {
			TotalPlayTime = 0,
			MobsKilled = 0,
			QuestsCompleted = 0,
			ItemsCrafted = 0,
			Deaths = 0,
			DamageDealt = 0,
			DamageTaken = 0,
			DistanceTraveled = 0,
		},

		WeaponMastery = {
			Sword = { Level = 1, Experience = 0 },
			Axe = { Level = 1, Experience = 0 },
			Bow = { Level = 1, Experience = 0 },
			Staff = { Level = 1, Experience = 0 },
			Spear = { Level = 1, Experience = 0 },
		},

		Settings = {
			MusicVolume = 0.5,
			SFXVolume = 0.7,
			ShowDamageNumbers = true,
			AutoPickupItems = true,
			ChatFilter = true,
			ShowPlayerNames = true,
		},

		LastLogin = os.time(),
	}
end

return PlayerTypes
