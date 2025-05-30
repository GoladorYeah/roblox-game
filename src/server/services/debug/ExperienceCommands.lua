-- src/server/services/debug/ExperienceCommands.lua
-- Команды для управления опытом и уровнями

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local ExperienceCommands = {}
ExperienceCommands.__index = ExperienceCommands

function ExperienceCommands.new(debugService)
	local self = setmetatable({}, ExperienceCommands)
	self.DebugService = debugService
	return self
end

function ExperienceCommands:RegisterCommands()
	local debugService = self.DebugService

	debugService:RegisterCommand(
		"addxp",
		"Добавить опыт: /addxp [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 100
			self:AddExperience(player, amount)
		end
	)

	debugService:RegisterCommand(
		"setexp",
		"Установить опыт для уровня: /setexp [количество]",
		function(player, args)
			local experience = tonumber(args[1]) or 0
			self:SetCurrentExperience(player, experience)
		end
	)

	debugService:RegisterCommand(
		"settotalexp",
		"Установить общий опыт: /settotalexp [количество]",
		function(player, args)
			local totalExperience = tonumber(args[1]) or 0
			self:SetTotalExperience(player, totalExperience)
		end
	)

	debugService:RegisterCommand(
		"setlevel",
		"Установить уровень: /setlevel [уровень]",
		function(player, args)
			local level = tonumber(args[1]) or 1
			self:SetLevel(player, level)
		end
	)

	debugService:RegisterCommand("xpdiag", "Диагностика опыта", function(player, _)
		self:DiagnoseExperience(player)
	end)

	debugService:RegisterCommand("fixexp", "Исправить опыт: /fixexp [mode]", function(player, args)
		local mode = args[1] or "auto"
		self:FixPlayerExperience(player, mode)
	end)

	debugService:RegisterCommand(
		"xpcalc",
		"Калькулятор опыта: /xpcalc [уровень]",
		function(player, args)
			local level = tonumber(args[1])
			if not level then
				local ServiceManager = self.DebugService:GetServiceManager()
				local PlayerDataService = ServiceManager:GetService("PlayerDataService")
				local data = PlayerDataService:GetData(player)
				level = data and data.Level or 1
			end
			self:ShowExperienceCalculations(player, level)
		end
	)

	debugService:RegisterCommand(
		"simulate",
		"Симуляция повышения: /simulate [xp]",
		function(player, args)
			local xpToAdd = tonumber(args[1]) or 100
			self:SimulateExperienceGain(player, xpToAdd)
		end
	)
end

-- Добавить опыт
function ExperienceCommands:AddExperience(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService ~= nil and PlayerDataService:IsDataLoaded(player) then
		PlayerDataService:AddExperience(player, amount)
		self.DebugService:SendMessage(player, string.format("✅ Добавлено %d опыта!", amount))
	else
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
	end
end

-- Установить уровень с правильным расчетом опыта
function ExperienceCommands:SetLevel(player, level)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		level = math.max(1, math.min(level, Constants.PLAYER.MAX_LEVEL))

		-- Устанавливаем уровень и обнуляем опыт в начале уровня
		data.Level = level
		data.Experience = 0 -- Опыт в начале уровня

		-- Пересчитываем очки атрибутов
		data.AttributePoints = math.max(0, (level - 1) * 5) -- 5 очков за каждый уровень после первого

		-- Пересчитываем ресурсы с новыми характеристиками
		PlayerDataService:InitializePlayerResources(player)

		-- Отправляем обновленные данные клиенту
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		-- Отправляем событие повышения уровня для эффектов
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.LEVEL_UP, {
			NewLevel = level,
			AttributePoints = data.AttributePoints,
		})

		local requiredForNext = PlayerDataService:GetRequiredExperience(level)
		self.DebugService:SendMessage(player, string.format("✅ Уровень установлен на %d!", level))
		self.DebugService:SendMessage(
			player,
			string.format("Опыт: 0/%d, Очки атрибутов: %d", requiredForNext, data.AttributePoints)
		)

		print(
			string.format(
				"[DEBUG] %s level set to %d (XP: 0/%d, Points: %d)",
				player.Name,
				level,
				requiredForNext,
				data.AttributePoints
			)
		)
	end
end

-- Установить текущий опыт для уровня (остаток)
function ExperienceCommands:SetCurrentExperience(player, experience)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		experience = math.max(0, experience)

		-- Получаем требуемый опыт для следующего уровня
		local requiredXP = PlayerDataService:GetRequiredExperience(data.Level)

		-- Ограничиваем опыт максимумом для текущего уровня
		if experience >= requiredXP then
			experience = requiredXP - 1
			self.DebugService:SendMessage(
				player,
				string.format(
					"⚠️ Опыт ограничен до %d (макс. для уровня %d)",
					experience,
					data.Level
				)
			)
		end

		data.Experience = experience

		-- Отправляем обновленные данные
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.EXPERIENCE_CHANGED, {
			Experience = experience,
			Level = data.Level,
			RequiredXP = requiredXP,
		})

		self.DebugService:SendMessage(
			player,
			string.format(
				"✅ Опыт установлен: %d/%d для уровня %d",
				experience,
				requiredXP,
				data.Level
			)
		)

		print(string.format("[DEBUG] %s current experience set to %d/%d", player.Name, experience, requiredXP))
	end
end

-- Установить общий накопленный опыт
function ExperienceCommands:SetTotalExperience(player, totalExperience)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		totalExperience = math.max(0, totalExperience)

		-- Сохраняем старые значения для сравнения
		local oldLevel = data.Level
		local oldExperience = data.Experience

		-- Пересчитываем уровень и остаток опыта из общего опыта
		local newLevel = 1
		local remainingExp = totalExperience

		-- Находим правильный уровень
		while newLevel < Constants.PLAYER.MAX_LEVEL do
			local expRequired = PlayerDataService:GetRequiredExperience(newLevel)
			if remainingExp < expRequired then
				break
			end
			remainingExp = remainingExp - expRequired
			newLevel = newLevel + 1
		end

		-- Устанавливаем новые значения
		data.Level = newLevel
		data.Experience = remainingExp

		-- Пересчитываем очки атрибутов
		data.AttributePoints = math.max(0, (newLevel - 1) * 5)

		-- Пересчитываем ресурсы
		PlayerDataService:InitializePlayerResources(player)

		-- Отправляем обновленные данные
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		-- Если уровень изменился, отправляем событие
		if newLevel ~= oldLevel then
			PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.LEVEL_UP, {
				NewLevel = newLevel,
				AttributePoints = data.AttributePoints,
			})
		end

		local nextLevelXP = PlayerDataService:GetRequiredExperience(newLevel)
		self.DebugService:SendMessage(
			player,
			string.format("✅ Общий опыт установлен на %d!", totalExperience)
		)
		self.DebugService:SendMessage(
			player,
			string.format("Уровень: %d, Опыт: %d/%d", newLevel, remainingExp, nextLevelXP)
		)

		print(
			string.format(
				"[DEBUG] %s total experience set: Level %d -> %d, Current XP %d -> %d",
				player.Name,
				oldLevel,
				newLevel,
				oldExperience,
				remainingExp
			)
		)
	end
end

-- Калькулятор опыта
function ExperienceCommands:ShowExperienceCalculations(player, level)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	self.DebugService:SendMessage(player, "=== КАЛЬКУЛЯТОР ОПЫТА ===")
	self.DebugService:SendMessage(player, string.format("Расчеты для уровня: %d", level))

	-- Опыт для достижения этого уровня
	local expForLevel = PlayerDataService:GetRequiredExperience(level)
	self.DebugService:SendMessage(player, string.format("Опыт для уровня %d: %d", level, expForLevel))

	-- Общий опыт для достижения этого уровня
	local totalExpForLevel = 0
	for i = 1, level - 1 do
		totalExpForLevel = totalExpForLevel + PlayerDataService:GetRequiredExperience(i)
	end
	self.DebugService:SendMessage(
		player,
		string.format("Общий опыт до %d уровня: %d", level, totalExpForLevel)
	)

	-- Опыт для следующего уровня
	if level < Constants.PLAYER.MAX_LEVEL then
		local expForNext = PlayerDataService:GetRequiredExperience(level + 1)
		self.DebugService:SendMessage(
			player,
			string.format("Опыт для %d уровня: %d", level + 1, expForNext)
		)
		self.DebugService:SendMessage(
			player,
			string.format("Общий опыт до %d уровня: %d", level + 1, totalExpForLevel + expForLevel)
		)
	end

	-- Показываем формулу
	local baseXP = Constants.EXPERIENCE.BASE_XP_REQUIRED
	local multiplier = Constants.EXPERIENCE.XP_MULTIPLIER
	self.DebugService:SendMessage(
		player,
		string.format("Формула: %d * (%d ^ %.1f) = %d", baseXP, level, multiplier, expForLevel)
	)

	-- Показываем таблицу для нескольких уровней
	self.DebugService:SendMessage(player, "--- ТАБЛИЦА УРОВНЕЙ ---")
	local startLevel = math.max(1, level - 2)
	local endLevel = math.min(Constants.PLAYER.MAX_LEVEL, level + 2)

	for i = startLevel, endLevel do
		local exp = PlayerDataService:GetRequiredExperience(i)
		local marker = (i == level) and " <-- ТЕКУЩИЙ" or ""
		self.DebugService:SendMessage(player, string.format("Уровень %d: %d XP%s", i, exp, marker))
	end
end

-- Симуляция получения опыта
function ExperienceCommands:SimulateExperienceGain(player, xpToAdd)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data == nil then
		return
	end

	self.DebugService:SendMessage(player, "=== СИМУЛЯЦИЯ ПОЛУЧЕНИЯ ОПЫТА ===")
	self.DebugService:SendMessage(
		player,
		string.format("Добавляем %d опыта к текущему", xpToAdd)
	)
	self.DebugService:SendMessage(
		player,
		string.format("Текущее состояние: Уровень %d, Опыт %d", data.Level, data.Experience)
	)

	-- Симулируем без изменения данных
	local simulatedLevel = data.Level
	local simulatedXP = data.Experience + xpToAdd
	local levelsGained = 0
	local totalAttributePoints = 0

	while
		simulatedXP >= PlayerDataService:GetRequiredExperience(simulatedLevel)
		and simulatedLevel < Constants.PLAYER.MAX_LEVEL
	do
		local requiredXP = PlayerDataService:GetRequiredExperience(simulatedLevel)
		simulatedXP = simulatedXP - requiredXP
		simulatedLevel = simulatedLevel + 1
		levelsGained = levelsGained + 1
		totalAttributePoints = totalAttributePoints + 5
	end

	local nextLevelXP = PlayerDataService:GetRequiredExperience(simulatedLevel)

	self.DebugService:SendMessage(
		player,
		string.format("Результат: Уровень %d, Опыт %d/%d", simulatedLevel, simulatedXP, nextLevelXP)
	)

	if levelsGained > 0 then
		self.DebugService:SendMessage(
			player,
			string.format("🎉 Повышение на %d уровней!", levelsGained)
		)
		self.DebugService:SendMessage(
			player,
			string.format("Получено очков атрибутов: %d", totalAttributePoints)
		)

		-- Показываем детали каждого повышения
		if levelsGained <= 5 then -- Показываем детали только если уровней немного
			self.DebugService:SendMessage(player, "--- ДЕТАЛИ ПОВЫШЕНИЙ ---")
			local tempLevel = data.Level
			local tempXP = data.Experience + xpToAdd

			while
				tempXP >= PlayerDataService:GetRequiredExperience(tempLevel)
				and tempLevel < Constants.PLAYER.MAX_LEVEL
			do
				local requiredXP = PlayerDataService:GetRequiredExperience(tempLevel)
				tempXP = tempXP - requiredXP
				tempLevel = tempLevel + 1
				self.DebugService:SendMessage(
					player,
					string.format("Уровень %d достигнут! Остаток: %d XP", tempLevel, tempXP)
				)
			end
		end
	else
		local progress = (simulatedXP / nextLevelXP) * 100
		self.DebugService:SendMessage(
			player,
			string.format("Прогресс к уровню %d: %.1f%%", simulatedLevel + 1, progress)
		)

		-- Показываем сколько еще нужно до следующего уровня
		local neededXP = nextLevelXP - simulatedXP
		self.DebugService:SendMessage(player, string.format("До следующего уровня: %d XP", neededXP))
	end
end

-- Диагностика опыта
function ExperienceCommands:DiagnoseExperience(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not PlayerDataService:IsDataLoaded(player) then
		self.DebugService:SendMessage(player, "❌ Данные не загружены")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self.DebugService:SendMessage(player, "❌ Данные недоступны")
		return
	end

	self.DebugService:SendMessage(player, "=== ДИАГНОСТИКА ОПЫТА ===")
	self.DebugService:SendMessage(player, string.format("Текущий уровень: %d", data.Level))
	self.DebugService:SendMessage(player, string.format("Текущий опыт: %d", data.Experience))

	-- Рассчитываем опыт для текущего и следующего уровня
	local expForCurrentLevel = PlayerDataService:GetRequiredExperience(data.Level)
	local totalExp = PlayerDataService:GetTotalExperience(player)

	self.DebugService:SendMessage(
		player,
		string.format("Нужно для следующего уровня: %d", expForCurrentLevel)
	)
	self.DebugService:SendMessage(player, string.format("Общий накопленный опыт: %d", totalExp))

	-- Проверяем корректность
	local issues = {}

	-- Проверка 1: Опыт не должен превышать требуемый для следующего уровня
	if data.Experience >= expForCurrentLevel then
		table.insert(
			issues,
			string.format(
				"⚠️ Слишком много опыта для уровня! (%d >= %d)",
				data.Experience,
				expForCurrentLevel
			)
		)
	end

	-- Проверка 2: Опыт не должен быть отрицательным
	if data.Experience < 0 then
		table.insert(issues, "⚠️ Отрицательный опыт!")
	end

	-- Проверка 3: Соответствие очков атрибутов уровню
	local expectedAttributePoints = math.max(0, (data.Level - 1) * 5)
	if data.AttributePoints > expectedAttributePoints then
		table.insert(
			issues,
			string.format(
				"⚠️ Слишком много очков атрибутов! (%d > %d)",
				data.AttributePoints,
				expectedAttributePoints
			)
		)
	end

	-- Показываем результаты
	if #issues == 0 then
		self.DebugService:SendMessage(player, "✅ Система опыта в норме!")

		-- Показываем прогресс
		local progress = (data.Experience / expForCurrentLevel) * 100
		self.DebugService:SendMessage(
			player,
			string.format("Прогресс к уровню %d: %.1f%%", data.Level + 1, progress)
		)

		-- Показываем статистику
		local neededXP = expForCurrentLevel - data.Experience
		self.DebugService:SendMessage(player, string.format("До следующего уровня: %d XP", neededXP))
	else
		for _, issue in ipairs(issues) do
			self.DebugService:SendMessage(player, issue)
		end
		self.DebugService:SendMessage(player, "Используйте /fixexp для исправления")
	end

	-- Показываем детали расчетов
	self.DebugService:SendMessage(player, "--- ДЕТАЛИ ---")
	self.DebugService:SendMessage(player, string.format("Базовый XP: %d", Constants.EXPERIENCE.BASE_XP_REQUIRED))
	self.DebugService:SendMessage(player, string.format("Множитель: %.1f", Constants.EXPERIENCE.XP_MULTIPLIER))
	self.DebugService:SendMessage(player, string.format("Макс уровень: %d", Constants.PLAYER.MAX_LEVEL))
	self.DebugService:SendMessage(
		player,
		string.format("Ожидаемые очки атрибутов: %d", expectedAttributePoints)
	)
end

-- Исправление опыта с режимами
function ExperienceCommands:FixPlayerExperience(player, mode)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not PlayerDataService:IsDataLoaded(player) then
		self.DebugService:SendMessage(player, "❌ Данные не загружены")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self.DebugService:SendMessage(player, "❌ Данные недоступны")
		return
	end

	local oldLevel = data.Level
	local oldExp = data.Experience
	local totalExp = PlayerDataService:GetTotalExperience(player)

	self.DebugService:SendMessage(
		player,
		string.format("=== ИСПРАВЛЕНИЕ ОПЫТА (режим: %s) ===", mode)
	)
	self.DebugService:SendMessage(
		player,
		string.format("Текущее состояние: Уровень %d, Опыт %d", oldLevel, oldExp)
	)

	if mode == "reset" then
		-- Режим 1: Сброс к началу уровня
		data.Experience = 0
		self.DebugService:SendMessage(
			player,
			string.format("✅ Опыт сброшен к началу %d уровня", data.Level)
		)
	elseif mode == "recalc" then
		-- Режим 2: Пересчет уровня из общего опыта
		local newLevel = 1
		local remainingExp = totalExp

		while newLevel < Constants.PLAYER.MAX_LEVEL do
			local expRequired = PlayerDataService:GetRequiredExperience(newLevel)
			if remainingExp < expRequired then
				break
			end
			remainingExp = remainingExp - expRequired
			newLevel = newLevel + 1
		end

		data.Level = newLevel
		data.Experience = remainingExp
		data.AttributePoints = math.max(0, (newLevel - 1) * 5)

		self.DebugService:SendMessage(
			player,
			string.format("✅ Пересчитано: Уровень %d -> %d", oldLevel, newLevel)
		)
		self.DebugService:SendMessage(player, string.format("Опыт: %d -> %d", oldExp, remainingExp))
	else -- mode == "auto" или любой другой
		-- Автоматический режим: выбираем лучший вариант
		local expForCurrentLevel = PlayerDataService:GetRequiredExperience(data.Level)

		if data.Experience >= expForCurrentLevel then
			-- Слишком много опыта - автоматически повышаем уровень
			local levelsGained = 0

			while data.Experience >= expForCurrentLevel and data.Level < Constants.PLAYER.MAX_LEVEL do
				data.Experience = data.Experience - expForCurrentLevel
				data.Level = data.Level + 1
				data.AttributePoints = data.AttributePoints + 5
				levelsGained = levelsGained + 1

				expForCurrentLevel = PlayerDataService:GetRequiredExperience(data.Level)
			end

			self.DebugService:SendMessage(
				player,
				string.format("✅ Автоповышение на %d уровней!", levelsGained)
			)
		elseif data.Experience < 0 then
			-- Отрицательный опыт - сбрасываем
			data.Experience = 0
			self.DebugService:SendMessage(player, "✅ Исправлен отрицательный опыт")
		else
			self.DebugService:SendMessage(player, "✅ Опыт уже в норме")
			return
		end
	end

	-- Применяем изменения
	PlayerDataService:InitializePlayerResources(player)
	PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

	if data.Level ~= oldLevel then
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.LEVEL_UP, {
			NewLevel = data.Level,
			AttributePoints = data.AttributePoints,
		})
	end

	local newRequiredXP = PlayerDataService:GetRequiredExperience(data.Level)
	self.DebugService:SendMessage(
		player,
		string.format(
			"Новое состояние: Уровень %d, Опыт %d/%d",
			data.Level,
			data.Experience,
			newRequiredXP
		)
	)

	print(
		string.format(
			"[DEBUG] %s experience fixed: %s mode, Level %d->%d, XP %d->%d",
			player.Name,
			mode,
			oldLevel,
			data.Level,
			oldExp,
			data.Experience
		)
	)
end

return ExperienceCommands
