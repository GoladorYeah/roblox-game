-- src/shared/constants/Constants.lua
-- Основные константы и настройки игры

local Constants = {}

-- Настройки игры
Constants.GAME_NAME = "New World MMO"
Constants.VERSION = "0.1.0"

-- Настройки игрока
Constants.PLAYER = {
	MAX_LEVEL = 100,
	START_LEVEL = 1,
	START_EXPERIENCE = 0,

	-- Базовые характеристики
	BASE_ATTRIBUTES = {
		Strength = 10,
		Dexterity = 10,
		Intelligence = 10,
		Constitution = 10,
		Focus = 10,
	},

	-- Здоровье и мана
	BASE_HEALTH = 100,
	BASE_MANA = 50,
	BASE_STAMINA = 100,

	-- Коэффициенты для расчета статов
	HEALTH_PER_CONSTITUTION = 5,
	MANA_PER_INTELLIGENCE = 3,
	STAMINA_PER_CONSTITUTION = 2,

	-- Стартовая валюта
	START_GOLD = 100,
}

-- Настройки опыта
Constants.EXPERIENCE = {
	-- Формула расчета опыта для следующего уровня: BASE * (level ^ MULTIPLIER)
	BASE_XP_REQUIRED = 100,
	XP_MULTIPLIER = 1.5,

	-- Источники опыта
	KILL_MOB_XP = 25,
	COMPLETE_QUEST_XP = 50,
	CRAFT_ITEM_XP = 10,
}

-- Настройки инвентаря
Constants.INVENTORY = {
	DEFAULT_SLOTS = 50,
	MAX_STACK_SIZE = 100,

	-- Типы предметов
	ITEM_TYPES = {
		WEAPON = "Weapon",
		ARMOR = "Armor",
		CONSUMABLE = "Consumable",
		MATERIAL = "Material",
		QUEST = "Quest",
		GEM = "Gem",
	},

	-- Редкость предметов
	RARITY = {
		COMMON = { Name = "Common", Color = Color3.fromRGB(255, 255, 255) },
		UNCOMMON = { Name = "Uncommon", Color = Color3.fromRGB(30, 255, 0) },
		RARE = { Name = "Rare", Color = Color3.fromRGB(0, 112, 255) },
		EPIC = { Name = "Epic", Color = Color3.fromRGB(163, 53, 238) },
		LEGENDARY = { Name = "Legendary", Color = Color3.fromRGB(255, 128, 0) },
	},
}

-- Настройки оружия
Constants.WEAPONS = {
	TYPES = {
		SWORD = "Sword",
		AXE = "Axe",
		BOW = "Bow",
		STAFF = "Staff",
		SPEAR = "Spear",
	},

	-- Базовый урон по типам
	BASE_DAMAGE = {
		Sword = 25,
		Axe = 30,
		Bow = 20,
		Staff = 35,
		Spear = 22,
	},

	-- Скорость атаки (атак в секунду)
	ATTACK_SPEED = {
		Sword = 1.2,
		Axe = 0.8,
		Bow = 1.5,
		Staff = 0.6,
		Spear = 1.0,
	},
}

-- Настройки боя
Constants.COMBAT = {
	-- Урон
	CRITICAL_CHANCE = 0.05, -- 5% базовый шанс крита
	CRITICAL_MULTIPLIER = 1.5,

	-- Блокирование
	BLOCK_DAMAGE_REDUCTION = 0.5, -- 50% снижения урона при блоке
	BLOCK_STAMINA_COST = 10,

	-- Уклонение
	DODGE_DISTANCE = 10,
	DODGE_STAMINA_COST = 20,
	DODGE_COOLDOWN = 1.0, -- секунды

	-- Регенерация
	HEALTH_REGEN_RATE = 1, -- HP в секунду
	MANA_REGEN_RATE = 2, -- MP в секунду
	STAMINA_REGEN_RATE = 10, -- Stamina в секунду
}

-- Настройки UI
Constants.UI = {
	COLORS = {
		PRIMARY = Color3.fromRGB(41, 128, 185),
		SECONDARY = Color3.fromRGB(52, 73, 94),
		SUCCESS = Color3.fromRGB(39, 174, 96),
		DANGER = Color3.fromRGB(231, 76, 60),
		WARNING = Color3.fromRGB(241, 196, 15),
		INFO = Color3.fromRGB(142, 68, 173),
	},

	FONTS = {
		MAIN = Enum.Font.Gotham,
		BOLD = Enum.Font.GothamBold,
		MONO = Enum.Font.RobotoMono,
	},
}

-- Настройки сети
Constants.NETWORK = {
	-- Rate limiting (запросов в секунду на игрока)
	RATE_LIMITS = {
		CHAT = 5,
		MOVEMENT = 30,
		COMBAT = 10,
		INVENTORY = 5,
		TRADING = 2,
	},

	-- Timeouts
	REQUEST_TIMEOUT = 5, -- секунд
	HEARTBEAT_INTERVAL = 30, -- секунд
}

-- События RemoteEvent'ов
Constants.REMOTE_EVENTS = {
	-- Данные игрока
	PLAYER_DATA_LOADED = "PlayerDataLoaded",
	PLAYER_STATS_CHANGED = "PlayerStatsChanged",

	-- Инвентарь
	INVENTORY_UPDATED = "InventoryUpdated",
	ITEM_EQUIPPED = "ItemEquipped",
	ITEM_UNEQUIPPED = "ItemUnequipped",

	-- Бой
	PLAYER_ATTACKED = "PlayerAttacked",
	DAMAGE_DEALT = "DamageDealt",
	HEALTH_CHANGED = "HealthChanged",

	-- Чат
	CHAT_MESSAGE = "ChatMessage",
	SYSTEM_MESSAGE = "SystemMessage",
}

-- Настройки мира
Constants.WORLD = {
	-- Streaming
	STREAMING_TARGET_RADIUS = 256,
	STREAMING_MAX_RADIUS = 512,

	-- День/ночь
	DAY_LENGTH = 1200, -- секунд (20 минут)
	NIGHT_LENGTH = 600, -- секунд (10 минут)

	-- Респавн
	RESPAWN_TIME = 5, -- секунд
	RESPAWN_INVULNERABILITY = 3, -- секунд неуязвимости после респавна
}

return Constants
