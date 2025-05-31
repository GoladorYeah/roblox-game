-- src/server/services/WorldService.lua
-- Сервис для управления миром: день/ночь, погода, освещение

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(ReplicatedStorage.Shared.BaseService)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

-- Константы времени суток (числовые)
local TIME_DAWN = 1
local TIME_DAY = 2
local TIME_DUSK = 3
local TIME_NIGHT = 4

-- Названия для вывода
local TIME_NAMES = {
	[TIME_DAWN] = "Dawn",
	[TIME_DAY] = "Day",
	[TIME_DUSK] = "Dusk",
	[TIME_NIGHT] = "Night",
}

local WorldService = setmetatable({}, { __index = BaseService })
WorldService.__index = WorldService

function WorldService.new()
	local self = setmetatable(BaseService.new("WorldService"), WorldService)

	-- Состояние мира
	self.CurrentTime = 12 -- Начинаем с полудня (будет загружено из DataStoreService)
	self.TimeSpeed = 1 -- Скорость времени (1 = реальное время)
	self.IsTimePaused = false

	-- Система сохранения состояния мира
	self.WorldDataStore = nil
	self.LastSaveTime = 0
	self.SaveInterval = 60 -- Сохраняем каждую минуту

	-- Настройки дня и ночи
	self.DaySettings = {
		ClockTime = 12,
		Brightness = 2,
		Ambient = Color3.fromRGB(51, 51, 76),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		Density = 0.3,
		Offset = 0.25,
		AtmosphereColor = Color3.fromRGB(204, 204, 230),
	}

	self.NightSettings = {
		ClockTime = 0,
		Brightness = 0.5,
		Ambient = Color3.fromRGB(25, 25, 51),
		ColorShift_Top = Color3.fromRGB(25, 25, 50),
		Density = 0.5,
		Offset = 0.1,
		AtmosphereColor = Color3.fromRGB(102, 102, 153),
	}

	-- События мира
	self.TimeChanged = Instance.new("BindableEvent")
	self.DayStarted = Instance.new("BindableEvent")
	self.NightStarted = Instance.new("BindableEvent")

	-- Последние события - используем числовую константу
	self.LastTimeOfDay = TIME_DAY

	return self
end

function WorldService:OnInitialize()
	print("[WORLD SERVICE] Initializing world systems...")

	-- Инициализируем DataStore для сохранения состояния мира
	self:InitializeDataStore()

	-- Загружаем сохраненное состояние мира
	self:LoadWorldState()

	-- Настраиваем начальное состояние мира
	self:SetupInitialWorld()

	-- Подключаем обновление времени
	self:ConnectEvent(RunService.Heartbeat, function()
		self:UpdateTime()
	end)

	-- Автосохранение состояния мира
	spawn(function()
		while true do
			wait(self.SaveInterval)
			self:SaveWorldState()
		end
	end)

	print("[WORLD SERVICE] World initialized with day/night cycle")
end

function WorldService:OnStart()
	print("[WORLD SERVICE] World systems started!")
	print(
		string.format(
			"[WORLD SERVICE] Day length: %d seconds, Night length: %d seconds",
			Constants.WORLD.DAY_LENGTH,
			Constants.WORLD.NIGHT_LENGTH
		)
	)
end

-- Настройка начального состояния мира
function WorldService:SetupInitialWorld()
	-- Устанавливаем базовые настройки освещения
	Lighting.ClockTime = self.CurrentTime
	Lighting.Brightness = self.DaySettings.Brightness
	Lighting.Ambient = self.DaySettings.Ambient
	Lighting.ColorShift_Top = self.DaySettings.ColorShift_Top

	-- Настраиваем атмосферу если есть
	local atmosphere = Lighting:FindFirstChild("Atmosphere")
	if atmosphere then
		atmosphere.Density = self.DaySettings.Density
		atmosphere.Offset = self.DaySettings.Offset
		atmosphere.Color = self.DaySettings.AtmosphereColor
	end

	print("[WORLD SERVICE] Initial world state: Day time")
end

-- Обновление времени
function WorldService:UpdateTime()
	if self.IsTimePaused then
		return
	end

	-- Рассчитываем скорость изменения времени
	local deltaTime = RunService.Heartbeat:Wait()
	local timeIncrement = (deltaTime * self.TimeSpeed) / (Constants.WORLD.DAY_LENGTH / 24)

	-- Обновляем текущее время
	self.CurrentTime = self.CurrentTime + timeIncrement

	-- Обрабатываем переход через 24 часа
	if self.CurrentTime >= 24 then
		self.CurrentTime = self.CurrentTime - 24
	end

	-- Обновляем освещение
	self:UpdateLighting()

	-- Проверяем смену дня/ночи
	self:CheckTimeOfDayChange()

	-- Обновляем время в Lighting
	Lighting.ClockTime = self.CurrentTime
end

-- Обновление освещения на основе времени
function WorldService:UpdateLighting()
	local timeOfDay = self:GetTimeOfDay()
	local transitionFactor = self:GetTransitionFactor()

	if timeOfDay == TIME_DAY then
		-- Дневное освещение
		Lighting.Brightness =
			self:LerpValue(self.NightSettings.Brightness, self.DaySettings.Brightness, transitionFactor)
		Lighting.Ambient = self:LerpColor(self.NightSettings.Ambient, self.DaySettings.Ambient, transitionFactor)
		Lighting.ColorShift_Top =
			self:LerpColor(self.NightSettings.ColorShift_Top, self.DaySettings.ColorShift_Top, transitionFactor)
	elseif timeOfDay == TIME_NIGHT then
		-- Ночное освещение
		Lighting.Brightness =
			self:LerpValue(self.DaySettings.Brightness, self.NightSettings.Brightness, transitionFactor)
		Lighting.Ambient = self:LerpColor(self.DaySettings.Ambient, self.NightSettings.Ambient, transitionFactor)
		Lighting.ColorShift_Top =
			self:LerpColor(self.DaySettings.ColorShift_Top, self.NightSettings.ColorShift_Top, transitionFactor)
	else -- Transition periods
		-- Плавные переходы на рассвете и закате
		local isDawn = timeOfDay == TIME_DAWN
		local factor = isDawn and transitionFactor or (1 - transitionFactor)

		Lighting.Brightness = self:LerpValue(self.NightSettings.Brightness, self.DaySettings.Brightness, factor)
		Lighting.Ambient = self:LerpColor(self.NightSettings.Ambient, self.DaySettings.Ambient, factor)
		Lighting.ColorShift_Top =
			self:LerpColor(self.NightSettings.ColorShift_Top, self.DaySettings.ColorShift_Top, factor)
	end

	-- Обновляем атмосферу
	local atmosphere = Lighting:FindFirstChild("Atmosphere")
	if atmosphere then
		if timeOfDay == TIME_DAY then
			atmosphere.Density = self:LerpValue(self.NightSettings.Density, self.DaySettings.Density, transitionFactor)
			atmosphere.Color =
				self:LerpColor(self.NightSettings.AtmosphereColor, self.DaySettings.AtmosphereColor, transitionFactor)
		elseif timeOfDay == TIME_NIGHT then
			atmosphere.Density = self:LerpValue(self.DaySettings.Density, self.NightSettings.Density, transitionFactor)
			atmosphere.Color =
				self:LerpColor(self.DaySettings.AtmosphereColor, self.NightSettings.AtmosphereColor, transitionFactor)
		end
	end
end

-- Определение времени суток
function WorldService:GetTimeOfDay(): number
	if self.CurrentTime >= 6 and self.CurrentTime < 7 then
		return TIME_DAWN
	elseif self.CurrentTime >= 7 and self.CurrentTime < 19 then
		return TIME_DAY
	elseif self.CurrentTime >= 19 and self.CurrentTime < 20 then
		return TIME_DUSK
	else
		return TIME_NIGHT
	end
end

-- Получение фактора перехода (0-1)
function WorldService:GetTransitionFactor()
	local timeOfDay = self:GetTimeOfDay()

	if timeOfDay == TIME_DAWN then
		-- Рассвет: от 6:00 до 7:00
		return (self.CurrentTime - 6) / 1
	elseif timeOfDay == TIME_DAY then
		-- День: полная яркость
		return 1
	elseif timeOfDay == TIME_DUSK then
		-- Закат: от 19:00 до 20:00
		return 1 - ((self.CurrentTime - 19) / 1)
	else
		-- Ночь: полная темнота
		return 0
	end
end

-- Проверка смены дня/ночи
function WorldService:CheckTimeOfDayChange()
	local currentTimeOfDay = self:GetTimeOfDay()

	if currentTimeOfDay ~= self.LastTimeOfDay then
		print(
			string.format(
				"[WORLD SERVICE] Time changed: %s -> %s (%.1f)",
				self.LastTimeOfDay,
				currentTimeOfDay,
				self.CurrentTime
			)
		)

		-- Отправляем событие
		self.TimeChanged:Fire({
			From = self.LastTimeOfDay,
			To = currentTimeOfDay,
			CurrentTime = self.CurrentTime,
		})

		-- Специальные события
		if currentTimeOfDay == TIME_DAY and self.LastTimeOfDay ~= TIME_DAY then
			self.DayStarted:Fire(self.CurrentTime)
			print("[WORLD SERVICE] Day has started!")
		elseif currentTimeOfDay == TIME_NIGHT and self.LastTimeOfDay ~= TIME_NIGHT then
			self.NightStarted:Fire(self.CurrentTime)
			print("[WORLD SERVICE] Night has started!")
		end

		self.LastTimeOfDay = currentTimeOfDay

		-- Уведомляем игроков через RemoteService
		self:NotifyPlayersTimeChange(currentTimeOfDay)
	end
end

-- Уведомление игроков о смене времени
function WorldService:NotifyPlayersTimeChange(timeOfDayNumber: number)
	local ServiceManager = require(script.Parent.Parent.ServiceManager)
	local RemoteService = ServiceManager:GetService("RemoteService")

	if RemoteService and RemoteService:IsReady() then
		local message = ""
		if timeOfDayNumber == TIME_DAY then
			message = "🌅 Dawn breaks! A new day begins."
		elseif timeOfDayNumber == TIME_NIGHT then
			message = "🌙 Night falls across the land."
		elseif timeOfDayNumber == TIME_DAWN then
			message = "🌄 The sun rises in the east."
		elseif timeOfDayNumber == TIME_DUSK then
			message = "🌆 The sun sets in the west."
		end

		if message ~= "" then
			RemoteService:BroadcastSystemMessage(message, "INFO")
		end
	end
end

-- Утилиты для интерполяции
function WorldService:LerpValue(a: number, b: number, t: number): number
	return a + (b - a) * math.max(0, math.min(1, t))
end

function WorldService:LerpColor(a: Color3, b: Color3, t: number): Color3
	t = math.max(0, math.min(1, t))
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

---[[ СОХРАНЕНИЕ СОСТОЯНИЯ МИРА ]]---

-- Инициализация DataStore
function WorldService:InitializeDataStore()
	local DataStoreService = game:GetService("DataStoreService")

	local success, result = pcall(function()
		self.WorldDataStore = DataStoreService:GetDataStore("WorldState")
	end)

	if success then
		print("[WORLD SERVICE] DataStore initialized successfully")
	else
		warn("[WORLD SERVICE] Failed to initialize DataStore: " .. tostring(result))
		warn("[WORLD SERVICE] World state will not be saved between sessions")
	end
end

-- Загрузка состояния мира
function WorldService:LoadWorldState()
	if not self.WorldDataStore then
		print("[WORLD SERVICE] No DataStore available, using default world state")
		return
	end

	local success, savedData = pcall(function()
		return self.WorldDataStore:GetAsync("CurrentWorldState")
	end)

	if success and savedData then
		-- Восстанавливаем состояние мира
		if savedData.CurrentTime then
			self.CurrentTime = math.max(0, math.min(24, savedData.CurrentTime))
		end

		if savedData.TimeSpeed then
			self.TimeSpeed = math.max(0, math.min(100, savedData.TimeSpeed))
		end

		if savedData.IsTimePaused ~= nil then
			self.IsTimePaused = savedData.IsTimePaused
		end

		print(
			string.format(
				"[WORLD SERVICE] Loaded world state: Time=%.1f, Speed=%.1fx, Paused=%s",
				self.CurrentTime,
				self.TimeSpeed,
				tostring(self.IsTimePaused)
			)
		)
	else
		if success then
			print("[WORLD SERVICE] No saved world state found, using defaults")
		else
			warn("[WORLD SERVICE] Failed to load world state: " .. tostring(savedData))
		end
	end
end

-- Сохранение состояния мира
function WorldService:SaveWorldState()
	if not self.WorldDataStore then
		return
	end

	local currentTime = tick()
	if currentTime - self.LastSaveTime < self.SaveInterval then
		return -- Слишком рано для сохранения
	end

	local worldData = {
		CurrentTime = self.CurrentTime,
		TimeSpeed = self.TimeSpeed,
		IsTimePaused = self.IsTimePaused,
		LastSaved = os.time(),
		Version = Constants.VERSION,
	}

	local success, errorMessage = pcall(function()
		self.WorldDataStore:SetAsync("CurrentWorldState", worldData)
	end)

	if success then
		self.LastSaveTime = currentTime
		print(
			string.format("[WORLD SERVICE] World state saved: Time=%.1f, Speed=%.1fx", self.CurrentTime, self.TimeSpeed)
		)
	else
		warn("[WORLD SERVICE] Failed to save world state: " .. tostring(errorMessage))
	end
end

---[[ УПРАВЛЕНИЕ ВРЕМЕНЕМ ]]---

-- Установить время суток
function WorldService:SetTime(hours: number)
	hours = math.max(0, math.min(24, hours))
	self.CurrentTime = hours
	Lighting.ClockTime = hours
	self:UpdateLighting()

	-- Сохраняем изменение немедленно
	self:SaveWorldState()

	print(string.format("[WORLD SERVICE] Time set to %.1f:00", hours))
end

-- Установить скорость времени
function WorldService:SetTimeSpeed(speed: number)
	speed = math.max(0, math.min(100, speed))
	self.TimeSpeed = speed

	-- Сохраняем изменение немедленно
	self:SaveWorldState()

	print(string.format("[WORLD SERVICE] Time speed set to %.1fx", speed))
end

-- Пауза/возобновление времени
function WorldService:PauseTime()
	self.IsTimePaused = true

	-- Сохраняем изменение немедленно
	self:SaveWorldState()

	print("[WORLD SERVICE] Time paused")
end

function WorldService:ResumeTime()
	self.IsTimePaused = false

	-- Сохраняем изменение немедленно
	self:SaveWorldState()

	print("[WORLD SERVICE] Time resumed")
end

-- Переключение паузы
function WorldService:ToggleTimePause()
	if self.IsTimePaused then
		self:ResumeTime()
	else
		self:PauseTime()
	end
end

---[[ ИНФОРМАЦИЯ О МИРЕ ]]---

-- Получить информацию о текущем времени
function WorldService:GetTimeInfo(): {
	CurrentTime: number,
	TimeOfDay: string,
	IsDay: boolean,
	IsNight: boolean,
	TransitionFactor: number,
	IsPaused: boolean,
	TimeSpeed: number,
}
	local timeOfDay = self:GetTimeOfDay()
	local timeOfDayName = TIME_NAMES[timeOfDay]
	return {
		CurrentTime = self.CurrentTime,
		TimeOfDay = timeOfDayName,
		IsDay = (timeOfDay == TIME_DAY or timeOfDay == TIME_DAWN),
		IsNight = (timeOfDay == TIME_NIGHT or timeOfDay == TIME_DUSK),
		TransitionFactor = self:GetTransitionFactor(),
		IsPaused = self.IsTimePaused,
		TimeSpeed = self.TimeSpeed,
	}
end

-- Получить красивое время в формате строки
function WorldService:GetFormattedTime(): string
	local hours = math.floor(self.CurrentTime)
	local minutes = math.floor((self.CurrentTime - hours) * 60)
	return string.format("%02d:%02d", hours, minutes)
end

function WorldService:OnCleanup()
	-- Сохраняем состояние мира перед закрытием
	print("[WORLD SERVICE] Saving world state before shutdown...")
	self:SaveWorldState()

	-- Очищаем события
	if self.TimeChanged then
		self.TimeChanged:Destroy()
	end
	if self.DayStarted then
		self.DayStarted:Destroy()
	end
	if self.NightStarted then
		self.NightStarted:Destroy()
	end

	print("[WORLD SERVICE] World service cleaned up")
end

return WorldService
