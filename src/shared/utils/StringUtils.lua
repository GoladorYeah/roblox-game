-- src/shared/utils/StringUtils.lua
-- Утилиты для работы со строками

local StringUtils = {}

---[[ БАЗОВЫЕ ОПЕРАЦИИ СО СТРОКАМИ ]]---

-- Обрезка пробелов с начала и конца
function StringUtils.Trim(str: string): string
	local result = string.match(str, "^%s*(.-)%s*$")
	return result or ""
end

-- Обрезка пробелов слева
function StringUtils.TrimLeft(str: string): string
	local result = string.match(str, "^%s*(.*)$")
	return result or ""
end

-- Обрезка пробелов справа
function StringUtils.TrimRight(str: string): string
	local result = string.match(str, "^(.-)%s*$")
	return result or ""
end

-- Проверка, что строка пустая или состоит только из пробелов
function StringUtils.IsEmpty(str: string): boolean
	return StringUtils.Trim(str) == ""
end

-- Проверка, что строка не пустая
function StringUtils.IsNotEmpty(str: string): boolean
	return not StringUtils.IsEmpty(str)
end

-- Разделение строки по разделителю
function StringUtils.Split(str: string, delimiter: string): { string }
	local result = {}
	local pattern = "(.-)" .. delimiter
	local lastEnd = 1

	for part in string.gmatch(str, pattern) do
		table.insert(result, part)
		lastEnd = lastEnd + #part + #delimiter
	end

	-- Добавляем последнюю часть
	table.insert(result, string.sub(str, lastEnd))

	return result
end

-- Объединение массива строк с разделителем
function StringUtils.Join(strings: { string }, delimiter: string): string
	return table.concat(strings, delimiter)
end

-- Повторение строки N раз
function StringUtils.Repeat(str: string, count: number): string
	if count <= 0 then
		return ""
	end

	local result = ""
	for _ = 1, count do
		result = result .. str
	end

	return result
end

-- Дополнение строки слева до определенной длины
function StringUtils.PadLeft(str: string, length: number, padChar: string?): string
	local actualPadChar = padChar or " "
	local padLength = length - #str

	if padLength <= 0 then
		return str
	end

	return StringUtils.Repeat(actualPadChar, padLength) .. str
end

-- Дополнение строки справа до определенной длины
function StringUtils.PadRight(str: string, length: number, padChar: string?): string
	local actualPadChar = padChar or " "
	local padLength = length - #str

	if padLength <= 0 then
		return str
	end

	return str .. StringUtils.Repeat(actualPadChar, padLength)
end

-- Дополнение строки с обеих сторон до определенной длины
function StringUtils.PadCenter(str: string, length: number, padChar: string?): string
	local actualPadChar = padChar or " "
	local padLength = length - #str

	if padLength <= 0 then
		return str
	end

	local leftPad = math.floor(padLength / 2)
	local rightPad = padLength - leftPad

	return StringUtils.Repeat(actualPadChar, leftPad) .. str .. StringUtils.Repeat(actualPadChar, rightPad)
end

---[[ ПРОВЕРКИ И ВАЛИДАЦИЯ ]]---

-- Проверка, начинается ли строка с подстроки
function StringUtils.StartsWith(str: string, prefix: string): boolean
	return string.sub(str, 1, #prefix) == prefix
end

-- Проверка, заканчивается ли строка подстрокой
function StringUtils.EndsWith(str: string, suffix: string): boolean
	return string.sub(str, -#suffix) == suffix
end

-- Проверка, содержит ли строка подстроку
function StringUtils.Contains(str: string, substring: string): boolean
	return string.find(str, substring, 1, true) ~= nil
end

-- Проверка, содержит ли строка только цифры
function StringUtils.IsNumeric(str: string): boolean
	local result = string.match(str, "^%d+$")
	return result ~= nil
end

-- Проверка, содержит ли строка только буквы
function StringUtils.IsAlpha(str: string): boolean
	local result = string.match(str, "^%a+$")
	return result ~= nil
end

-- Проверка, содержит ли строка только буквы и цифры
function StringUtils.IsAlphanumeric(str: string): boolean
	local result = string.match(str, "^%w+$")
	return result ~= nil
end

-- Проверка валидности email (простая)
function StringUtils.IsValidEmail(str: string): boolean
	local result = string.match(str, "^[%w%.]+@[%w%.]+%.%w+$")
	return result ~= nil
end

-- Проверка, что строка является валидным именем игрока
function StringUtils.IsValidPlayerName(str: string): boolean
	if #str < 1 or #str > 20 then
		return false
	end

	-- Только буквы, цифры, подчеркивания и дефисы
	local result = string.match(str, "^[%w_%-]+$")
	return result ~= nil
end

---[[ ПРЕОБРАЗОВАНИЯ ]]---

-- Преобразование в нижний регистр
function StringUtils.ToLower(str: string): string
	return string.lower(str)
end

-- Преобразование в верхний регистр
function StringUtils.ToUpper(str: string): string
	return string.upper(str)
end

-- Преобразование первой буквы в верхний регистр
function StringUtils.Capitalize(str: string): string
	if #str == 0 then
		return str
	end

	return string.upper(string.sub(str, 1, 1)) .. string.lower(string.sub(str, 2))
end

-- Преобразование в Title Case (Каждое Слово С Заглавной)
function StringUtils.ToTitleCase(str: string): string
	return string.gsub(str, "(%w)([%w]*)", function(first, rest)
		return string.upper(first) .. string.lower(rest)
	end)
end

-- Обращение строки
function StringUtils.Reverse(str: string): string
	return string.reverse(str)
end

---[[ ПОИСК И ЗАМЕНА ]]---

-- Замена всех вхождений подстроки
function StringUtils.Replace(str: string, oldStr: string, newStr: string): string
	local escapedOld = string.gsub(oldStr, "([^%w])", "%%%1")
	return string.gsub(str, escapedOld, newStr)
end

-- Замена первого вхождения подстроки
function StringUtils.ReplaceFirst(str: string, oldStr: string, newStr: string): string
	local pos = string.find(str, oldStr, 1, true)
	if pos then
		return string.sub(str, 1, pos - 1) .. newStr .. string.sub(str, pos + #oldStr)
	end
	return str
end

-- Подсчет вхождений подстроки
function StringUtils.CountOccurrences(str: string, substring: string): number
	local count = 0
	local pos = 1

	while true do
		local found = string.find(str, substring, pos, true)
		if not found then
			break
		end
		count = count + 1
		pos = found + 1
	end

	return count
end

---[[ ИЗВЛЕЧЕНИЕ И ОБРЕЗКА ]]---

-- Извлечение подстроки безопасно (с проверкой границ)
function StringUtils.SafeSubstring(str: string, startPos: number, endPos: number?): string
	local length = #str
	startPos = math.max(1, math.min(startPos, length))
	local actualEndPos = endPos and math.max(startPos, math.min(endPos, length)) or length

	return string.sub(str, startPos, actualEndPos)
end

-- Обрезка строки до максимальной длины
function StringUtils.Truncate(str: string, maxLength: number, suffix: string?): string
	local actualSuffix = suffix or "..."

	if #str <= maxLength then
		return str
	end

	local truncateLength = maxLength - #actualSuffix
	if truncateLength <= 0 then
		return string.sub(actualSuffix, 1, maxLength)
	end

	return string.sub(str, 1, truncateLength) .. actualSuffix
end

-- Извлечение чисел из строки
function StringUtils.ExtractNumbers(str: string): { number }
	local numbers = {}

	for num in string.gmatch(str, "%-?%d+%.?%d*") do
		local parsed = tonumber(num)
		if parsed then
			table.insert(numbers, parsed)
		end
	end

	return numbers
end

-- Извлечение слов из строки
function StringUtils.ExtractWords(str: string): { string }
	local words = {}

	for word in string.gmatch(str, "%w+") do
		table.insert(words, word)
	end

	return words
end

---[[ ФОРМАТИРОВАНИЕ ]]---

-- Форматирование числа с разделителями тысяч
function StringUtils.FormatNumber(number: number, separator: string?): string
	local actualSeparator = separator or ","
	local str = tostring(math.floor(number))
	local reversed = StringUtils.Reverse(str)

	local formatted = ""
	for i = 1, #reversed do
		if i > 1 and (i - 1) % 3 == 0 then
			formatted = formatted .. actualSeparator
		end
		formatted = formatted .. string.sub(reversed, i, i)
	end

	return StringUtils.Reverse(formatted)
end

-- Форматирование времени (секунды в читаемый формат)
function StringUtils.FormatTime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	else
		return string.format("%d:%02d", minutes, secs)
	end
end

-- Форматирование размера файла
function StringUtils.FormatFileSize(bytes: number): string
	local units = { "B", "KB", "MB", "GB", "TB" }
	local size = bytes
	local unitIndex = 1

	while size >= 1024 and unitIndex < #units do
		size = size / 1024
		unitIndex = unitIndex + 1
	end

	if unitIndex == 1 then
		return string.format("%d %s", size, units[unitIndex])
	else
		return string.format("%.2f %s", size, units[unitIndex])
	end
end

---[[ ИГРОВЫЕ УТИЛИТЫ ]]---

-- Форматирование имени игрока с цветами редкости
function StringUtils.FormatPlayerName(name: string, level: number?, prefix: string?): string
	local formatted = name

	if prefix then
		formatted = prefix .. " " .. formatted
	end

	if level then
		formatted = formatted .. " (Lv." .. level .. ")"
	end

	return formatted
end

-- Форматирование сообщения чата
function StringUtils.FormatChatMessage(playerName: string, message: string, timestamp: number?): string
	local timeStr = ""
	if timestamp then
		timeStr = "[" .. os.date("%H:%M", timestamp) .. "] "
	end

	return timeStr .. playerName .. ": " .. message
end

-- Цензурирование текста (простая версия)
function StringUtils.CensorText(text: string, bannedWords: { string }?): string
	local actualBannedWords = bannedWords or { "damn", "hell", "stupid" } -- Примеры

	local censored = text
	for _, word in ipairs(actualBannedWords) do
		local replacement = StringUtils.Repeat("*", #word)
		censored = StringUtils.Replace(StringUtils.ToLower(censored), StringUtils.ToLower(word), replacement)
	end

	return censored
end

-- Генерация случайной строки
function StringUtils.GenerateRandomString(length: number, charset: string?): string
	local actualCharset = charset or "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

	local result = ""
	for _ = 1, length do
		local randomIndex = math.random(1, #actualCharset)
		result = result .. string.sub(actualCharset, randomIndex, randomIndex)
	end

	return result
end

-- Создание slug из текста (для URLs, идентификаторов)
function StringUtils.CreateSlug(text: string): string
	local slug = StringUtils.ToLower(text)

	-- Заменяем пробелы и специальные символы на дефисы
	slug = string.gsub(slug, "[%s%p]+", "-")

	-- Убираем дефисы с начала и конца
	slug = string.gsub(slug, "^%-+", "")
	slug = string.gsub(slug, "%-+$", "")

	return slug
end

---[[ ESCAPE И БЕЗОПАСНОСТЬ ]]---

-- Экранирование специальных символов для pattern matching
function StringUtils.EscapePattern(str: string): string
	return string.gsub(str, "([^%w])", "%%%1")
end

-- Экранирование HTML символов
function StringUtils.EscapeHtml(str: string): string
	local htmlEntities = {
		["&"] = "&amp;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		['"'] = "&quot;",
		["'"] = "&#39;",
	}

	local escaped = str
	for char, entity in pairs(htmlEntities) do
		escaped = StringUtils.Replace(escaped, char, entity)
	end

	return escaped
end

-- Удаление всех специальных символов (только буквы и цифры)
function StringUtils.Sanitize(str: string): string
	return string.gsub(str, "[^%w]", "")
end

---[[ АНАЛИЗ СТРОК ]]---

-- Вычисление расстояния Левенштейна между строками
function StringUtils.LevenshteinDistance(str1: string, str2: string): number
	local len1, len2 = #str1, #str2
	local matrix = {}

	-- Инициализация матрицы
	for i = 0, len1 do
		matrix[i] = {}
		matrix[i][0] = i
	end

	for j = 0, len2 do
		matrix[0][j] = j
	end

	-- Заполнение матрицы
	for i = 1, len1 do
		for j = 1, len2 do
			local cost = (string.sub(str1, i, i) == string.sub(str2, j, j)) and 0 or 1
			matrix[i][j] = math.min(
				matrix[i - 1][j] + 1, -- deletion
				matrix[i][j - 1] + 1, -- insertion
				matrix[i - 1][j - 1] + cost -- substitution
			)
		end
	end

	return matrix[len1][len2]
end

-- Вычисление схожести строк (0-1)
function StringUtils.Similarity(str1: string, str2: string): number
	local maxLen = math.max(#str1, #str2)
	if maxLen == 0 then
		return 1
	end

	local distance = StringUtils.LevenshteinDistance(str1, str2)
	return 1 - (distance / maxLen)
end

return StringUtils
