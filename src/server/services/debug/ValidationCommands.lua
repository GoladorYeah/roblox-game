-- src/server/services/debug/ValidationCommands.lua
-- Команды для тестирования валидации

local ValidationCommands = {}
ValidationCommands.__index = ValidationCommands

function ValidationCommands.new(debugService)
	local self = setmetatable({}, ValidationCommands)
	self.DebugService = debugService
	return self
end

function ValidationCommands:RegisterCommands()
	local debugService = self.DebugService

	debugService:RegisterCommand("valstats", "Статистика валидации", function(player, _)
		self:ShowValidationStats(player)
	end)

	debugService:RegisterCommand("testval", "Тест валидации: /testval [тип]", function(player, args)
		local testType = args[1] or "player"
		self:TestValidation(player, testType)
	end)

	debugService:RegisterCommand("resetval", "Сброс статистики валидации", function(player, _)
		self:ResetValidationStats(player)
	end)

	debugService:RegisterCommand("valtest", "Быстрый тест валидации", function(player, _)
		self:QuickValidationTest(player)
	end)

	debugService:RegisterCommand(
		"valdebug",
		"Режим отладки валидации: /valdebug [on/off]",
		function(player, args)
			local mode = args[1] or "toggle"
			self:SetValidationDebugMode(player, mode)
		end
	)
end

-- Показать статистику валидации
function ValidationCommands:ShowValidationStats(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local ValidationService = ServiceManager:GetService("ValidationService")

	if not ValidationService then
		self.DebugService:SendMessage(player, "❌ ValidationService недоступен!")
		return
	end

	local stats = ValidationService:GetValidationStatistics()

	self.DebugService:SendMessage(player, "=== СТАТИСТИКА ВАЛИДАЦИИ ===")
	self.DebugService:SendMessage(player, string.format("Общих проверок: %d", stats.TotalValidations))
	self.DebugService:SendMessage(player, string.format("Успешных: %d", stats.PassedValidations))
	self.DebugService:SendMessage(player, string.format("Неудачных: %d", stats.FailedValidations))
	self.DebugService:SendMessage(player, string.format("Успешность: %.2f%%", stats.SuccessRate))
	self.DebugService:SendMessage(
		player,
		string.format("Попаданий в кэш: %d (%.2f%%)", stats.CacheHits, stats.CacheHitRate)
	)
	self.DebugService:SendMessage(player, string.format("Время работы: %.2f часов", stats.UptimeHours))

	-- Показываем самые частые ошибки
	if next(stats.MostCommonErrors) then
		self.DebugService:SendMessage(player, "--- ЧАСТЫЕ ОШИБКИ ---")

		-- Сортируем ошибки по частоте
		local sortedErrors = {}
		for errorCode, count in pairs(stats.MostCommonErrors) do
			table.insert(sortedErrors, { code = errorCode, count = count })
		end

		table.sort(sortedErrors, function(a, b)
			return a.count > b.count
		end)

		-- Показываем топ-5 ошибок
		for i = 1, math.min(5, #sortedErrors) do
			local error = sortedErrors[i]
			self.DebugService:SendMessage(player, string.format("  %s: %d раз", error.code, error.count))
		end
	else
		self.DebugService:SendMessage(player, "✅ Ошибок валидации не обнаружено")
	end
end

-- Тестирование валидации
function ValidationCommands:TestValidation(player, testType)
	local ServiceManager = self.DebugService:GetServiceManager()
	local ValidationService = ServiceManager:GetService("ValidationService")
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not ValidationService then
		self.DebugService:SendMessage(player, "❌ ValidationService недоступен!")
		return
	end

	self.DebugService:SendMessage(
		player,
		string.format("🧪 Запуск тестов валидации: %s", testType)
	)

	if testType == "player" then
		-- Тест валидации данных игрока
		local data = PlayerDataService:GetData(player)
		if data then
			local result = ValidationService:ValidatePlayerData(data, player.UserId)
			if result.IsValid then
				self.DebugService:SendMessage(player, "✅ Данные игрока прошли валидацию")
			else
				self.DebugService:SendMessage(
					player,
					string.format("❌ Ошибка валидации: %s", result.ErrorMessage or "Unknown")
				)
				self.DebugService:SendMessage(
					player,
					string.format("Код ошибки: %s", result.ErrorCode or "UNKNOWN")
				)
			end
		else
			self.DebugService:SendMessage(player, "❌ Данные игрока не загружены")
		end
	elseif testType == "exp" then
		-- Тест валидации опыта
		local result = ValidationService:ValidateExperienceChange(100, 50, player.UserId)
		if result.IsValid then
			self.DebugService:SendMessage(player, "✅ Валидация опыта пройдена")
		else
			self.DebugService:SendMessage(
				player,
				string.format("❌ Ошибка валидации опыта: %s", result.ErrorMessage or "Unknown")
			)
		end

		-- Тест недопустимого опыта
		local badResult = ValidationService:ValidateExperienceChange(100, 100000, player.UserId)
		if not badResult.IsValid then
			self.DebugService:SendMessage(player, "✅ Большой опыт корректно отклонен")
		else
			self.DebugService:SendMessage(player, "❌ Большой опыт не был отклонен!")
		end
	elseif testType == "gold" then
		-- Тест валидации золота
		local result = ValidationService:ValidateGoldTransaction(1000, -500, "ITEM_PURCHASE", player.UserId)
		if result.IsValid then
			self.DebugService:SendMessage(player, "✅ Валидация золота пройдена")
		else
			self.DebugService:SendMessage(
				player,
				string.format("❌ Ошибка валидации золота: %s", result.ErrorMessage or "Unknown")
			)
		end

		-- Тест недостатка золота
		local poorResult = ValidationService:ValidateGoldTransaction(100, -500, "ITEM_PURCHASE", player.UserId)
		if not poorResult.IsValid then
			self.DebugService:SendMessage(
				player,
				"✅ Недостаток золота корректно отклонен"
			)
		else
			self.DebugService:SendMessage(player, "❌ Недостаток золота не был отклонен!")
		end
	elseif testType == "level" then
		-- Тест валидации уровней
		local tests = {
			{ current = 5, new = 6, shouldPass = true, desc = "Нормальное повышение" },
			{ current = 10, new = 12, shouldPass = false, desc = "Прыжок через уровень" },
			{ current = 15, new = 14, shouldPass = false, desc = "Понижение уровня" },
			{ current = 50, new = 51, shouldPass = true, desc = "Высокие уровни" },
		}

		self.DebugService:SendMessage(player, "--- ТЕСТЫ УРОВНЕЙ ---")
		local passedTests = 0

		for _, test in ipairs(tests) do
			local result = ValidationService:ValidateLevelChange(test.current, test.new, player.UserId)
			local passed = (result.IsValid == test.shouldPass)

			if passed then
				passedTests = passedTests + 1
				self.DebugService:SendMessage(player, string.format("✅ %s", test.desc))
			else
				self.DebugService:SendMessage(player, string.format("❌ %s", test.desc))
			end
		end

		self.DebugService:SendMessage(
			player,
			string.format("Результат: %d/%d тестов пройдено", passedTests, #tests)
		)
	elseif testType == "stress" then
		-- Стресс-тест валидации
		self.DebugService:SendMessage(player, "🔥 Запуск стресс-теста (1000 валидаций)...")

		local startTime = tick()
		local passedTests = 0
		local testCount = 1000

		for _ = 1, testCount do
			local testData = self:GenerateRandomPlayerData()
			local result = ValidationService:ValidatePlayerData(testData, player.UserId)
			if result.IsValid then
				passedTests = passedTests + 1
			end
		end

		local endTime = tick()
		local duration = (endTime - startTime) * 1000

		self.DebugService:SendMessage(
			player,
			string.format("⚡ Стресс-тест завершен за %.2f мс", duration)
		)
		self.DebugService:SendMessage(
			player,
			string.format(
				"Прошло: %d/%d тестов (%.1f%%)",
				passedTests,
				testCount,
				(passedTests / testCount) * 100
			)
		)
		self.DebugService:SendMessage(
			player,
			string.format("Среднее время: %.3f мс/тест", duration / testCount)
		)

		-- Оценка производительности
		if duration < 1000 then
			self.DebugService:SendMessage(player, "🚀 Отличная производительность!")
		elseif duration < 3000 then
			self.DebugService:SendMessage(player, "✅ Хорошая производительность")
		else
			self.DebugService:SendMessage(player, "⚠️ Медленная производительность")
		end
	elseif testType == "all" then
		-- Полный набор тестов
		self.DebugService:SendMessage(player, "🧪 Запуск полного набора тестов...")

		self:TestValidation(player, "player")
		self:TestValidation(player, "exp")
		self:TestValidation(player, "gold")
		self:TestValidation(player, "level")

		self.DebugService:SendMessage(player, "✅ Все базовые тесты завершены")
	else
		self.DebugService:SendMessage(player, "❌ Неизвестный тип теста!")
		self.DebugService:SendMessage(player, "Доступные типы: player, exp, gold, level, stress, all")
	end
end

-- Быстрый тест валидации текущего игрока
function ValidationCommands:QuickValidationTest(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local ValidationService = ServiceManager:GetService("ValidationService")
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not ValidationService or not PlayerDataService then
		self.DebugService:SendMessage(player, "❌ Сервисы недоступны!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	self.DebugService:SendMessage(player, "⚡ Быстрая проверка...")

	-- Проверяем основные компоненты
	local tests = {
		{
			name = "Данные игрока",
			test = function()
				return ValidationService:ValidatePlayerData(data, player.UserId)
			end,
		},
		{
			name = "Опыт для уровня",
			test = function()
				return ValidationService:ValidateExperienceForLevel(data.Level, data.Experience)
			end,
		},
		{
			name = "Целостность данных",
			test = function()
				return ValidationService:ValidateDataIntegrity(data)
			end,
		},
	}

	local passedTests = 0
	for _, test in ipairs(tests) do
		local result = test.test()
		if result.IsValid then
			self.DebugService:SendMessage(player, string.format("✅ %s", test.name))
			passedTests = passedTests + 1
		else
			self.DebugService:SendMessage(
				player,
				string.format("❌ %s: %s", test.name, result.ErrorMessage or "Unknown")
			)
		end
	end

	if passedTests == #tests then
		self.DebugService:SendMessage(player, "🎉 Все проверки пройдены!")
	else
		self.DebugService:SendMessage(
			player,
			string.format("⚠️ Пройдено %d/%d проверок", passedTests, #tests)
		)
	end
end

-- Сброс статистики валидации
function ValidationCommands:ResetValidationStats(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local ValidationService = ServiceManager:GetService("ValidationService")

	if not ValidationService then
		self.DebugService:SendMessage(player, "❌ ValidationService недоступен!")
		return
	end

	ValidationService:ResetStatistics()
	self.DebugService:SendMessage(player, "✅ Статистика валидации сброшена!")
end

-- Режим отладки валидации
function ValidationCommands:SetValidationDebugMode(player, mode)
	local ServiceManager = self.DebugService:GetServiceManager()
	local ValidationService = ServiceManager:GetService("ValidationService")

	if not ValidationService then
		self.DebugService:SendMessage(player, "❌ ValidationService недоступен!")
		return
	end

	local currentSettings = ValidationService:GetSettings()
	local newMode = nil

	if mode == "on" then
		newMode = true
	elseif mode == "off" then
		newMode = false
	else -- toggle
		newMode = not currentSettings.LogFailedValidations
	end

	ValidationService:SetDevelopmentMode(newMode)

	local statusText = newMode and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"
	self.DebugService:SendMessage(
		player,
		string.format("🔧 Режим отладки валидации: %s", statusText)
	)

	if newMode then
		self.DebugService:SendMessage(
			player,
			"Теперь все ошибки валидации будут детально логироваться"
		)
	else
		self.DebugService:SendMessage(player, "Детальное логирование отключено")
	end
end

-- Генерация случайных данных игрока для тестирования
function ValidationCommands:GenerateRandomPlayerData()
	return {
		Level = math.random(1, 100),
		Experience = math.random(0, 10000),
		Attributes = {
			Strength = math.random(10, 100),
			Dexterity = math.random(10, 100),
			Intelligence = math.random(10, 100),
			Constitution = math.random(10, 100),
			Focus = math.random(10, 100),
		},
		Currency = { Gold = math.random(0, 100000) },
		Statistics = {
			TotalPlayTime = math.random(0, 86400),
			MobsKilled = math.random(0, 1000),
			QuestsCompleted = math.random(0, 100),
			ItemsCrafted = math.random(0, 500),
			Deaths = math.random(0, 50),
			DamageDealt = math.random(0, 50000),
			DamageTaken = math.random(0, 30000),
			DistanceTraveled = math.random(0, 100000),
		},
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
		Inventory = {},
		WeaponMastery = {
			Sword = { Level = math.random(1, 20), Experience = math.random(0, 1000) },
			Axe = { Level = math.random(1, 20), Experience = math.random(0, 1000) },
			Bow = { Level = math.random(1, 20), Experience = math.random(0, 1000) },
			Staff = { Level = math.random(1, 20), Experience = math.random(0, 1000) },
			Spear = { Level = math.random(1, 20), Experience = math.random(0, 1000) },
		},
		Settings = {
			MusicVolume = math.random() * 1.0,
			SFXVolume = math.random() * 1.0,
			ShowDamageNumbers = math.random() > 0.5,
			AutoPickupItems = math.random() > 0.5,
			ChatFilter = math.random() > 0.5,
			ShowPlayerNames = math.random() > 0.5,
		},
		AttributePoints = math.random(0, 50),
		Health = math.random(50, 200),
		Mana = math.random(20, 100),
		Stamina = math.random(50, 150),
		MaxHealth = math.random(100, 300),
		MaxMana = math.random(50, 150),
		MaxStamina = math.random(100, 200),
		LastLogin = os.time(),
	}
end

return ValidationCommands
