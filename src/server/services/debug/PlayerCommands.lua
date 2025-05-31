-- src/server/services/debug/PlayerCommands.lua
-- Команды для управления данными игрока (НЕ персонажем!)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.constants.Constants)

local PlayerCommands = {}
PlayerCommands.__index = PlayerCommands

function PlayerCommands.new(debugService)
	local self = setmetatable({}, PlayerCommands)
	self.DebugService = debugService
	return self
end

function PlayerCommands:RegisterCommands()
	local debugService = self.DebugService

	-- ТОЛЬКО команды для ДАННЫХ игрока, не персонажа!
	debugService:RegisterCommand("stats", "Показать статистику игрока", function(player, _)
		self:ShowStats(player)
	end)

	debugService:RegisterCommand(
		"addgold",
		"Добавить золото: /addgold [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 100
			self:AddGold(player, amount)
		end
	)

	debugService:RegisterCommand(
		"setgold",
		"Установить золото: /setgold [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 1000
			self:SetGold(player, amount)
		end
	)

	debugService:RegisterCommand(
		"addattr",
		"Добавить очки атрибутов: /addattr [количество]",
		function(player, args)
			local amount = tonumber(args[1]) or 5
			self:AddAttributePoints(player, amount)
		end
	)

	debugService:RegisterCommand("resetattr", "Сбросить атрибуты", function(player, _)
		self:ResetAttributes(player)
	end)

	debugService:RegisterCommand(
		"savedata",
		"Принудительно сохранить данные",
		function(player, _)
			self:SavePlayerData(player)
		end
	)

	debugService:RegisterCommand(
		"reloaddata",
		"Перезагрузить данные игрока",
		function(player, _)
			self:ReloadPlayerData(player)
		end
	)
end

-- Показать статистику игрока
function PlayerCommands:ShowStats(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		local requiredXP = PlayerDataService:GetRequiredExperience(data.Level)
		local totalXP = PlayerDataService:GetTotalExperience(player)
		local nextLevelXP = PlayerDataService:GetRequiredExperience(data.Level + 1)

		self.DebugService:SendMessage(player, "=== СТАТИСТИКА ИГРОКА ===")
		self.DebugService:SendMessage(player, "👤 Имя: " .. player.Name)
		self.DebugService:SendMessage(player, "⭐ Уровень: " .. data.Level)
		self.DebugService:SendMessage(
			player,
			string.format(
				"📈 Опыт: %d/%d (%.1f%%)",
				data.Experience,
				requiredXP,
				(data.Experience / requiredXP) * 100
			)
		)
		self.DebugService:SendMessage(player, "🎯 Общий опыт: " .. totalXP)
		self.DebugService:SendMessage(player, "📊 Для следующего уровня: " .. nextLevelXP)
		self.DebugService:SendMessage(player, "💰 Золото: " .. data.Currency.Gold)
		self.DebugService:SendMessage(player, "🎲 Очки атрибутов: " .. data.AttributePoints)
		self.DebugService:SendMessage(
			player,
			"⏱️ Время игры: " .. math.floor(data.Statistics.TotalPlayTime / 60) .. " мин"
		)

		-- Показываем максимальные ресурсы (расчетные)
		self.DebugService:SendMessage(player, "--- МАКСИМАЛЬНЫЕ РЕСУРСЫ ---")
		self.DebugService:SendMessage(
			player,
			string.format("❤️ Макс. здоровье: %d", data.MaxHealth or 100)
		)
		self.DebugService:SendMessage(player, string.format("💙 Макс. мана: %d", data.MaxMana or 50))
		self.DebugService:SendMessage(
			player,
			string.format("💛 Макс. стамина: %d", data.MaxStamina or 100)
		)

		-- Показываем атрибуты
		self.DebugService:SendMessage(player, "--- АТРИБУТЫ ---")
		for attrName, attrValue in pairs(data.Attributes) do
			self.DebugService:SendMessage(player, string.format("🔸 %s: %d", attrName, attrValue))
		end

		-- Показываем игровую статистику
		self.DebugService:SendMessage(player, "--- ИГРОВАЯ СТАТИСТИКА ---")
		self.DebugService:SendMessage(player, "⚔️ Убито мобов: " .. data.Statistics.MobsKilled)
		self.DebugService:SendMessage(
			player,
			"📜 Завершено квестов: " .. data.Statistics.QuestsCompleted
		)
		self.DebugService:SendMessage(
			player,
			"🔨 Создано предметов: " .. data.Statistics.ItemsCrafted
		)
		self.DebugService:SendMessage(player, "💀 Смертей: " .. data.Statistics.Deaths)
		self.DebugService:SendMessage(player, "⚔️ Нанесено урона: " .. data.Statistics.DamageDealt)
		self.DebugService:SendMessage(player, "🛡️ Получено урона: " .. data.Statistics.DamageTaken)
	end
end

-- Добавить золото
function PlayerCommands:AddGold(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local success = PlayerDataService:AddGold(player, amount, "ADMIN_GRANT")
	if success then
		self.DebugService:SendMessage(player, string.format("✅ Добавлено %d золота!", amount))
	else
		self.DebugService:SendMessage(player, "❌ Ошибка при добавлении золота!")
	end
end

-- Установить золото
function PlayerCommands:SetGold(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		amount = math.max(0, math.min(amount, 1000000000)) -- Ограничиваем диапазон

		local oldGold = data.Currency.Gold
		data.Currency.Gold = amount

		-- Уведомляем клиент об изменении данных
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		self.DebugService:SendMessage(
			player,
			string.format("✅ Золото установлено: %d -> %d", oldGold, amount)
		)
		print(string.format("[DEBUG] %s gold set: %d -> %d", player.Name, oldGold, amount))
	end
end

-- Добавить очки атрибутов
function PlayerCommands:AddAttributePoints(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		amount = math.max(0, amount)

		local oldPoints = data.AttributePoints
		data.AttributePoints = data.AttributePoints + amount

		-- Уведомляем клиент об изменении данных
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		self.DebugService:SendMessage(
			player,
			string.format(
				"✅ Добавлено %d очков атрибутов! Всего: %d",
				amount,
				data.AttributePoints
			)
		)
		print(
			string.format(
				"[DEBUG] %s attribute points: %d -> %d (+%d)",
				player.Name,
				oldPoints,
				data.AttributePoints,
				amount
			)
		)
	end
end

-- Сбросить атрибуты к базовым значениям
function PlayerCommands:ResetAttributes(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		-- Сохраняем старые значения
		local oldAttributes = table.clone(data.Attributes)

		-- Сбрасываем к базовым значениям
		data.Attributes = {
			Strength = Constants.PLAYER.BASE_ATTRIBUTES.Strength,
			Dexterity = Constants.PLAYER.BASE_ATTRIBUTES.Dexterity,
			Intelligence = Constants.PLAYER.BASE_ATTRIBUTES.Intelligence,
			Constitution = Constants.PLAYER.BASE_ATTRIBUTES.Constitution,
			Focus = Constants.PLAYER.BASE_ATTRIBUTES.Focus,
		}

		-- Возвращаем очки атрибутов (предполагаем 5 очков за уровень)
		data.AttributePoints = math.max(0, (data.Level - 1) * 5)

		-- Пересчитываем ресурсы с новыми атрибутами
		PlayerDataService:InitializePlayerResources(player)

		-- Уведомляем клиент
		PlayerDataService:FireClient(player, Constants.REMOTE_EVENTS.PLAYER_DATA_LOADED, data)

		self.DebugService:SendMessage(
			player,
			"✅ Атрибуты сброшены к базовым значениям!"
		)
		self.DebugService:SendMessage(
			player,
			string.format("🎲 Очки атрибутов восстановлены: %d", data.AttributePoints)
		)

		-- Показываем изменения
		self.DebugService:SendMessage(player, "--- ИЗМЕНЕНИЯ ---")
		for attr, newValue in pairs(data.Attributes) do
			local oldValue = oldAttributes[attr]
			if oldValue ~= newValue then
				self.DebugService:SendMessage(player, string.format("%s: %d -> %d", attr, oldValue, newValue))
			end
		end

		print(
			string.format(
				"[DEBUG] %s attributes reset to base values, points restored: %d",
				player.Name,
				data.AttributePoints
			)
		)
	end
end

-- Принудительно сохранить данные игрока
function PlayerCommands:SavePlayerData(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil then
		self.DebugService:SendMessage(player, "❌ PlayerDataService недоступен!")
		return
	end

	if not PlayerDataService:IsDataLoaded(player) then
		self.DebugService:SendMessage(player, "❌ Данные игрока не загружены!")
		return
	end

	-- ProfileService автоматически сохраняет данные
	-- Но мы можем принудительно сохранить через SaveAllPlayerData
	PlayerDataService:SaveAllPlayerData()

	self.DebugService:SendMessage(player, "💾 Данные сохранены!")
	print(string.format("[DEBUG] Forced save for %s", player.Name))
end

-- Перезагрузить данные игрока (опасная операция!)
function PlayerCommands:ReloadPlayerData(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil then
		self.DebugService:SendMessage(player, "❌ PlayerDataService недоступен!")
		return
	end

	self.DebugService:SendMessage(player, "⚠️ Перезагрузка данных...")
	self.DebugService:SendMessage(
		player,
		"⚠️ ВНИМАНИЕ: Несохраненные изменения будут потеряны!"
	)

	-- Сначала сохраняем текущие данные
	PlayerDataService:SavePlayerData(player)

	-- Ждем немного
	wait(1)

	-- Загружаем заново
	PlayerDataService:LoadPlayerData(player)

	self.DebugService:SendMessage(player, "🔄 Данные перезагружены!")
	print(string.format("[DEBUG] Data reloaded for %s", player.Name))
end

return PlayerCommands
