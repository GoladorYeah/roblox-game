-- src/shared/utils/TableUtils.lua
-- Утилиты для работы с таблицами

local TableUtils = {}

---[[ БАЗОВЫЕ ОПЕРАЦИИ С ТАБЛИЦАМИ ]]---

-- Глубокое копирование таблицы
function TableUtils.DeepCopy(original: { [any]: any }): { [any]: any }
	local copy = {}

	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = TableUtils.DeepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

-- Поверхностное копирование таблицы
function TableUtils.ShallowCopy(original: { [any]: any }): { [any]: any }
	return table.clone(original)
end

-- Объединение таблиц (перезаписывает конфликтующие ключи)
function TableUtils.Merge(target: { [any]: any }, source: { [any]: any }): { [any]: any }
	for key, value in pairs(source) do
		target[key] = value
	end

	return target
end

-- Глубокое объединение таблиц
function TableUtils.DeepMerge(target: { [any]: any }, source: { [any]: any }): { [any]: any }
	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			target[key] = TableUtils.DeepMerge(target[key], value)
		else
			target[key] = value
		end
	end

	return target
end

-- Проверка равенства таблиц
function TableUtils.AreEqual(table1: { [any]: any }, table2: { [any]: any }): boolean
	-- Проверяем, что оба значения - таблицы
	if type(table1) ~= "table" or type(table2) ~= "table" then
		return table1 == table2
	end

	-- Проверяем все ключи из первой таблицы
	for key, value in pairs(table1) do
		if not TableUtils.AreEqual(value, table2[key]) then
			return false
		end
	end

	-- Проверяем, что во второй таблице нет дополнительных ключей
	for key, _ in pairs(table2) do
		if table1[key] == nil then
			return false
		end
	end

	return true
end

-- Получение размера таблицы (включая не-числовые ключи)
function TableUtils.GetSize(tbl: { [any]: any }): number
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

-- Проверка, пустая ли таблица
function TableUtils.IsEmpty(tbl: { [any]: any }): boolean
	return next(tbl) == nil
end

-- Получение всех ключей таблицы
function TableUtils.GetKeys(tbl: { [any]: any }): { any }
	local keys = {}
	for key, _ in pairs(tbl) do
		table.insert(keys, key)
	end
	return keys
end

-- Получение всех значений таблицы
function TableUtils.GetValues(tbl: { [any]: any }): { any }
	local values = {}
	for _, value in pairs(tbl) do
		table.insert(values, value)
	end
	return values
end

-- Инвертирование таблицы (ключи становятся значениями и наоборот)
function TableUtils.Invert(tbl: { [any]: any }): { [any]: any }
	local inverted = {}
	for key, value in pairs(tbl) do
		inverted[value] = key
	end
	return inverted
end

---[[ ОПЕРАЦИИ С МАССИВАМИ ]]---

-- Проверка, содержит ли массив значение
function TableUtils.Contains(array: { any }, value: any): boolean
	for _, item in ipairs(array) do
		if item == value then
			return true
		end
	end
	return false
end

-- Поиск индекса элемента в массиве
function TableUtils.IndexOf(array: { any }, value: any): number?
	for i, item in ipairs(array) do
		if item == value then
			return i
		end
	end
	return nil
end

-- Удаление элемента из массива по значению
function TableUtils.RemoveValue(array: { any }, value: any): boolean
	local index = TableUtils.IndexOf(array, value)
	if index then
		table.remove(array, index)
		return true
	end
	return false
end

-- Удаление всех вхождений значения
function TableUtils.RemoveAllValues(array: { any }, value: any): number
	local removed = 0
	local i = 1

	while i <= #array do
		if array[i] == value then
			table.remove(array, i)
			removed = removed + 1
		else
			i = i + 1
		end
	end

	return removed
end

-- Фильтрация массива
function TableUtils.Filter(array: { any }, predicate: (any, number?) -> boolean): { any }
	local filtered = {}

	for i, item in ipairs(array) do
		if predicate(item, i) then
			table.insert(filtered, item)
		end
	end

	return filtered
end

-- Преобразование массива
function TableUtils.Map(array: { any }, transform: (any, number?) -> any): { any }
	local mapped = {}

	for i, item in ipairs(array) do
		mapped[i] = transform(item, i)
	end

	return mapped
end

-- Свертка массива (reduce)
function TableUtils.Reduce(array: { any }, reducer: (any, any, number?) -> any, initialValue: any?): any
	local accumulator = initialValue
	local startIndex = 1

	if accumulator == nil and #array > 0 then
		accumulator = array[1]
		startIndex = 2
	end

	for i = startIndex, #array do
		accumulator = reducer(accumulator, array[i], i)
	end

	return accumulator
end

-- Поиск элемента в массиве
function TableUtils.Find(array: { any }, predicate: (any, number?) -> boolean): any?
	for i, item in ipairs(array) do
		if predicate(item, i) then
			return item
		end
	end
	return nil
end

-- Поиск индекса элемента в массиве
function TableUtils.FindIndex(array: { any }, predicate: (any, number?) -> boolean): number?
	for i, item in ipairs(array) do
		if predicate(item, i) then
			return i
		end
	end
	return nil
end

-- Проверка, удовлетворяют ли все элементы условию
function TableUtils.All(array: { any }, predicate: (any, number?) -> boolean): boolean
	for i, item in ipairs(array) do
		if not predicate(item, i) then
			return false
		end
	end
	return true
end

-- Проверка, удовлетворяет ли хотя бы один элемент условию
function TableUtils.Any(array: { any }, predicate: (any, number?) -> boolean): boolean
	for i, item in ipairs(array) do
		if predicate(item, i) then
			return true
		end
	end
	return false
end

-- Перемешивание массива (Fisher-Yates)
function TableUtils.Shuffle(array: { any }): { any }
	local shuffled = TableUtils.ShallowCopy(array)

	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	return shuffled
end

-- Получение случайного элемента из массива
function TableUtils.GetRandomElement(array: { any }): any?
	if #array == 0 then
		return nil
	end

	return array[math.random(#array)]
end

-- Получение N случайных элементов без повторений
function TableUtils.GetRandomElements(array: { any }, count: number): { any }
	if count >= #array then
		return TableUtils.Shuffle(array)
	end

	local shuffled = TableUtils.Shuffle(array)
	local result = {}

	for i = 1, math.min(count, #shuffled) do
		table.insert(result, shuffled[i])
	end

	return result
end

-- Разделение массива на части
function TableUtils.Chunk(array: { any }, size: number): { { any } }
	local chunks = {}
	local currentChunk = {}

	for i, item in ipairs(array) do
		table.insert(currentChunk, item)

		if #currentChunk == size or i == #array then
			table.insert(chunks, currentChunk)
			currentChunk = {}
		end
	end

	return chunks
end

-- Объединение массивов
function TableUtils.Concat(...: { any }): { any }
	local result = {}

	for _, array in ipairs({ ... }) do
		for _, item in ipairs(array) do
			table.insert(result, item)
		end
	end

	return result
end

-- Удаление дубликатов из массива
function TableUtils.Unique(array: { any }): { any }
	local seen = {}
	local unique = {}

	for _, item in ipairs(array) do
		if not seen[item] then
			seen[item] = true
			table.insert(unique, item)
		end
	end

	return unique
end

-- Пересечение массивов
function TableUtils.Intersection(array1: { any }, array2: { any }): { any }
	local set = {}
	local result = {}

	-- Создаем множество из первого массива
	for _, item in ipairs(array1) do
		set[item] = true
	end

	-- Добавляем элементы из второго массива, которые есть в первом
	for _, item in ipairs(array2) do
		if set[item] and not TableUtils.Contains(result, item) then
			table.insert(result, item)
		end
	end

	return result
end

-- Разность массивов
function TableUtils.Difference(array1: { any }, array2: { any }): { any }
	local set = {}
	local result = {}

	-- Создаем множество из второго массива
	for _, item in ipairs(array2) do
		set[item] = true
	end

	-- Добавляем элементы из первого массива, которых нет во втором
	for _, item in ipairs(array1) do
		if not set[item] then
			table.insert(result, item)
		end
	end

	return result
end

---[[ ГРУППИРОВКА И АГРЕГАЦИЯ ]]---

-- Группировка по ключевой функции
function TableUtils.GroupBy(array: { any }, keySelector: (any) -> any): { [any]: { any } }
	local groups = {}

	for _, item in ipairs(array) do
		local key = keySelector(item)

		if not groups[key] then
			groups[key] = {}
		end

		table.insert(groups[key], item)
	end

	return groups
end

-- Подсчет элементов по ключевой функции
function TableUtils.CountBy(array: { any }, keySelector: (any) -> any): { [any]: number }
	local counts = {}

	for _, item in ipairs(array) do
		local key = keySelector(item)
		counts[key] = (counts[key] or 0) + 1
	end

	return counts
end

-- Суммирование по ключевой функции
function TableUtils.SumBy(array: { any }, valueSelector: (any) -> number): number
	local sum = 0

	for _, item in ipairs(array) do
		sum = sum + valueSelector(item)
	end

	return sum
end

-- Максимальное значение по ключевой функции
function TableUtils.MaxBy(array: { any }, valueSelector: (any) -> number): any?
	if #array == 0 then
		return nil
	end

	local maxItem = array[1]
	local maxValue = valueSelector(maxItem)

	for i = 2, #array do
		local value = valueSelector(array[i])
		if value > maxValue then
			maxValue = value
			maxItem = array[i]
		end
	end

	return maxItem
end

-- Минимальное значение по ключевой функции
function TableUtils.MinBy(array: { any }, valueSelector: (any) -> number): any?
	if #array == 0 then
		return nil
	end

	local minItem = array[1]
	local minValue = valueSelector(minItem)

	for i = 2, #array do
		local value = valueSelector(array[i])
		if value < minValue then
			minValue = value
			minItem = array[i]
		end
	end

	return minItem
end

---[[ СОРТИРОВКА ]]---

-- Сортировка по ключевой функции
function TableUtils.SortBy(array: { any }, keySelector: (any) -> any, descending: boolean?): { any }
	local sorted = TableUtils.ShallowCopy(array)
	local isDescending = descending or false

	table.sort(sorted, function(a, b)
		local keyA = keySelector(a)
		local keyB = keySelector(b)

		if isDescending then
			return keyA > keyB
		else
			return keyA < keyB
		end
	end)

	return sorted
end

-- Многоуровневая сортировка
function TableUtils.SortByMultiple(array: { any }, keySelectors: { (any) -> any }, descending: { boolean }?): { any }
	local sorted = TableUtils.ShallowCopy(array)

	table.sort(sorted, function(a, b)
		for i, keySelector in ipairs(keySelectors) do
			local keyA = keySelector(a)
			local keyB = keySelector(b)
			local isDescending = descending and descending[i] or false

			if keyA ~= keyB then
				if isDescending then
					return keyA > keyB
				else
					return keyA < keyB
				end
			end
		end

		return false -- элементы равны
	end)

	return sorted
end

---[[ ИГРОВЫЕ УТИЛИТЫ ]]---

-- Поиск игрока по UserId
function TableUtils.FindPlayerByUserId(players: { any }, userId: number): any?
	return TableUtils.Find(players, function(player)
		return player.UserId == userId
	end)
end

-- Группировка предметов по типу
function TableUtils.GroupItemsByType(items: { any }): { [string]: { any } }
	return TableUtils.GroupBy(items, function(item)
		return item.Type or "Unknown"
	end)
end

-- Фильтрация предметов по редкости
function TableUtils.FilterItemsByRarity(items: { any }, rarity: string): { any }
	return TableUtils.Filter(items, function(item)
		return item.Rarity == rarity
	end)
end

-- Сортировка игроков по уровню
function TableUtils.SortPlayersByLevel(players: { any }, descending: boolean?): { any }
	local isDescending = descending or false
	return TableUtils.SortBy(players, function(player)
		return player.Level or 1
	end, isDescending)
end

-- Получение топ N игроков по опыту
function TableUtils.GetTopPlayersByExperience(players: { any }, count: number): { any }
	local sorted = TableUtils.SortBy(players, function(player)
		return player.Experience or 0
	end, true) -- по убыванию

	local result = {}
	for i = 1, math.min(count, #sorted) do
		table.insert(result, sorted[i])
	end

	return result
end

---[[ ПРОИЗВОДИТЕЛЬНОСТЬ ]]---

-- Создание индекса для быстрого поиска
function TableUtils.CreateIndex(array: { any }, keySelector: (any) -> any): { [any]: any }
	local index = {}

	for _, item in ipairs(array) do
		local key = keySelector(item)
		index[key] = item
	end

	return index
end

-- Создание множественного индекса (один ключ -> много значений)
function TableUtils.CreateMultiIndex(array: { any }, keySelector: (any) -> any): { [any]: { any } }
	local index = {}

	for _, item in ipairs(array) do
		local key = keySelector(item)

		if not index[key] then
			index[key] = {}
		end

		table.insert(index[key], item)
	end

	return index
end

---[[ ОТЛАДКА ]]---

-- Красивая печать таблицы
function TableUtils.PrettyPrint(tbl: { [any]: any }, indent: number?): string
	local actualIndent = indent or 0
	local indentStr = string.rep("  ", actualIndent)
	local result = "{\n"

	for key, value in pairs(tbl) do
		result = result .. indentStr .. "  "

		if type(key) == "string" then
			result = result .. '["' .. key .. '"]'
		else
			result = result .. "[" .. tostring(key) .. "]"
		end

		result = result .. " = "

		if type(value) == "table" then
			result = result .. TableUtils.PrettyPrint(value, actualIndent + 1)
		elseif type(value) == "string" then
			result = result .. '"' .. value .. '"'
		else
			result = result .. tostring(value)
		end

		result = result .. ",\n"
	end

	result = result .. indentStr .. "}"
	return result
end

-- Получение информации о таблице
function TableUtils.GetTableInfo(tbl: { [any]: any }): {
	Size: number,
	ArrayLength: number,
	HasNonIntegerKeys: boolean,
	KeyTypes: { string },
	ValueTypes: { string },
}
	local info = {
		Size = TableUtils.GetSize(tbl),
		ArrayLength = #tbl,
		HasNonIntegerKeys = false,
		KeyTypes = {},
		ValueTypes = {},
	}

	local keyTypeCounts = {}
	local valueTypeCounts = {}

	for key, value in pairs(tbl) do
		local keyType = type(key)
		local valueType = type(value)

		keyTypeCounts[keyType] = (keyTypeCounts[keyType] or 0) + 1
		valueTypeCounts[valueType] = (valueTypeCounts[valueType] or 0) + 1

		if keyType ~= "number" or key ~= math.floor(key) or key <= 0 then
			info.HasNonIntegerKeys = true
		end
	end

	info.KeyTypes = TableUtils.GetKeys(keyTypeCounts)
	info.ValueTypes = TableUtils.GetKeys(valueTypeCounts)

	return info
end

return TableUtils
