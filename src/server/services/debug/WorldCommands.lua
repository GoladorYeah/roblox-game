-- src/server/services/debug/WorldCommands.lua
-- Команды для управления миром и временем

local WorldCommands = {}
WorldCommands.__index = WorldCommands

function WorldCommands.new(debugService)
	local self = setmetatable({}, WorldCommands)
	self.DebugService = debugService
	return self
end

function WorldCommands:RegisterCommands()
	local debugService = self.DebugService

	debugService:RegisterCommand("time", "Показать текущее время мира", function(player, _)
		self:ShowWorldTime(player)
	end)

	debugService:RegisterCommand(
		"settime",
		"Установить время: /settime [часы]",
		function(player, args)
			local hours = tonumber(args[1])
			if hours then
				self:SetWorldTime(player, hours)
			else
				debugService:SendMessage(player, "❌ Укажите час (0-24): /settime 12")
			end
		end
	)

	debugService:RegisterCommand(
		"timespeed",
		"Установить скорость времени: /timespeed [множитель]",
		function(player, args)
			local speed = tonumber(args[1])
			if speed then
				self:SetTimeSpeed(player, speed)
			else
				debugService:SendMessage(player, "❌ Укажите скорость (0-100): /timespeed 2")
			end
		end
	)

	debugService:RegisterCommand("pausetime", "Поставить время на паузу", function(player, _)
		self:PauseTime(player)
	end)

	debugService:RegisterCommand("resumetime", "Возобновить время", function(player, _)
		self:ResumeTime(player)
	end)

	debugService:RegisterCommand("day", "Установить день (12:00)", function(player, _)
		self:SetWorldTime(player, 12)
	end)

	debugService:RegisterCommand("night", "Установить ночь (00:00)", function(player, _)
		self:SetWorldTime(player, 0)
	end)

	debugService:RegisterCommand("dawn", "Установить рассвет (06:30)", function(player, _)
		self:SetWorldTime(player, 6.5)
	end)

	debugService:RegisterCommand("dusk", "Установить закат (19:30)", function(player, _)
		self:SetWorldTime(player, 19.5)
	end)

	debugService:RegisterCommand("worldinfo", "Подробная информация о мире", function(player, _)
		self:ShowWorldInfo(player)
	end)

	debugService:RegisterCommand(
		"fasttime",
		"Быстрое время: /fasttime [скорость]",
		function(player, args)
			local speed = tonumber(args[1]) or 10
			self:SetTimeSpeed(player, speed)
			debugService:SendMessage(player, string.format("⚡ Время ускорено в %dx раз", speed))
		end
	)

	debugService:RegisterCommand(
		"normaltime",
		"Нормальная скорость времени",
		function(player, _)
			self:SetTimeSpeed(player, 1)
			debugService:SendMessage(
				player,
				"🕐 Время восстановлено к нормальной скорости"
			)
		end
	)

	debugService:RegisterCommand("saveworld", "Сохранить состояние мира", function(player, _)
		self:SaveWorldState(player)
	end)

	debugService:RegisterCommand("loadworld", "Загрузить состояние мира", function(player, _)
		self:LoadWorldState(player)
	end)
end

-- Показать текущее время мира
function WorldCommands:ShowWorldTime(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	local timeInfo = WorldService:GetTimeInfo()
	local formattedTime = WorldService:GetFormattedTime()

	self.DebugService:SendMessage(player, "=== ВРЕМЯ МИРА ===")
	self.DebugService:SendMessage(player, string.format("🕐 Время: %s", formattedTime))
	self.DebugService:SendMessage(player, string.format("🌅 Период: %s", timeInfo.TimeOfDay))

	local dayNightStatus = timeInfo.IsDay and "День" or "Ночь"
	self.DebugService:SendMessage(player, string.format("☀️ День/Ночь: %s", dayNightStatus))

	local speedStatus = timeInfo.IsPaused and "⏸️ ПАУЗА" or string.format("⚡ %.1fx", timeInfo.TimeSpeed)
	self.DebugService:SendMessage(player, string.format("⏱️ Скорость: %s", speedStatus))

	if timeInfo.TransitionFactor then
		self.DebugService:SendMessage(
			player,
			string.format("🌄 Переход: %.1f%%", timeInfo.TransitionFactor * 100)
		)
	end
end

-- Установить время мира
function WorldCommands:SetWorldTime(player, hours)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	if hours < 0 or hours > 24 then
		self.DebugService:SendMessage(player, "❌ Время должно быть от 0 до 24 часов")
		return
	end

	WorldService:SetTime(hours)
	local newTimeInfo = WorldService:GetTimeInfo()
	local formattedTime = WorldService:GetFormattedTime()

	self.DebugService:SendMessage(
		player,
		string.format("✅ Время установлено: %s (%s)", formattedTime, newTimeInfo.TimeOfDay)
	)

	-- Уведомляем всех игроков
	local RemoteService = ServiceManager:GetService("RemoteService")
	if RemoteService then
		RemoteService:BroadcastSystemMessage(
			string.format("🕐 Время изменено администратором: %s", formattedTime),
			"INFO"
		)
	end
end

-- Установить скорость времени
function WorldCommands:SetTimeSpeed(player, speed)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	if speed < 0 or speed > 100 then
		self.DebugService:SendMessage(player, "❌ Скорость должна быть от 0 до 100")
		return
	end

	WorldService:SetTimeSpeed(speed)

	if speed == 0 then
		self.DebugService:SendMessage(player, "⏸️ Время остановлено")
	elseif speed == 1 then
		self.DebugService:SendMessage(player, "🕐 Время идет с нормальной скоростью")
	else
		self.DebugService:SendMessage(player, string.format("⚡ Время ускорено в %.1fx раз", speed))
	end
end

-- Поставить время на паузу
function WorldCommands:PauseTime(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	WorldService:PauseTime()
	self.DebugService:SendMessage(player, "⏸️ Время поставлено на паузу")

	-- Уведомляем всех игроков
	local RemoteService = ServiceManager:GetService("RemoteService")
	if RemoteService then
		RemoteService:BroadcastSystemMessage(
			"⏸️ Время остановлено администратором",
			"WARNING"
		)
	end
end

-- Возобновить время
function WorldCommands:ResumeTime(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	WorldService:ResumeTime()
	self.DebugService:SendMessage(player, "▶️ Время возобновлено")

	-- Уведомляем всех игроков
	local RemoteService = ServiceManager:GetService("RemoteService")
	if RemoteService then
		RemoteService:BroadcastSystemMessage(
			"▶️ Время возобновлено администратором",
			"INFO"
		)
	end
end

-- Показать подробную информацию о мире
function WorldCommands:ShowWorldInfo(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	local timeInfo = WorldService:GetTimeInfo()
	local formattedTime = WorldService:GetFormattedTime()

	self.DebugService:SendMessage(player, "=== ИНФОРМАЦИЯ О МИРЕ ===")

	-- Основная информация
	self.DebugService:SendMessage(player, "--- ВРЕМЯ ---")
	self.DebugService:SendMessage(player, string.format("Текущее время: %s", formattedTime))
	self.DebugService:SendMessage(
		player,
		string.format("Точное время: %.2f часов", timeInfo.CurrentTime)
	)
	self.DebugService:SendMessage(player, string.format("Период суток: %s", timeInfo.TimeOfDay))

	-- Состояние времени
	self.DebugService:SendMessage(player, "--- СОСТОЯНИЕ ---")
	local statusIcon = timeInfo.IsPaused and "⏸️" or "▶️"
	local statusText = timeInfo.IsPaused and "Пауза" or "Активно"
	self.DebugService:SendMessage(player, string.format("%s Состояние: %s", statusIcon, statusText))
	self.DebugService:SendMessage(player, string.format("⚡ Скорость: %.1fx", timeInfo.TimeSpeed))

	-- День/Ночь
	self.DebugService:SendMessage(player, "--- ДЕНЬ/НОЧЬ ---")
	local dayNightIcon = timeInfo.IsDay and "☀️" or "🌙"
	local dayNightText = timeInfo.IsDay and "День" or "Ночь"
	self.DebugService:SendMessage(player, string.format("%s Тип: %s", dayNightIcon, dayNightText))

	if timeInfo.TransitionFactor then
		local transitionText = ""
		if timeInfo.TimeOfDay == "Dawn" then
			transitionText = "🌅 Рассвет"
		elseif timeInfo.TimeOfDay == "Dusk" then
			transitionText = "🌆 Закат"
		else
			transitionText = "🌄 Переход"
		end
		self.DebugService:SendMessage(
			player,
			string.format("%s: %.1f%%", transitionText, timeInfo.TransitionFactor * 100)
		)
	end

	-- Настройки мира
	self.DebugService:SendMessage(player, "--- НАСТРОЙКИ ---")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Constants = require(ReplicatedStorage.Shared.constants.Constants)

	self.DebugService:SendMessage(
		player,
		string.format("Длительность дня: %d сек", Constants.WORLD.DAY_LENGTH)
	)
	self.DebugService:SendMessage(
		player,
		string.format("Длительность ночи: %d сек", Constants.WORLD.NIGHT_LENGTH)
	)

	-- Освещение
	local Lighting = game:GetService("Lighting")
	self.DebugService:SendMessage(player, "--- ОСВЕЩЕНИЕ ---")
	self.DebugService:SendMessage(player, string.format("Яркость: %.1f", Lighting.Brightness))
	self.DebugService:SendMessage(player, string.format("Время Lighting: %.1f", Lighting.ClockTime))

	local atmosphere = Lighting:FindFirstChild("Atmosphere")
	if atmosphere then
		self.DebugService:SendMessage(
			player,
			string.format("Плотность атмосферы: %.1f", atmosphere.Density)
		)
	end

	-- Быстрые команды
	self.DebugService:SendMessage(player, "--- БЫСТРЫЕ КОМАНДЫ ---")
	self.DebugService:SendMessage(player, "/day - день, /night - ночь")
	self.DebugService:SendMessage(player, "/dawn - рассвет, /dusk - закат")
	self.DebugService:SendMessage(player, "/fasttime 10 - ускорить время")
	self.DebugService:SendMessage(player, "/pausetime - пауза времени")
	self.DebugService:SendMessage(player, "/saveworld - сохранить мир")
end

-- Сохранить состояние мира
function WorldCommands:SaveWorldState(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	WorldService:SaveWorldState()
	self.DebugService:SendMessage(player, "💾 Состояние мира сохранено!")
end

-- Загрузить состояние мира
function WorldCommands:LoadWorldState(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local WorldService = ServiceManager:GetService("WorldService")

	if not WorldService then
		self.DebugService:SendMessage(player, "❌ WorldService недоступен!")
		return
	end

	WorldService:LoadWorldState()
	self.DebugService:SendMessage(player, "📁 Состояние мира загружено!")

	-- Показываем новое состояние
	local timeInfo = WorldService:GetTimeInfo()
	local formattedTime = WorldService:GetFormattedTime()
	self.DebugService:SendMessage(
		player,
		string.format("🕐 Текущее время: %s (%s)", formattedTime, timeInfo.TimeOfDay)
	)
end

return WorldCommands
