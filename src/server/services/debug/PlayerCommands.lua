-- src/server/services/debug/PlayerCommands.lua
-- Команды для управления игроком

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

	debugService:RegisterCommand("stats", "Показать статистику игрока", function(player, _)
		self:ShowStats(player)
	end)

	debugService:RegisterCommand("heal", "Восстановить здоровье", function(player, _)
		self:HealPlayer(player)
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
end

-- Показать статистику игрока
function PlayerCommands:ShowStats(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		local requiredXP = PlayerDataService:GetRequiredExperience(data.Level)
		local totalXP = PlayerDataService:GetTotalExperience(player)
		local nextLevelXP = PlayerDataService:GetRequiredExperience(data.Level + 1)

		self.DebugService:SendMessage(player, "=== СТАТИСТИКА ИГРОКА ===")
		self.DebugService:SendMessage(player, "Уровень: " .. data.Level)
		self.DebugService:SendMessage(
			player,
			string.format("Опыт: %d/%d (%.1f%%)", data.Experience, requiredXP, (data.Experience / requiredXP) * 100)
		)
		self.DebugService:SendMessage(player, "Общий опыт: " .. totalXP)
		self.DebugService:SendMessage(player, "Для следующего уровня: " .. nextLevelXP)
		self.DebugService:SendMessage(player, "Золото: " .. data.Currency.Gold)
		self.DebugService:SendMessage(
			player,
			string.format("Здоровье: %d/%d", data.Health, data.MaxHealth or 100)
		)
		self.DebugService:SendMessage(player, string.format("Мана: %d/%d", data.Mana, data.MaxMana or 50))
		self.DebugService:SendMessage(
			player,
			string.format("Стамина: %d/%d", data.Stamina, data.MaxStamina or 100)
		)
		self.DebugService:SendMessage(
			player,
			"Время игры: " .. math.floor(data.Statistics.TotalPlayTime / 60) .. " мин"
		)
		self.DebugService:SendMessage(player, "Очки атрибутов: " .. data.AttributePoints)

		-- Показываем атрибуты
		self.DebugService:SendMessage(player, "--- АТРИБУТЫ ---")
		for attrName, attrValue in pairs(data.Attributes) do
			self.DebugService:SendMessage(player, string.format("%s: %d", attrName, attrValue))
		end

		-- Показываем статистику
		self.DebugService:SendMessage(player, "--- СТАТИСТИКА ---")
		self.DebugService:SendMessage(player, "Убито мобов: " .. data.Statistics.MobsKilled)
		self.DebugService:SendMessage(player, "Завершено квестов: " .. data.Statistics.QuestsCompleted)
		self.DebugService:SendMessage(player, "Создано предметов: " .. data.Statistics.ItemsCrafted)
		self.DebugService:SendMessage(player, "Смертей: " .. data.Statistics.Deaths)
	end
end

-- Восстановить здоровье игрока
function PlayerCommands:HealPlayer(player)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "Данные игрока не загружены!")
		return
	end

	local data = PlayerDataService:GetData(player)
	if data ~= nil then
		-- Рассчитываем максимальные значения
		local maxHealth = Constants.PLAYER.BASE_HEALTH
			+ (data.Attributes.Constitution * Constants.PLAYER.HEALTH_PER_CONSTITUTION)
		local maxMana = Constants.PLAYER.BASE_MANA
			+ (data.Attributes.Intelligence * Constants.PLAYER.MANA_PER_INTELLIGENCE)
		local maxStamina = Constants.PLAYER.BASE_STAMINA
			+ (data.Attributes.Constitution * Constants.PLAYER.STAMINA_PER_CONSTITUTION)

		-- Восстанавливаем ресурсы
		data.Health = maxHealth
		data.Mana = maxMana
		data.Stamina = maxStamina

		-- Обновляем максимальные значения
		data.MaxHealth = maxHealth
		data.MaxMana = maxMana
		data.MaxStamina = maxStamina

		-- Отправляем обновления
		PlayerDataService:InitializePlayerResources(player)

		self.DebugService:SendMessage(
			player,
			string.format(
				"✅ Полностью восстановлен! HP: %d, MP: %d, SP: %d",
				maxHealth,
				maxMana,
				maxStamina
			)
		)

		print(
			string.format("[DEBUG] %s fully healed: HP=%d, MP=%d, SP=%d", player.Name, maxHealth, maxMana, maxStamina)
		)
	end
end

-- Добавить золото
function PlayerCommands:AddGold(player, amount)
	local ServiceManager = self.DebugService:GetServiceManager()
	local PlayerDataService = ServiceManager:GetService("PlayerDataService")

	if PlayerDataService == nil or PlayerDataService:IsDataLoaded(player) == false then
		self.DebugService:SendMessage(player, "Данные игрока не загружены!")
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
		self.DebugService:SendMessage(player, "Данные игрока не загружены!")
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
		self.DebugService:SendMessage(player, "Данные игрока не загружены!")
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
		self.DebugService:SendMessage(player, "Данные игрока не загружены!")
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
			string.format("Очки атрибутов восстановлены: %d", data.AttributePoints)
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

return PlayerCommands
