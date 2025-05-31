-- src/client/controllers/CameraController.lua
-- Контроллер камеры в стиле New World

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local BaseController = require(ReplicatedStorage.Shared.BaseController)
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local CameraController = setmetatable({}, { __index = BaseController })
CameraController.__index = CameraController

function CameraController.new()
	local self = setmetatable(BaseController.new("CameraController"), CameraController)

	self.LocalPlayer = Players.LocalPlayer
	self.Camera = workspace.CurrentCamera
	self.Mouse = self.LocalPlayer:GetMouse()

	-- Настройки камеры
	self.Settings = {
		-- Расстояние от персонажа
		DefaultDistance = 8,
		MinDistance = 2,
		MaxDistance = 20,
		CurrentDistance = 8,

		-- Углы камеры
		MinVerticalAngle = math.rad(-80), -- -80 градусов (вверх)
		MaxVerticalAngle = math.rad(60), -- 60 градусов (вниз)

		-- Чувствительность мыши
		MouseSensitivity = 0.003,
		ScrollSensitivity = 1.5,

		-- Плавность движения
		CameraSmoothness = 8, -- Чем больше, тем плавнее
		ZoomSmoothness = 12,

		-- Прицеливание
		AimDistance = 3,
		AimFieldOfView = 50,
		DefaultFieldOfView = 70,
		AimSmoothness = 10,

		-- Смещения камеры
		ShoulderOffset = Vector3.new(1.5, 0, 0), -- Смещение через плечо
		CenterOffset = Vector3.new(0, 0, 0), -- Центрированная камера

		-- Столкновения
		EnableCollisionDetection = true,
		CollisionBuffer = 0.5,
	}

	-- Состояние камеры
	self.State = {
		-- Углы поворота
		HorizontalAngle = 0,
		VerticalAngle = 0,

		-- Целевые значения для плавного движения
		TargetDistance = self.Settings.DefaultDistance,
		TargetHorizontalAngle = 0,
		TargetVerticalAngle = 0,
		TargetFieldOfView = self.Settings.DefaultFieldOfView,
		TargetOffset = self.Settings.CenterOffset,

		-- Режимы
		IsAiming = false,
		IsOverShoulder = false,
		IsCameraLocked = false,

		-- Последняя позиция персонажа
		LastCharacterPosition = Vector3.new(0, 0, 0),

		-- Подключения событий
		InputConnections = {},
		RenderConnection = nil,
	}

	-- UI элементы
	self.CrosshairEnabled = true
	self.CrosshairGui = nil

	return self
end

function CameraController:OnInitialize()
	print("[CAMERA CONTROLLER] Initializing New World camera system...")

	-- Устанавливаем тип камеры
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Camera.FieldOfView = self.Settings.DefaultFieldOfView

	-- Создаем прицел
	self:CreateCrosshair()

	-- Настраиваем управление
	self:SetupInput()

	-- Ждем появления персонажа
	self:WaitForCharacter()
end

function CameraController:OnStart()
	print("[CAMERA CONTROLLER] Camera system ready!")

	-- Запускаем основной цикл камеры
	self:StartCameraLoop()
end

-- Ожидание появления персонажа
function CameraController:WaitForCharacter()
	local function onCharacterAdded(character)
		self:SetupCharacter(character)
	end

	if self.LocalPlayer.Character then
		onCharacterAdded(self.LocalPlayer.Character)
	end

	self:ConnectEvent(self.LocalPlayer.CharacterAdded, onCharacterAdded)
end

-- Настройка персонажа
function CameraController:SetupCharacter(character)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoidRootPart then
		warn("[CAMERA CONTROLLER] HumanoidRootPart not found!")
		return
	end

	-- Инициализируем позицию камеры
	self.State.LastCharacterPosition = humanoidRootPart.Position

	-- Устанавливаем начальные углы на основе направления персонажа
	local lookDirection = humanoidRootPart.CFrame.LookVector
	self.State.HorizontalAngle = math.atan2(-lookDirection.X, -lookDirection.Z)
	self.State.TargetHorizontalAngle = self.State.HorizontalAngle

	print("[CAMERA CONTROLLER] Character setup complete!")
end

-- Настройка управления
function CameraController:SetupInput()
	-- Управление мышью
	self.State.InputConnections.MouseMove = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:HandleMouseMovement(input.Delta)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			self:HandleMouseWheel(input.Position.Z)
		end
	end)

	-- Клавиши управления
	self.State.InputConnections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Правая кнопка мыши - прицеливание
			self:StartAiming()
		elseif input.KeyCode == Enum.KeyCode.V then
			-- V - переключение вида через плечо
			self:ToggleShoulderView()
		elseif input.KeyCode == Enum.KeyCode.C then
			-- C - переключение режима камеры
			self:ToggleCameraMode()
		end
	end)

	self.State.InputConnections.InputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Отпустили правую кнопку мыши
			self:StopAiming()
		end
	end)

	-- Контекстные действия
	ContextActionService:BindAction("CameraToggle", function(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then
			self:ToggleCameraLock()
		end
	end, false, Enum.KeyCode.LeftAlt)

	print("[CAMERA CONTROLLER] Input setup complete!")
end

-- Обработка движения мыши
function CameraController:HandleMouseMovement(delta)
	if self.State.IsCameraLocked then
		return
	end

	-- Применяем чувствительность
	local horizontalDelta = -delta.X * self.Settings.MouseSensitivity
	local verticalDelta = -delta.Y * self.Settings.MouseSensitivity

	-- Обновляем целевые углы
	self.State.TargetHorizontalAngle = self.State.TargetHorizontalAngle + horizontalDelta
	self.State.TargetVerticalAngle = math.clamp(
		self.State.TargetVerticalAngle + verticalDelta,
		self.Settings.MinVerticalAngle,
		self.Settings.MaxVerticalAngle
	)
end

-- Обработка колесика мыши
function CameraController:HandleMouseWheel(wheelDelta)
	local zoomDelta = -wheelDelta * self.Settings.ScrollSensitivity

	self.State.TargetDistance =
		math.clamp(self.State.TargetDistance + zoomDelta, self.Settings.MinDistance, self.Settings.MaxDistance)
end

-- Начать прицеливание
function CameraController:StartAiming()
	if self.State.IsAiming then
		return
	end

	self.State.IsAiming = true
	self.State.TargetDistance = self.Settings.AimDistance
	self.State.TargetFieldOfView = self.Settings.AimFieldOfView
	self.State.TargetOffset = self.Settings.ShoulderOffset

	-- Показываем прицел
	if self.CrosshairGui then
		self.CrosshairGui.Enabled = true
	end

	print("[CAMERA CONTROLLER] Aiming started")
end

-- Закончить прицеливание
function CameraController:StopAiming()
	if not self.State.IsAiming then
		return
	end

	self.State.IsAiming = false
	self.State.TargetDistance = self.Settings.DefaultDistance
	self.State.TargetFieldOfView = self.Settings.DefaultFieldOfView

	if not self.State.IsOverShoulder then
		self.State.TargetOffset = self.Settings.CenterOffset
	end

	-- Скрываем прицел
	if self.CrosshairGui then
		self.CrosshairGui.Enabled = false
	end

	print("[CAMERA CONTROLLER] Aiming stopped")
end

-- Переключить вид через плечо
function CameraController:ToggleShoulderView()
	self.State.IsOverShoulder = not self.State.IsOverShoulder

	if self.State.IsOverShoulder then
		self.State.TargetOffset = self.Settings.ShoulderOffset
		print("[CAMERA CONTROLLER] Shoulder view enabled")
	else
		if not self.State.IsAiming then
			self.State.TargetOffset = self.Settings.CenterOffset
		end
		print("[CAMERA CONTROLLER] Shoulder view disabled")
	end
end

-- Переключить режим камеры
function CameraController:ToggleCameraMode()
	-- Можно добавить разные режимы камеры
	local modes = { "Normal", "Close", "Far" }
	-- Пока просто сбрасываем к дефолтным настройкам
	self:ResetCamera()
end

-- Сбросить камеру к дефолтным настройкам
function CameraController:ResetCamera()
	self.State.TargetDistance = self.Settings.DefaultDistance
	self.State.TargetFieldOfView = self.Settings.DefaultFieldOfView
	self.State.TargetOffset = self.Settings.CenterOffset
	self.State.IsOverShoulder = false
	self.State.IsAiming = false

	print("[CAMERA CONTROLLER] Camera reset to defaults")
end

-- Переключить блокировку камеры
function CameraController:ToggleCameraLock()
	self.State.IsCameraLocked = not self.State.IsCameraLocked

	if self.State.IsCameraLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		print("[CAMERA CONTROLLER] Camera unlocked")
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		print("[CAMERA CONTROLLER] Camera locked")
	end
end

-- Запуск основного цикла камеры
function CameraController:StartCameraLoop()
	self.State.RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		self:UpdateCamera(deltaTime)
	end)
end

-- Обновление камеры каждый кадр
function CameraController:UpdateCamera(deltaTime)
	local character = self.LocalPlayer.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	-- Плавно интерполируем к целевым значениям
	local smoothness = self.Settings.CameraSmoothness * deltaTime
	local zoomSmoothness = self.Settings.ZoomSmoothness * deltaTime
	local aimSmoothness = self.Settings.AimSmoothness * deltaTime

	-- Обновляем углы
	self.State.HorizontalAngle =
		self:LerpAngle(self.State.HorizontalAngle, self.State.TargetHorizontalAngle, smoothness)

	self.State.VerticalAngle = self:LerpAngle(self.State.VerticalAngle, self.State.TargetVerticalAngle, smoothness)

	-- Обновляем расстояние
	self.Settings.CurrentDistance = self:Lerp(self.Settings.CurrentDistance, self.State.TargetDistance, zoomSmoothness)

	-- Обновляем поле зрения
	self.Camera.FieldOfView = self:Lerp(self.Camera.FieldOfView, self.State.TargetFieldOfView, aimSmoothness)

	-- Рассчитываем позицию камеры
	local cameraPosition, cameraLookAt = self:CalculateCameraPosition(humanoidRootPart)

	-- Проверяем столкновения
	if self.Settings.EnableCollisionDetection then
		cameraPosition = self:HandleCameraCollision(humanoidRootPart.Position, cameraPosition)
	end

	-- Применяем позицию и поворот камеры
	self.Camera.CFrame = CFrame.lookAt(cameraPosition, cameraLookAt)

	-- Обновляем позицию для следующего кадра
	self.State.LastCharacterPosition = humanoidRootPart.Position
end

-- Расчет позиции камеры
function CameraController:CalculateCameraPosition(humanoidRootPart)
	local characterPosition = humanoidRootPart.Position
	local characterCFrame = humanoidRootPart.CFrame

	-- Создаем матрицу поворота для камеры
	local horizontalCFrame = CFrame.Angles(0, self.State.HorizontalAngle, 0)
	local verticalCFrame = CFrame.Angles(self.State.VerticalAngle, 0, 0)
	local rotationCFrame = horizontalCFrame * verticalCFrame

	-- Базовое смещение камеры назад
	local baseOffset = Vector3.new(0, 0, self.Settings.CurrentDistance)

	-- Применяем смещение через плечо или центрированное
	local currentOffset = self:LerpVector3(
		Vector3.new(0, 0, 0),
		self.State.TargetOffset,
		self.Settings.AimSmoothness * RunService.RenderStepped:Wait()
	)

	-- Высота камеры (немного выше персонажа)
	local heightOffset = Vector3.new(0, 2, 0)

	-- Финальная позиция камеры
	local cameraOffset = rotationCFrame:VectorToWorldSpace(baseOffset + currentOffset)
	local cameraPosition = characterPosition + heightOffset + cameraOffset

	-- Точка, на которую смотрит камера
	local lookAtPosition = characterPosition + heightOffset + characterCFrame:VectorToWorldSpace(currentOffset)

	return cameraPosition, lookAtPosition
end

-- Обработка столкновений камеры
function CameraController:HandleCameraCollision(characterPosition, desiredCameraPosition)
	local direction = (desiredCameraPosition - characterPosition).Unit
	local distance = (desiredCameraPosition - characterPosition).Magnitude

	-- Создаем рейкаст от персонажа к желаемой позиции камеры
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { self.LocalPlayer.Character }

	local raycastResult = workspace:Raycast(characterPosition, direction * distance, raycastParams)

	if raycastResult then
		-- Есть препятствие, сдвигаем камеру ближе
		local collisionDistance = raycastResult.Distance - self.Settings.CollisionBuffer
		return characterPosition + direction * math.max(collisionDistance, self.Settings.MinDistance)
	end

	return desiredCameraPosition
end

-- Создание прицела
function CameraController:CreateCrosshair()
	local playerGui = self.LocalPlayer:WaitForChild("PlayerGui")

	-- Создаем ScreenGui для прицела
	local crosshairGui = Instance.new("ScreenGui")
	crosshairGui.Name = "CrosshairGui"
	crosshairGui.Enabled = false
	crosshairGui.Parent = playerGui

	-- Основной фрейм прицела
	local crosshairFrame = Instance.new("Frame")
	crosshairFrame.Name = "CrosshairFrame"
	crosshairFrame.Size = UDim2.new(0, 40, 0, 40)
	crosshairFrame.Position = UDim2.new(0.5, -20, 0.5, -20)
	crosshairFrame.BackgroundTransparency = 1
	crosshairFrame.Parent = crosshairGui

	-- Создаем линии прицела
	local lineProps = {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		BackgroundTransparency = 0.2,
	}

	-- Горизонтальная линия
	local horizontalLine = Instance.new("Frame")
	for prop, value in pairs(lineProps) do
		horizontalLine[prop] = value
	end
	horizontalLine.Size = UDim2.new(0, 20, 0, 2)
	horizontalLine.Position = UDim2.new(0.5, -10, 0.5, -1)
	horizontalLine.Parent = crosshairFrame

	-- Вертикальная линия
	local verticalLine = Instance.new("Frame")
	for prop, value in pairs(lineProps) do
		verticalLine[prop] = value
	end
	verticalLine.Size = UDim2.new(0, 2, 0, 20)
	verticalLine.Position = UDim2.new(0.5, -1, 0.5, -10)
	verticalLine.Parent = crosshairFrame

	-- Центральная точка
	local centerDot = Instance.new("Frame")
	centerDot.Size = UDim2.new(0, 2, 0, 2)
	centerDot.Position = UDim2.new(0.5, -1, 0.5, -1)
	centerDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	centerDot.BorderSizePixel = 0
	centerDot.Parent = crosshairFrame

	-- Добавляем скругленные углы
	for _, element in pairs({ horizontalLine, verticalLine, centerDot }) do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 1)
		corner.Parent = element
	end

	self.CrosshairGui = crosshairGui
	print("[CAMERA CONTROLLER] Crosshair created!")
end

-- Утилиты для интерполяции
function CameraController:Lerp(a, b, t)
	return a + (b - a) * math.min(t, 1)
end

function CameraController:LerpVector3(a, b, t)
	return a:Lerp(b, math.min(t, 1))
end

function CameraController:LerpAngle(a, b, t)
	local difference = b - a
	-- Нормализуем разность углов
	while difference > math.pi do
		difference = difference - 2 * math.pi
	end
	while difference < -math.pi do
		difference = difference + 2 * math.pi
	end
	return a + difference * math.min(t, 1)
end

-- Получить текущую информацию о камере
function CameraController:GetCameraInfo()
	return {
		Distance = self.Settings.CurrentDistance,
		HorizontalAngle = math.deg(self.State.HorizontalAngle),
		VerticalAngle = math.deg(self.State.VerticalAngle),
		FieldOfView = self.Camera.FieldOfView,
		IsAiming = self.State.IsAiming,
		IsOverShoulder = self.State.IsOverShoulder,
		IsLocked = self.State.IsCameraLocked,
	}
end

-- Установить настройки камеры
function CameraController:UpdateSettings(newSettings)
	for key, value in pairs(newSettings) do
		if self.Settings[key] ~= nil then
			self.Settings[key] = value
			print("[CAMERA CONTROLLER] Updated setting: " .. key .. " = " .. tostring(value))
		end
	end
end

-- Включить/выключить прицел
function CameraController:SetCrosshairEnabled(enabled)
	self.CrosshairEnabled = enabled
	if self.CrosshairGui then
		self.CrosshairGui.Enabled = enabled and self.State.IsAiming
	end
end

function CameraController:OnCleanup()
	-- Отключаем все соединения
	for _, connection in pairs(self.State.InputConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	if self.State.RenderConnection then
		self.State.RenderConnection:Disconnect()
	end

	-- Убираем контекстные действия
	ContextActionService:UnbindAction("CameraToggle")

	-- Восстанавливаем стандартную камеру
	self.Camera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	-- Удаляем UI
	if self.CrosshairGui then
		self.CrosshairGui:Destroy()
	end

	print("[CAMERA CONTROLLER] Camera controller cleaned up")
end

return CameraController
