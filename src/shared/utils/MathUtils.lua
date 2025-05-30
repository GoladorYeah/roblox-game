-- src/shared/utils/MathUtils.lua
-- Математические утилиты для игровых расчетов

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local MathUtils = {}

---[[ БАЗОВЫЕ МАТЕМАТИЧЕСКИЕ ФУНКЦИИ ]]---

-- Зажатие значения в диапазоне
function MathUtils.Clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

-- Линейная интерполяция
function MathUtils.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * MathUtils.Clamp(t, 0, 1)
end

-- Обратная линейная интерполяция (получить t из значения)
function MathUtils.InverseLerp(a: number, b: number, value: number): number
	if a == b then
		return 0
	end
	return MathUtils.Clamp((value - a) / (b - a), 0, 1)
end

-- Округление до определенного количества знаков
function MathUtils.Round(value: number, decimals: number?): number
	local actualDecimals = decimals or 0
	local multiplier = 10 ^ actualDecimals
	return math.floor(value * multiplier + 0.5) / multiplier
end

-- Проверка приблизительного равенства чисел
function MathUtils.Approximately(a: number, b: number, epsilon: number?): boolean
	local actualEpsilon = epsilon or 0.0001
	return math.abs(a - b) < actualEpsilon
end

-- Знак числа (-1, 0, 1)
function MathUtils.Sign(value: number): number
	if value > 0 then
		return 1
	elseif value < 0 then
		return -1
	else
		return 0
	end
end

-- Случайное число в диапазоне с плавающей точкой
function MathUtils.RandomFloat(min: number, max: number): number
	return min + math.random() * (max - min)
end

-- Случайное число с нормальным распределением (Box-Muller)
function MathUtils.RandomGaussian(mean: number?, stdDev: number?): number
	local actualMean = mean or 0
	local actualStdDev = stdDev or 1

	local u1 = math.random()
	local u2 = math.random()

	local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	return z0 * actualStdDev + actualMean
end

---[[ ИГРОВЫЕ РАСЧЕТЫ ]]---

-- Расчет опыта, необходимого для уровня
function MathUtils.CalculateRequiredExperience(level: number): number
	return math.floor(Constants.EXPERIENCE.BASE_XP_REQUIRED * (level ^ Constants.EXPERIENCE.XP_MULTIPLIER))
end

-- Расчет уровня по опыту
function MathUtils.CalculateLevelFromExperience(totalExperience: number): number
	local level = 1
	local expForNextLevel = MathUtils.CalculateRequiredExperience(level)
	local currentExp = totalExperience

	while currentExp >= expForNextLevel and level < Constants.PLAYER.MAX_LEVEL do
		currentExp = currentExp - expForNextLevel
		level = level + 1
		expForNextLevel = MathUtils.CalculateRequiredExperience(level)
	end

	return level
end

-- Расчет прогресса опыта в процентах
function MathUtils.CalculateExperienceProgress(currentExp: number, level: number): number
	local requiredExp = MathUtils.CalculateRequiredExperience(level)
	if requiredExp == 0 then
		return 100
	end
	return MathUtils.Clamp((currentExp / requiredExp) * 100, 0, 100)
end

-- Расчет максимального здоровья
function MathUtils.CalculateMaxHealth(constitution: number): number
	return Constants.PLAYER.BASE_HEALTH + (constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
end

-- Расчет максимальной маны
function MathUtils.CalculateMaxMana(intelligence: number): number
	return Constants.PLAYER.BASE_MANA + (intelligence * Constants.PLAYER.MANA_PER_INTELLIGENCE)
end

-- Расчет максимальной стамины
function MathUtils.CalculateMaxStamina(constitution: number): number
	return Constants.PLAYER.BASE_STAMINA + (constitution * Constants.PLAYER.STAMINA_PER_CONSTITUTION)
end

-- Расчет урона с учетом характеристик
function MathUtils.CalculateDamage(baseDamage: number, strength: number, weaponType: string?): number
	local strengthBonus = strength * 0.5 -- 0.5 урона за 1 силу
	local weaponMultiplier = 1.0

	if weaponType and Constants.WEAPONS.BASE_DAMAGE[weaponType] then
		weaponMultiplier = Constants.WEAPONS.BASE_DAMAGE[weaponType] / 25.0 -- Нормализация относительно базового урона меча
	end

	return math.floor((baseDamage + strengthBonus) * weaponMultiplier)
end

-- Расчет шанса критического удара
function MathUtils.CalculateCriticalChance(dexterity: number, baseChance: number?): number
	local actualBaseChance = baseChance or Constants.COMBAT.CRITICAL_CHANCE
	local dexterityBonus = dexterity * 0.001 -- 0.1% за 1 ловкость
	return MathUtils.Clamp(actualBaseChance + dexterityBonus, 0, 0.5) -- Максимум 50% крита
end

-- Проверка критического удара
function MathUtils.IsCriticalHit(criticalChance: number): boolean
	return math.random() < criticalChance
end

-- Расчет финального урона с критом
function MathUtils.CalculateFinalDamage(baseDamage: number, isCritical: boolean, criticalMultiplier: number?): number
	local actualMultiplier = criticalMultiplier or Constants.COMBAT.CRITICAL_MULTIPLIER

	if isCritical then
		return math.floor(baseDamage * actualMultiplier)
	else
		return baseDamage
	end
end

-- Расчет стоимости улучшения предмета
function MathUtils.CalculateUpgradeCost(currentLevel: number, basePrice: number): number
	return math.floor(basePrice * (1.5 ^ currentLevel))
end

---[[ ЭКОНОМИЧЕСКИЕ РАСЧЕТЫ ]]---

-- Расчет стоимости предмета с учетом редкости
function MathUtils.CalculateItemValue(baseValue: number, rarity: string, level: number?): number
	local actualLevel = level or 1

	local rarityMultipliers = {
		Common = 1.0,
		Uncommon = 2.0,
		Rare = 5.0,
		Epic = 12.0,
		Legendary = 30.0,
	}

	local rarityMultiplier = rarityMultipliers[rarity] or 1.0
	local levelMultiplier = 1 + (actualLevel - 1) * 0.1 -- 10% за уровень

	return math.floor(baseValue * rarityMultiplier * levelMultiplier)
end

-- Расчет налога на торговлю
function MathUtils.CalculateTradeTax(amount: number, taxRate: number?): number
	local actualTaxRate = taxRate or 0.05 -- 5% по умолчанию
	return math.floor(amount * actualTaxRate)
end

-- Расчет скидки
function MathUtils.ApplyDiscount(originalPrice: number, discountPercent: number): number
	discountPercent = MathUtils.Clamp(discountPercent, 0, 100)
	return math.floor(originalPrice * (1 - discountPercent / 100))
end

---[[ ГЕОМЕТРИЧЕСКИЕ ФУНКЦИИ ]]---

-- Расстояние между двумя точками
function MathUtils.Distance(pos1: Vector3, pos2: Vector3): number
	return (pos1 - pos2).Magnitude
end

-- Расстояние в 2D (игнорируя Y)
function MathUtils.Distance2D(pos1: Vector3, pos2: Vector3): number
	local dx = pos1.X - pos2.X
	local dz = pos1.Z - pos2.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Проверка, находится ли точка в радиусе
function MathUtils.IsInRange(pos1: Vector3, pos2: Vector3, range: number): boolean
	return MathUtils.Distance(pos1, pos2) <= range
end

-- Направление от одной точки к другой (нормализованный вектор)
function MathUtils.Direction(from: Vector3, to: Vector3): Vector3
	local direction = (to - from)
	return direction.Unit
end

---[[ ВРЕМЕННЫЕ ФУНКЦИИ ]]---

-- Конвертация секунд в читаемый формат
function MathUtils.FormatTime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	else
		return string.format("%d:%02d", minutes, secs)
	end
end

-- Проверка, прошло ли определенное время
function MathUtils.HasTimePassed(lastTime: number, interval: number): boolean
	return tick() - lastTime >= interval
end

-- Получение времени до события
function MathUtils.TimeUntil(targetTime: number): number
	return math.max(0, targetTime - tick())
end

---[[ АНИМАЦИОННЫЕ ФУНКЦИИ ]]---

-- Easing функции для плавной анимации
MathUtils.Easing = {}

function MathUtils.Easing.EaseInQuad(t: number): number
	return t * t
end

function MathUtils.Easing.EaseOutQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end

function MathUtils.Easing.EaseInOutQuad(t: number): number
	if t < 0.5 then
		return 2 * t * t
	else
		return 1 - 2 * (1 - t) * (1 - t)
	end
end

---[[ УТИЛИТЫ ДЛЯ РАЗРАБОТКИ ]]---

-- Бенчмарк функции
function MathUtils.Benchmark(func: () -> (), iterations: number?): number
	local actualIterations = iterations or 1000

	local startTime = tick()

	for _ = 1, actualIterations do
		func()
	end

	local endTime = tick()
	return (endTime - startTime) / actualIterations * 1000 -- миллисекунды
end

-- Генерация случайного UUID (простая версия)
function MathUtils.GenerateUUID(): string
	local chars = "0123456789ABCDEF"
	local uuid = ""

	for i = 1, 32 do
		if i == 9 or i == 14 or i == 19 or i == 24 then
			uuid = uuid .. "-"
		end

		local randomIndex = math.random(1, #chars)
		uuid = uuid .. string.sub(chars, randomIndex, randomIndex)
	end

	return uuid
end

return MathUtils
