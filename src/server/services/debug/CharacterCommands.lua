-- src/server/services/debug/CharacterCommands.lua
-- Команды для управления персонажем и ресурсами

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local CharacterCommands = {}
CharacterCommands.__index = CharacterCommands

function CharacterCommands.new(debugService)
	local self = setmetatable({}, CharacterCommands)
	self.DebugService = debugService
	return self
end

function CharacterCommands:RegisterCommands()
	local debugService = self.DebugService

	debugService:RegisterCommand(
		"damage",
		"Нанести урон: /damage [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 25
			self:DamagePlayer(player, amount)
		end
	)

	debugService:RegisterCommand(
		"heal",
		"Восстановить здоровье: /heal [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 50
			self:HealPlayer(player, amount)
		end
	)

	debugService:RegisterCommand("kill", "Убить персонажа", function(player, _)
		self:KillPlayer(player)
	end)

	debugService:RegisterCommand("respawn", "Принудительный респавн", function(player, _)
		self:RespawnPlayer(player)
	end)

	debugService:RegisterCommand("invul", "Неуязвимость: /invul [секунды]", function(player, args)
		local duration = tonumber(args[1]) or 10
		self:SetInvulnerability(player, duration)
	end)

	debugService:RegisterCommand(
		"regen",
		"Полное восстановление ресурсов",
		function(player, _)
			self:FullRegeneration(player)
		end
	)

	debugService:RegisterCommand(
		"sethealth",
		"Установить здоровье: /sethealth [количество]",
		function(player, args)
			local amount = tonumber(args[1])
			if amount then
				self:SetHealth(player, amount)
			else
				debugService:SendMessage(
					player,
					"❌ Укажите количество здоровья: /sethealth 100"
				)
			end
		end
	)

	debugService:RegisterCommand(
		"setmana",
		"Установить ману: /setmana [количество]",
		function(player, args)
			local amount = tonumber(args[1])
			if amount then
				self:SetMana(player, amount)
			else
				debugService:SendMessage(player, "❌ Укажите количество маны: /setmana 50")
			end
		end
	)

	debugService:RegisterCommand(
		"setstamina",
		"Установить стамину: /setstamina [количество]",
		function(player, args)
			local amount = tonumber(args[1])
			if amount then
				self:SetStamina(player, amount)
			else
				debugService:SendMessage(
					player,
					"❌ Укажите количество стамины: /setstamina 100"
				)
			end
		end
	)

	debugService:RegisterCommand("charinfo", "Информация о персонаже", function(player, _)
		self:ShowCharacterInfo(player)
	end)

	debugService:RegisterCommand(
		"speed",
		"Установить скорость: /speed [значение]",
		function(player, args)
			local speed = tonumber(args[1]) or 16
			self:SetWalkSpeed(player, speed)
		end
	)

	debugService:RegisterCommand(
		"jump",
		"Установить силу прыжка: /jump [значение]",
		function(player, args)
			local jumpPower = tonumber(args[1]) or 50
			self:SetJumpPower(player, jumpPower)
		end
	)

	debugService:RegisterCommand(
		"consumestamina",
		"Потратить стамину: /consumestamina [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 20
			self:ConsumeStamina(player, amount)
		end
	)

	debugService:RegisterCommand(
		"teleport",
		"Телепорт к спавну: /teleport [spawn]",
		function(player, args)
			local spawnName = args[1] or "MAIN"
			self:TeleportToSpawn(player, spawnName)
		end
	)

	debugService:RegisterCommand("resetchar", "Сброс персонажа", function(player, _)
		self:ResetCharacter(player)
	end)
end

-- Нанести урон игроку
function CharacterCommands:DamagePlayer(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	amount = math.max(1, math.min(amount, 10000)) -- Ограничиваем диапазон

	local success = CharacterService:DamagePlayer(player, amount, "Debug", "Admin Command")
	if success then
		self.DebugService:SendMessage(player, string.format("💥 Нанесен урон: %d", amount))
	else
		self.DebugService:SendMessage(player, "❌ Не удалось нанести урон!")
	end
end

-- Лечение игрока
function CharacterCommands:HealPlayer(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	amount = math.max(1, math.min(amount, 10000))

	local success = CharacterService:HealPlayer(player, amount, "Debug Heal")
	if success then
		self.DebugService:SendMessage(
			player,
			string.format("💚 Восстановлено здоровья: %d", amount)
		)
	else
		self.DebugService:SendMessage(player, "❌ Здоровье уже максимальное!")
	end
end

-- Убить игрока
function CharacterCommands:KillPlayer(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	local character = CharacterService:GetPlayerCharacter(player)
	if not character then
		self.DebugService:SendMessage(player, "❌ Персонаж не найден!")
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health > 0 then
		CharacterService:DamagePlayer(player, humanoid.Health, "Debug", "Kill Command")
		self.DebugService:SendMessage(player, "💀 Персонаж убит!")
	else
		self.DebugService:SendMessage(player, "❌ Персонаж уже мертв!")
	end
end

-- Принудительный респавн
function CharacterCommands:RespawnPlayer(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	-- Очищаем таймер респавна если есть
	CharacterService.RespawnTimers[player] = nil

	-- Принудительно респавним
	CharacterService:RespawnPlayer(player)
	self.DebugService:SendMessage(player, "🔄 Принудительный респавн выполнен!")
end

-- Установить неуязвимость
function CharacterCommands:SetInvulnerability(player, duration)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	duration = math.max(1, math.min(duration, 300)) -- Максимум 5 минут

	CharacterService:SetPlayerInvulnerable(player, duration)
	self.DebugService:SendMessage(
		player,
		string.format("🛡️ Неуязвимость активна на %.1f секунд", duration)
	)
end

-- Полное восстановление ресурсов
function CharacterCommands:FullRegeneration(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	CharacterService:RestorePlayerResources(player)
	self.DebugService:SendMessage(player, "✨ Все ресурсы полностью восстановлены!")
end

-- Установить здоровье
function CharacterCommands:SetHealth(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not CharacterService or not PlayerDataService then
		self.DebugService:SendMessage(player, "❌ Сервисы недоступны!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	amount = math.max(0, math.min(amount, data.MaxHealth))

	-- Устанавливаем здоровье напрямую
	data.Health = amount

	local character = CharacterService:GetPlayerCharacter(player)
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = amount
		end
	end

	CharacterService:NotifyResourceChanged(player, "Health", amount, data.MaxHealth)
	self.DebugService:SendMessage(
		player,
		string.format("❤️ Здоровье установлено: %d/%d", amount, data.MaxHealth)
	)
end

-- Установить ману
function CharacterCommands:SetMana(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not PlayerDataService or not CharacterService then
		self.DebugService:SendMessage(player, "❌ Сервисы недоступны!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	amount = math.max(0, math.min(amount, data.MaxMana))
	data.Mana = amount

	CharacterService:NotifyResourceChanged(player, "Mana", amount, data.MaxMana)
	self.DebugService:SendMessage(
		player,
		string.format("💙 Мана установлена: %d/%d", amount, data.MaxMana)
	)
end

-- Установить стамину
function CharacterCommands:SetStamina(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not PlayerDataService or not CharacterService then
		self.DebugService:SendMessage(player, "❌ Сервисы недоступны!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if not data then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	amount = math.max(0, math.min(amount, data.MaxStamina))
	data.Stamina = amount

	CharacterService:NotifyResourceChanged(player, "Stamina", amount, data.MaxStamina)
	self.DebugService:SendMessage(
		player,
		string.format("💛 Стамина установлена: %d/%d", amount, data.MaxStamina)
	)
end

-- Показать информацию о персонаже
function CharacterCommands:ShowCharacterInfo(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if not CharacterService or not PlayerDataService then
		self.DebugService:SendMessage(player, "❌ Сервисы недоступны!")
		return
	end

	local data = PlayerDataService:GetData(player)
	local character = CharacterService:GetPlayerCharacter(player)

	if not data then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	self.DebugService:SendMessage(player, "=== ИНФОРМАЦИЯ О ПЕРСОНАЖЕ ===")

	-- Основная информация
	self.DebugService:SendMessage(player, string.format("Имя: %s", player.Name))
	self.DebugService:SendMessage(player, string.format("Уровень: %d", data.Level))

	-- Ресурсы
	self.DebugService:SendMessage(player, "--- РЕСУРСЫ ---")
	self.DebugService:SendMessage(
		player,
		string.format(
			"❤️ Здоровье: %d/%d (%.1f%%)",
			data.Health,
			data.MaxHealth,
			(data.Health / data.MaxHealth) * 100
		)
	)
	self.DebugService:SendMessage(
		player,
		string.format("💙 Мана: %d/%d (%.1f%%)", data.Mana, data.MaxMana, (data.Mana / data.MaxMana) * 100)
	)
	self.DebugService:SendMessage(
		player,
		string.format(
			"💛 Стамина: %d/%d (%.1f%%)",
			data.Stamina,
			data.MaxStamina,
			(data.Stamina / data.MaxStamina) * 100
		)
	)

	-- Состояние персонажа
	self.DebugService:SendMessage(player, "--- СОСТОЯНИЕ ---")

	local isAlive = character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0
	local aliveStatus = isAlive and "✅ Жив" or "💀 Мертв"
	self.DebugService:SendMessage(player, string.format("Статус: %s", aliveStatus))

	local isInvulnerable = CharacterService:IsPlayerInvulnerable(player)
	local invulStatus = isInvulnerable and "🛡️ Неуязвим" or "⚔️ Уязвим"
	self.DebugService:SendMessage(player, string.format("Защита: %s", invulStatus))

	local isSetup = CharacterService:IsCharacterSetup(player)
	local setupStatus = isSetup and "✅ Настроен" or "⏳ Настройка..."
	self.DebugService:SendMessage(player, string.format("Персонаж: %s", setupStatus))

	-- Характеристики персонажа
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			self.DebugService:SendMessage(player, "--- ХАРАКТЕРИСТИКИ ---")
			self.DebugService:SendMessage(
				player,
				string.format("Скорость ходьбы: %.1f", humanoid.WalkSpeed)
			)
			self.DebugService:SendMessage(player, string.format("Сила прыжка: %.1f", humanoid.JumpPower))
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local pos = humanoidRootPart.Position
			self.DebugService:SendMessage(
				player,
				string.format("Позиция: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
			)
		end
	end

	-- Статистика смертей
	self.DebugService:SendMessage(player, "--- СТАТИСТИКА ---")
	self.DebugService:SendMessage(player, string.format("Смертей: %d", data.Statistics.Deaths))

	-- Быстрые команды
	self.DebugService:SendMessage(player, "--- КОМАНДЫ ---")
	self.DebugService:SendMessage(player, "/damage 50 - нанести урон")
	self.DebugService:SendMessage(player, "/heal 100 - лечение")
	self.DebugService:SendMessage(player, "/regen - полное восстановление")
	self.DebugService:SendMessage(player, "/kill - убить персонажа")
end

-- Установить скорость ходьбы
function CharacterCommands:SetWalkSpeed(player, speed)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	local character = CharacterService:GetPlayerCharacter(player)
	if not character then
		self.DebugService:SendMessage(player, "❌ Персонаж не найден!")
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		self.DebugService:SendMessage(player, "❌ Humanoid не найден!")
		return
	end

	speed = math.max(0, math.min(speed, 100)) -- Ограничиваем скорость
	humanoid.WalkSpeed = speed

	self.DebugService:SendMessage(player, string.format("🏃 Скорость ходьбы: %.1f", speed))
end

-- Установить силу прыжка
function CharacterCommands:SetJumpPower(player, jumpPower)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	local character = CharacterService:GetPlayerCharacter(player)
	if not character then
		self.DebugService:SendMessage(player, "❌ Персонаж не найден!")
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		self.DebugService:SendMessage(player, "❌ Humanoid не найден!")
		return
	end

	jumpPower = math.max(0, math.min(jumpPower, 200)) -- Ограничиваем силу прыжка
	humanoid.JumpPower = jumpPower

	self.DebugService:SendMessage(player, string.format("🦘 Сила прыжка: %.1f", jumpPower))
end

-- Потратить стамину
function CharacterCommands:ConsumeStamina(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	amount = math.max(1, math.min(amount, 1000))

	local success = CharacterService:ConsumeStamina(player, amount)
	if success then
		self.DebugService:SendMessage(player, string.format("⚡ Потрачено стамины: %d", amount))
	else
		self.DebugService:SendMessage(player, "❌ Недостаточно стамины!")
	end
end

-- Телепорт к точке спавна
function CharacterCommands:TeleportToSpawn(player, spawnName)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	local character = CharacterService:GetPlayerCharacter(player)
	if not character then
		self.DebugService:SendMessage(player, "❌ Персонаж не найден!")
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		self.DebugService:SendMessage(player, "❌ HumanoidRootPart не найден!")
		return
	end

	-- Получаем точку спавна
	local spawnLocations = Constants.WORLD.SPAWN_LOCATIONS
	local spawnLocation = spawnLocations[spawnName:upper()]

	if not spawnLocation then
		self.DebugService:SendMessage(player, "❌ Точка спавна не найдена: " .. spawnName)
		self.DebugService:SendMessage(player, "Доступные: MAIN, NORTH, SOUTH, EAST, WEST")
		return
	end

	-- Телепортируем
	humanoidRootPart.CFrame = CFrame.new(spawnLocation.Position)
	self.DebugService:SendMessage(
		player,
		string.format("🌀 Телепорт к %s (%s)", spawnLocation.Name, spawnName:upper())
	)
end

-- Сброс персонажа
function CharacterCommands:ResetCharacter(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local CharacterService = ServiceManager:GetService("CharacterService")

	if not CharacterService then
		self.DebugService:SendMessage(player, "❌ CharacterService недоступен!")
		return
	end

	-- Принудительно перезагружаем персонажа
	player:LoadCharacter()
	self.DebugService:SendMessage(player, "🔄 Персонаж сброшен и перезагружен!")
end

return CharacterCommands
