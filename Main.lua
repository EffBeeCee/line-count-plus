-- GET SERVICES (services required for script searching) --
local Selection = game:GetService("Selection")

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGUI = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local SoundService = game:GetService("SoundService")

local rblxServices = {
	Workspace = workspace,
	Players = Players,
	ReplicatedFirst = ReplicatedFirst,
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = ServerScriptService,
	ServerStorage = ServerStorage,
	StarterGUI = StarterGUI,
	StarterPack = StarterPack,
	StarterPlayer = StarterPlayer,
	SoundService = SoundService
}

-- CREATE PLUGIN BUTTON --

local toolbar = plugin:CreateToolbar("Line Count+")
local openPluginButton = toolbar:CreateButton(
	"Line Count Plus",
	"Launch line count plus",
	"rbxassetid://101738058022875"
)

-- CREATE WIDGET --

local dockWidgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	false,
	false
)

local widget = plugin:CreateDockWidgetPluginGui(
	"Line Count Plus",
	dockWidgetInfo
)

widget.Title = "Line Count+"

local GUI = script.Parent:WaitForChild("GUI")
GUI.Parent = widget

-- GET GUI --

local dataSection = GUI:FindFirstChild("Data")
local productivitySection = GUI:FindFirstChild("Productivity")

local allDataTableGUI = dataSection:FindFirstChild("DataTable")
local allDataIncludeSpacesGUI = dataSection:FindFirstChild("IncludeSpaces")
local allDataIncludeCommentsGUI = dataSection:FindFirstChild("IncludeComments")
local allDataIncludeDuplicatesGUI = dataSection:FindFirstChild("IncludeDuplicates")
local allDataLocationGUI = dataSection:FindFirstChild("Location")

local productivityTableGUI = productivitySection:FindFirstChild("DataTable")
local productivityIncludeSpacesGUI = productivitySection:FindFirstChild("IncludeSpaces")
local productivityIncludeCommentsGUI = productivitySection:FindFirstChild("IncludeComments")
local productivityRecordingGUI = productivitySection:FindFirstChild("Recording")

-- GET SAVED DATA --

-- Get settings data --
local settingsData = {}

settingsData.AllDataIncludeSpaces = plugin:GetSetting("AllDataIncludeSpaces")
settingsData.AllDataIncludeComments = plugin:GetSetting("AllDataIncludeComments")
settingsData.AllDataIncludeDuplicates = plugin:GetSetting("AllDataIncludeDuplicates")
settingsData.AllDataLocation = plugin:GetSetting("AllDataLocation")

settingsData.ProductivityIncludeSpaces = plugin:GetSetting("ProductivityIncludeSpaces")
settingsData.ProductivityIncludeComments = plugin:GetSetting("ProductivityIncludeComments")
settingsData.ProductivityRecordingNow = plugin:GetSetting("ProductivityRecordingNow")

-- Get productivity data --
local productivityData = {}

--[[ Amount created:
	{
	[1] = #scripts,
	[2] = lines,
	[3] = space lines,
	[4] = comment lines,
	[5] = characters,
	[6] = space characters,
	[7] = comment characters,
	[8] = unix time at recording start
	}
]]

productivityData.ProductivityDay = plugin:GetSetting("ProductivityDay")
productivityData.ProductivityWeek = plugin:GetSetting("ProductivityWeek")
productivityData.ProductivityMonth = plugin:GetSetting("ProductivityMonth")
productivityData.ProductivityRecording = plugin:GetSetting("ProductivityRecording")

-- UPDATE PLUGIN GUI DATA --

-- Returns the {<#regular lines>, <#comment lines>, <#space lines>, <regular chars>, <comment chars>, <space chars>} in a script as a tuple
local function GetDataFromScript(givenScript: Script)
	local TABULATION_CHARACTER = "	"
	
	local lines = string.split(givenScript.Source, "\n")
	
	-- Set up variables --
	local regularLines = 0
	local commentLines = 0
	local spaceLines = 0
	
	local regularChars = 0
	local commentChars = 0
	local spaceChars = 0
	
	-- Is the function currently indexing through a long comment (--[[<comment>]])?
	local inLongComment = false
	
	-- Is the function currently indexing through a string (disables comments syntax)?
	local inString = false
	
	-- Index through lines --
	
	for _, line in lines do
		-- Remove spaces, then check if the line starts with "--" (comment) or "--[[" (long comment)
		local lineLength = string.len(line)
		local lineWithoutSpaces = string.gsub(string.gsub(line, " ", ""), TABULATION_CHARACTER, "")
		
		-- Update line data (easy) --
		
		if string.sub(lineWithoutSpaces, 1, 2) == "--" then -- Line starts with a comment (comment line); may still contain comment later on in line though
			commentLines += 1
		elseif lineWithoutSpaces == "" then -- Blank line (space line)
			spaceLines += 1
		else -- Regular line
			regularLines += 1
		end
		
		-- Update character data (harder) --
		for charIndex = 1, lineLength do
			local char = string.sub(line, charIndex, charIndex)
			local next2Chars = string.sub(line, charIndex, charIndex + 1)
			local next4Chars = string.sub(line, charIndex, charIndex + 3)
			
			-- Check for string starting/ending --
			
			if (char == '"' or char == "'") and (not inLongComment) then
				inString = not inString -- Reverse
			end
			
			-- Check if a comment is ending --
			
			if next2Chars == "]]" and inLongComment and (not inString) then
				-- The comment ended and the script will think the "]]" is regular chars so create an offset of +2 on comment and -2 on regular
				inLongComment = false
				commentChars += 2
				regularChars -= 2
			end
			
			-- Check if a comment is starting --
			
			if next4Chars == "--[[" and (not inString) then
				inLongComment = true
			elseif next2Chars == "--" and (not inLongComment) and (not inString) then
				-- The rest of the line is a comment: add the rest of the line to the counter and break
				commentChars += lineLength - charIndex
				break
			end
			
			-- Check what type of character should be added
			
			if inLongComment then
				commentChars += 1
			elseif char == " " or char == TABULATION_CHARACTER then
				spaceChars += 1
			else
				regularChars += 1
			end
		end
	end
	
	-- Return variables --
	return regularLines, commentLines, spaceLines, regularChars, commentChars, spaceChars
end

-- Formats number with commas
local function FormatNumber(inputNumber: number)
	inputNumber = tostring(inputNumber)
	
	local isNegative = false
	
	if string.sub(inputNumber, 1, 1) == "-" then
		isNegative = true
		inputNumber = string.gsub(inputNumber, "-", "")
	end
	
	local formatted = inputNumber:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
	
	local prepend = "-"
	
	if not isNegative then prepend = "" end
	
	return prepend .. formatted
end

-- Updates the non-productivity data displayed in the GUI of the plugin
local function UpdateAllData(locationName: string, includeComments: boolean, includeSpaces: boolean, includeDuplicates: boolean)
	-- Get service(s) to loop through --
	local allDescendants: {Instance} = {}
	
	if locationName == "All" then
		for _, service in rblxServices do
			for _, descendant in service:GetDescendants() do
				table.insert(allDescendants, descendant)
			end
		end
	elseif locationName == "Selection" then
		if #Selection:Get() == 0 then return end
		
		-- First add selected instance and then add the descendants of the selected instance
		for _, selectedInstance in Selection:Get() do
			table.insert(allDescendants, selectedInstance)
			
			for _, descendant in selectedInstance:GetDescendants() do
				table.insert(allDescendants, descendant)
			end
		end
	else
		allDescendants = rblxServices[locationName]:GetDescendants()
	end
	
	-- Returns the script type (LegacyServer, LegacyLocal, Module, Server, Client, Plugin) or nil if not a script
	local function GetScriptType(instance: Instance)
		local scriptType
		
		if instance:IsA("Script") then -- LegacyServer, Server, Client, or Plugin
			if instance.RunContext == Enum.RunContext.Legacy then
				scriptType = "LegacyServer"
			elseif instance.RunContext == Enum.RunContext.Server then
				scriptType = "Server"
			elseif instance.RunContext == Enum.RunContext.Client then
				scriptType = "Client"
			elseif instance.RunContext == Enum.RunContext.Plugin then
				scriptType = "Plugin"
			end
		elseif instance:IsA("LocalScript") then -- LegacyLocal
			scriptType = "LegacyLocal"
		elseif instance:IsA("ModuleScript") then -- Module
			scriptType = "Module"
		end
		
		return scriptType
	end
	
	-- Initialize data variables --
	-- {[<ScriptType>] = {Amount, Lines, Characters}}
	local data = {LegacyServer = {}, LegacyLocal = {}, Module = {}, Server = {}, Client = {}, Plugin = {}}
	
	-- List of all scripts found within search (used to remove duplicates)
	local foundScripts = {}
	
	-- Loop through descendents --
	for _, descendant: Script in allDescendants do
		-- Get type
		local scriptType = GetScriptType(descendant)
		
		if scriptType ~= nil then
			-- Check if script is a duplicate
			local isDuplicate = false
			
			if not includeDuplicates then
				for _, foundScript in foundScripts do
					if foundScript.Source == descendant.Source then
						isDuplicate = true
					end
				end
			end
			
			table.insert(foundScripts, descendant) -- Note: must be added after search to prevent script from being detected as duplicate
			
			if not isDuplicate then
				-- Create data row if not found
				if #data[scriptType] == 0 then data[scriptType] = {0, 0, 0} end
				
				-- Get data from script
				local regularLines, commentLines, spaceLines, regularChars, commentChars, spaceChars = GetDataFromScript(descendant)
				
				-- Add extra lines/chars if specified in settings
				local lines = regularLines
				local chars = regularChars
				
				if includeComments then
					lines += commentLines
					chars += commentChars
				end
				
				if includeSpaces then
					lines += spaceLines
					chars += spaceChars
				end
				
				-- 1 new script found and added to total
				local dataRow = data[scriptType]
				
				dataRow[1] += 1
				
				dataRow[2] += lines
				
				dataRow[3] += chars
			end
		end
	end
	
	-- Display data --
	
	local dataTotal = {0, 0, 0}
	
	-- Individual script types
	for scriptType, row in pairs(data) do
		-- Update GUI
		local GUIRow = allDataTableGUI:FindFirstChild(scriptType)
		
		if not row[1] then row[1] = 0 end
		if not row[2] then row[2] = 0 end
		if not row[3] then row[3] = 0 end
		
		GUIRow:FindFirstChild("Amount").Text = FormatNumber(row[1])
		GUIRow:FindFirstChild("Lines").Text = FormatNumber(row[2])
		GUIRow:FindFirstChild("Characters").Text = FormatNumber(row[3])
		
		-- Add to total
		dataTotal[1] += row[1]
		dataTotal[2] += row[2]
		dataTotal[3] += row[3]
	end
	
	-- Total
	local totalRow = allDataTableGUI:FindFirstChild("Total")
	
	totalRow:FindFirstChild("Amount").Text = FormatNumber(dataTotal[1])
	totalRow:FindFirstChild("Lines").Text = FormatNumber(dataTotal[2])
	totalRow:FindFirstChild("Characters").Text = FormatNumber(dataTotal[3])
end

local previousProductivityData

-- Updates the productivity widget GUI
local function UpdateProductivityData(includeComments: boolean, includeSpaces: boolean, recording: boolean, resetRecording: boolean)
	-- Get instances --
	local allInstances = {}
	
	for _, service in rblxServices do
		for _, descendant in service:GetDescendants() do
			table.insert(allInstances, descendant)
		end
	end
	
	local dataNow = {
		Scripts = 0,
		RegularLines = 0,
		CommentLines = 0,
		SpaceLines = 0,
		RegularChars = 0,
		CommentChars = 0,
		SpaceChars = 0
	}
	
	for _, instance: Instance in allInstances do
		if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
			local regularLines, commentLines, spaceLines, regularChars, commentChars, spaceChars = GetDataFromScript(instance)
			
			dataNow.Scripts += 1
			dataNow.RegularLines += regularLines
			dataNow.CommentLines += commentLines
			dataNow.SpaceLines += spaceLines
			dataNow.RegularChars += regularChars
			dataNow.CommentChars += commentChars
			dataNow.SpaceChars += spaceChars
		end
	end
	
	-- Get change in data since last update
	if not previousProductivityData then previousProductivityData = dataNow end
	
	local dataChange = {}
	
	for index, data in dataNow do
		dataChange[index] = data - previousProductivityData[index]
	end
	
	-- Set previous data to data now (already used and not required anymore)
	previousProductivityData = dataNow
	
	-- Condenses line/character data into total lines and total chars using user settings
	local function GetLinesCharacters(regularLines: number, commentLines: number, spaceLines: number, regularChars: number, commentChars: number, spaceChars: number)
		local totalLines = regularLines
		local totalChars = regularChars
		
		if includeComments then
			totalLines += commentLines
			totalChars += commentChars
		end
		
		if includeSpaces then
			totalLines += spaceLines
			totalChars += spaceChars
		end
		
		return totalLines, totalChars
	end
	
	-- Returns if a new day/week/month started since the last unix epoch time. Timeframe is "Day", "Month", or "Year"
	local function TimeframeChanged(lastTime: number, timeframe: string)
		if timeframe == "Day" then
			local lastTimeDay = DateTime.fromUnixTimestamp(lastTime):FormatLocalTime("DDD", "en-us")
			local nowDay = DateTime.now():FormatLocalTime("DDD", "en-us")
			
			if lastTimeDay ~= nowDay then
				return true -- New day
			else
				return false
			end
		elseif timeframe == "Week" then
			local utcOffset = os.date("*t").hour - os.date("!*t").hour
			local utcOffsetSecs = utcOffset * 3600
			
			local zerothWeekUnixEpochTime = 86400 * 4 -- Unix epoch was on a thursday (offset to monday)
			local lastTimeUnixEpochWeeks = math.floor(((lastTime + zerothWeekUnixEpochTime + utcOffset) / 86400) / 7)
			local nowUnixEpochWeeks = math.floor(((os.time() + zerothWeekUnixEpochTime + utcOffset) / 86400) / 7)
			
			if lastTimeUnixEpochWeeks ~= nowUnixEpochWeeks then
				return true -- New week
			else
				return false
			end
		else
			local lastTimeMonth = DateTime.fromUnixTimestamp(lastTime):FormatLocalTime("M", "en-us")
			local nowMonth = DateTime.now():FormatLocalTime("M", "en-us")
			
			if lastTimeMonth ~= nowMonth then
				return true -- New month
			else
				return false
			end
		end
	end
	
	-- For use in case a new day/week/month has started (all zeros ending with unix time)
	local defaultIndexedTable = {}
	
	for index = 1, 7 do
		defaultIndexedTable[index] = 0
	end
	
	defaultIndexedTable[8] = os.time()
	
	-- Returns the totals for scripts/lines/chars added within the timeframe and the new data table
	local function GetProductivity(previousTotal: {})
		local linesChange, charsChange = GetLinesCharacters(
			dataChange.RegularLines,
			dataChange.CommentLines,
			dataChange.SpaceLines,
			dataChange.RegularChars,
			dataChange.CommentChars,
			dataChange.SpaceChars
		)
		
		local scriptsChange = dataChange.Scripts
		
		local previousTotalLines, previousTotalChars = GetLinesCharacters(
			previousTotal[2],
			previousTotal[3],
			previousTotal[4],
			previousTotal[5],
			previousTotal[6],
			previousTotal[7]
		)
		
		local previousTotalScripts = previousTotal[1]
		
		-- Get data factoring in settings
		local newTotalScripts = previousTotalScripts + scriptsChange
		local newTotalLines = previousTotalLines + linesChange
		local newTotalChars = previousTotalChars + charsChange
		
		-- Get data without factoring in settings
		local newTotal = {
			previousTotalScripts + scriptsChange,
			dataChange.RegularLines + previousTotal[2],
			dataChange.CommentLines + previousTotal[3],
			dataChange.SpaceLines + previousTotal[4],
			dataChange.RegularChars + previousTotal[5],
			dataChange.CommentChars + previousTotal[6],
			dataChange.SpaceChars + previousTotal[7],
			previousTotal[8]
		}
		
		return newTotalScripts, newTotalLines, newTotalChars, newTotal
	end
	
	-- Update day timeframe GUI --
	
	local dayData = productivityData.ProductivityDay
	
	if not dayData then
		dayData = defaultIndexedTable
		productivityData.ProductivityDay = dayData
		plugin:SetSetting("ProductivityDay", productivityData.ProductivityDay)
	end
	
	-- Check if a new day started
	local unixTimeOfDayStart = dayData[8]
	local newDay = TimeframeChanged(unixTimeOfDayStart, "Day")
	
	if newDay then
		dayData = defaultIndexedTable
		productivityData.ProductivityDay = dayData
		plugin:SetSetting("ProductivityDay", productivityData.ProductivityDay)
	end
	
	local dayScripts, dayLines, dayChars, dayAllData = GetProductivity(dayData)
	
	productivityData.ProductivityDay = dayAllData
	plugin:SetSetting("ProductivityDay", productivityData.ProductivityDay)
	
	-- Update GUI
	local daySection = productivityTableGUI:FindFirstChild("Day")
	
	daySection:FindFirstChild("Amount").Text = FormatNumber(dayScripts)
	daySection:FindFirstChild("Lines").Text = FormatNumber(dayLines)
	daySection:FindFirstChild("Characters").Text = FormatNumber(dayChars)
	
	-- Update week timeframe GUI --
	
	local weekData = productivityData.ProductivityWeek
	
	if not weekData then
		weekData = defaultIndexedTable
		productivityData.ProductivityWeek = weekData
		plugin:SetSetting("ProductivityWeek", productivityData.ProductivityWeek)
	end
	
	local unixTimeOfWeekStart = weekData[8]
	local newWeek = TimeframeChanged(unixTimeOfWeekStart, "Week")
	
	if newWeek then
		weekData = defaultIndexedTable
		productivityData.ProductivityWeek = weekData
		plugin:SetSetting("ProductivityWeek", productivityData.ProductivityWeek)
	end

	local weekScripts, weekLines, weekChars, weekAllData = GetProductivity(weekData)

	productivityData.ProductivityWeek = weekAllData
	plugin:SetSetting("ProductivityWeek", productivityData.ProductivityWeek)

	-- Update GUI
	local weekSection = productivityTableGUI:FindFirstChild("Week")

	weekSection:FindFirstChild("Amount").Text = FormatNumber(weekScripts)
	weekSection:FindFirstChild("Lines").Text = FormatNumber(weekLines)
	weekSection:FindFirstChild("Characters").Text = FormatNumber(weekChars)
	
	-- Update month timeframe GUI --
	
	local monthData = productivityData.ProductivityMonth
	
	if not monthData then
		monthData = defaultIndexedTable
		productivityData.ProductivityMonth = monthData
		plugin:SetSetting("ProductivityMonth", productivityData.ProductivityMonth)
	end
	
	local unixTimeOfMonthStart = monthData[8]
	local newMonth = TimeframeChanged(unixTimeOfMonthStart, "Month")
	
	if newMonth then
		monthData = defaultIndexedTable
		productivityData.ProductivityMonth = monthData
		plugin:SetSetting("ProductivityMonth", productivityData.ProductivityMonth)
	end

	local monthScripts, monthLines, monthChars, monthAllData = GetProductivity(monthData)
	
	productivityData.ProductivityMonth = monthAllData
	plugin:SetSetting("ProductivityMonth", productivityData.ProductivityMonth)

	-- Update GUI
	local monthSection = productivityTableGUI:FindFirstChild("Month")

	monthSection:FindFirstChild("Amount").Text = FormatNumber(monthScripts)
	monthSection:FindFirstChild("Lines").Text = FormatNumber(monthLines)
	monthSection:FindFirstChild("Characters").Text = FormatNumber(monthChars)
	
	-- Update recording GUI --
	
	local recordingData = productivityData.ProductivityRecording
	
	if resetRecording or (not recordingData) then
		recordingData = defaultIndexedTable
		productivityData.ProductivityRecording = recordingData
		plugin:SetSetting("ProductivityRecording", productivityData.ProductivityRecording)
	end
	
	if recording or resetRecording then
		local recordingScripts, recordingLines, recordingChars, recordingAllData = GetProductivity(recordingData)
		
		productivityData.ProductivityRecording = recordingAllData
		plugin:SetSetting("ProductivityRecording", productivityData.ProductivityRecording)
		
		-- Update GUI
		local recordingSection = productivityTableGUI:FindFirstChild("Recording")

		recordingSection:FindFirstChild("Amount").Text = FormatNumber(recordingScripts)
		recordingSection:FindFirstChild("Lines").Text = FormatNumber(recordingLines)
		recordingSection:FindFirstChild("Characters").Text = FormatNumber(recordingChars)
	end
end

-- LISTEN FOR SETTINGS CLICKS --

-- Listens for settings clicks and updates/saves them
local function ListenForSettingsClicks()
	-- RBLX assets --
	
	local CHECKBOX_CHECKED_ID = "rbxassetid://76303270887070"
	local CHECKBOX_UNCHECKED_ID = "rbxassetid://115676850649048"
	
	local function GetCheckboxID(checked: boolean)
		if checked then
			return CHECKBOX_CHECKED_ID
		else
			return CHECKBOX_UNCHECKED_ID
		end
	end
	
	-- All data GUI --
	
	local allDataIncludeSpaces = settingsData.AllDataIncludeSpaces
	local allDataIncludeComments = settingsData.AllDataIncludeComments
	local allDataIncludeDuplicates = settingsData.AllDataIncludeDuplicates
	local allDataLocation = settingsData.AllDataLocation
	
	if allDataIncludeSpaces == nil then allDataIncludeSpaces = true end
	if allDataIncludeComments == nil then allDataIncludeComments = true end
	if allDataIncludeDuplicates == nil then allDataIncludeDuplicates = true end
	if allDataLocation == nil then allDataLocation = "All" end
	
	UpdateAllData(allDataLocation, allDataIncludeComments, allDataIncludeSpaces, allDataIncludeDuplicates) -- Initial run
	
	-- Include spaces --
	
	local allDataIncludeSpacesCheckbox = allDataIncludeSpacesGUI:FindFirstChild("Checkbox")
	
	allDataIncludeSpacesCheckbox.Image = GetCheckboxID(allDataIncludeSpaces)
	
	allDataIncludeSpacesCheckbox.MouseButton1Click:Connect(function()
		-- Update stored data
		allDataIncludeSpaces = not allDataIncludeSpaces
		plugin:SetSetting("AllDataIncludeSpaces", allDataIncludeSpaces)
		
		-- Update GUI
		allDataIncludeSpacesCheckbox.Image = GetCheckboxID(allDataIncludeSpaces)
		
		UpdateAllData(allDataLocation, allDataIncludeComments, allDataIncludeSpaces, allDataIncludeDuplicates)
	end)
	
	-- Include comments --
	
	local allDataIncludeCommentsCheckbox = allDataIncludeCommentsGUI:FindFirstChild("Checkbox")
	
	allDataIncludeCommentsCheckbox.Image = GetCheckboxID(allDataIncludeComments)

	allDataIncludeCommentsCheckbox.MouseButton1Click:Connect(function()
		-- Update stored data
		allDataIncludeComments = not allDataIncludeComments
		plugin:SetSetting("AllDataIncludeComments", allDataIncludeComments)

		-- Update GUI
		allDataIncludeCommentsCheckbox.Image = GetCheckboxID(allDataIncludeComments)
		
		UpdateAllData(allDataLocation, allDataIncludeComments, allDataIncludeSpaces, allDataIncludeDuplicates)
	end)
	
	-- Include duplicates --
	
	local allDataIncludeDuplicatesCheckbox = allDataIncludeDuplicatesGUI:FindFirstChild("Checkbox")
	
	allDataIncludeDuplicatesCheckbox.Image = GetCheckboxID(allDataIncludeDuplicates)
	
	allDataIncludeDuplicatesCheckbox.MouseButton1Click:Connect(function()
		-- Update stored data
		allDataIncludeDuplicates = not allDataIncludeDuplicates
		plugin:SetSetting("AllDataIncludeDuplicates", allDataIncludeDuplicates)
		
		-- Update GUI
		allDataIncludeDuplicatesCheckbox.Image = GetCheckboxID(allDataIncludeDuplicates)

		UpdateAllData(allDataLocation, allDataIncludeComments, allDataIncludeSpaces, allDataIncludeDuplicates)
	end)
	
	-- Location --
	
	local allLocations = {
		"Workspace",
		"Players",
		"ReplicatedFirst",
		"ReplicatedStorage",
		"ServerScriptService",
		"ServerStorage",
		"StarterGUI",
		"StarterPack",
		"StarterPlayer",
		"SoundService",
		"All",
		"Selection"
	}
	
	local allDataLocationIndex = table.find(allLocations, allDataLocation)
	
	local allDataLocationLeft = allDataLocationGUI:FindFirstChild("SelectLeftTriangle")
	local allDataLocationRight = allDataLocationGUI:FindFirstChild("SelectRightTriangle")
	
	allDataLocationGUI:FindFirstChild("Location").Text = allDataLocation
	
	-- Updates the location index and displays the new GUI data
	local function UpdateLocationIndex(indexChange: number)
		-- Update setting
		allDataLocationIndex += indexChange
		
		if allDataLocationIndex > #allLocations then -- Went past max limit; go back to start
			allDataLocationIndex = 1
		elseif allDataLocationIndex < 1 then -- Went past min limit; cycle to end
			allDataLocationIndex = #allLocations
		end
		
		local location = allLocations[allDataLocationIndex]
		allDataLocation = location
		
		plugin:SetSetting("AllDataLocation", location)
		
		-- Update GUI
		allDataLocationGUI:FindFirstChild("Location").Text = location
		
		UpdateAllData(allDataLocation, allDataIncludeComments, allDataIncludeSpaces, allDataIncludeDuplicates)
	end
	
	allDataLocationRight.MouseButton1Click:Connect(function()
		UpdateLocationIndex(1)
	end)
	
	allDataLocationLeft.MouseButton1Click:Connect(function()
		UpdateLocationIndex(-1)
	end)
	
	Selection.SelectionChanged:Connect(function()
		if allDataLocation == "Selection" then
			UpdateAllData(allDataLocation, allDataIncludeComments, allDataIncludeSpaces, allDataIncludeDuplicates)
		end
	end)
	
	-- Productivity GUI --
	
	local productivityIncludeSpaces = settingsData.ProductivityIncludeSpaces
	local productivityIncludeComments = settingsData.ProductivityIncludeComments
	local recordingNow = settingsData.ProductivityRecordingNow
	
	if productivityIncludeSpaces == nil then productivityIncludeSpaces = true end
	if productivityIncludeComments == nil then productivityIncludeComments = true end
	if recordingNow == nil then recordingNow = true end
	
	UpdateProductivityData(productivityIncludeComments, productivityIncludeSpaces, recordingNow, false)
	
	-- Include spaces --
	
	local productivityIncludeSpacesCheckbox = productivityIncludeSpacesGUI:FindFirstChild("Checkbox")
	
	productivityIncludeSpacesCheckbox.Image = GetCheckboxID(productivityIncludeSpaces)
	
	productivityIncludeSpacesCheckbox.MouseButton1Click:Connect(function()
		-- Update stored data
		productivityIncludeSpaces = not productivityIncludeSpaces
		plugin:SetSetting("ProductivityIncludeSpaces", productivityIncludeSpaces)

		-- Update GUI
		productivityIncludeSpacesCheckbox.Image = GetCheckboxID(productivityIncludeSpaces)

		UpdateProductivityData(productivityIncludeComments, productivityIncludeSpaces, recordingNow, false)
	end)
	
	-- Include comments --
	
	local productivityIncludeCommentsCheckbox = productivityIncludeCommentsGUI:FindFirstChild("Checkbox")
	
	productivityIncludeCommentsCheckbox.Image = GetCheckboxID(productivityIncludeComments)
	
	productivityIncludeCommentsCheckbox.MouseButton1Click:Connect(function()
		-- Update stored data
		productivityIncludeComments = not productivityIncludeComments
		plugin:SetSetting("ProductivityIncludeComments", productivityIncludeComments)

		-- Update GUI
		productivityIncludeCommentsCheckbox.Image = GetCheckboxID(productivityIncludeComments)

		UpdateProductivityData(productivityIncludeComments, productivityIncludeSpaces, recordingNow, false)
	end)
	
	-- Recording --
	
	local productivityRecordStartStop = productivityRecordingGUI:FindFirstChild("StartStop")
	local productivityRecordReset = productivityRecordingGUI:FindFirstChild("Reset")
	
	-- Returns "Start" or "Stop" based on the recording status
	local function GetStartStopButtonText()
		if recordingNow then
			return "Stop"
		else
			return "Start"
		end
	end
	
	productivityRecordStartStop.Text = GetStartStopButtonText()
	
	-- Start/stop recording
	productivityRecordStartStop.MouseButton1Click:Connect(function()
		recordingNow = not recordingNow
		plugin:SetSetting("ProductivityRecordingNow", recordingNow)
		
		productivityRecordStartStop.Text = GetStartStopButtonText()
		
		UpdateProductivityData(productivityIncludeComments, productivityIncludeSpaces, recordingNow, false)
	end)
	
	-- Reset
	productivityRecordReset.MouseButton1Click:Connect(function()
		recordingNow = false
		
		productivityRecordStartStop.Text = GetStartStopButtonText()
		
		UpdateProductivityData(productivityIncludeComments, productivityIncludeSpaces, recordingNow, true)
	end)
	
	-- Auto-update (every 2 seconds) --
	
	task.spawn(function()
		while true do
			UpdateAllData(allDataLocation, allDataIncludeComments, allDataIncludeSpaces, allDataIncludeDuplicates)
			UpdateProductivityData(productivityIncludeComments, productivityIncludeSpaces, recordingNow, false)
			
			task.wait(2)
		end
	end)
end

ListenForSettingsClicks()

-- OPEN GUI --

-- Toggles the GUI visibility
local function OpenButtonClick()
	widget.Enabled = not widget.Enabled -- Open=close; close=open
end

openPluginButton.Click:Connect(OpenButtonClick)
