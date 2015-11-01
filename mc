--[[
  MiniatureCraft, a game by Detective_Smith
  Current Version: 2.0.52

  This game is under the Creative Commons Attribution-NonCommercial 4.0 
  International Public License which basically means that you are free to:

  Share - copy and redistribute the material in any medium or format
  Adapt - remix, transform, and build upon the material

  Under the following terms:
  
  Attribution - You must give appropriate credit, provide a link to the license, 
  and indicate if changes were made. You may do so in any reasonable manner, but 
  not in any way that suggests the licensor endorses you or your use.
  
  NonCommercial - You may not use the material for commercial purposes.
  
  No additional restrictions - You may not apply legal terms or technological measures 
  that legally restrict others from doing anything the license permits.

  Enjoy and have fun! :D
--]]

--[[
	
	Awesome Ideas:

	-- Save world seed. Only save chunks which were modified. Would save a TON of space.
	   Biome maps can be saved along with the seed for speedups.
	   Perhaps only save the changes made to said chunk? Nah, going too far.

	-- Add internal permissions system

	-- Perhaps remove File API, and replace with Client & Server API?

	-- Server connecting can work like this:
	Password can have os.day()..os.time() added to the end of it, then encrypt request

	-- Biomes: Work like this.
	A function to create a biome map. It doesn't have to be part of the initial world generation.
	Simply needs to be a map of the whole world with a number assigned to each block's biome.
	Saving biome maps should be really simple. Have only up to 16 biomes, and save a number for each as an id.
		
		E.X: 0 = Plains, 1 = Desert, etc.
	
	When saving, simplying allocate one byte for two blocks. Then run it through the good 'ol compressor.
	Using this, your average, 64x64 biome map should be 2 kilobytes at most.

	-- Key bindings.

	It generates the biomes in terms of chunks. After that, it runs a "leak" function as to spread a biome.
	Makes it look lessy blocking sense it does it chunk by chunk first.

	Current Changes:

	-- Chat.addCommand(cmdName, function)
	-- New start screen splash text.
	-- New, easier error logging (with little messages in each error log).
	-- require() function for use with mods and APIs. unload() removes any loaded files from memory.
	-- reportError() function, which I need to tweak a bit.
	-- 4 New Apis:
	   Client, Server, Keyboard, & Timer
	
	-----------------------------------------------------------------------------------------------------------

	TODO:

	Add dungeons & Villages and stuffs
	Make lighting more realisitc

	draw heavy inspiration from the actual game. does things a lot more easily.

	make ender pearl type thing
	first wall it hits it tps you to

	give items a interactOn() function.
	called whenever an item is used.
	
	just have chat API draw hud on tick() function

	signs!

	interactOn(player, dim, x, y)
	onTake(player, dim, x, y) -- ran when something is picked up
	tick() function for all assets
	isHit() function for blocks/tiles
--]]

local tArgs = {...}
if not term.isColor() then error("Advanced Computer Required to Play.", 2) end

local ScreenWidth, ScreenHeight = term.getSize()
local debugMode, hideGUI = false, true

local MainFolder = shell.getRunningProgram():sub(1, #shell.getRunningProgram() - #fs.getName(shell.getRunningProgram()))
local APIFolder, ModsFolder, SavesFolder = MainFolder.. "/API/", MainFolder.. "/Mods/", MainFolder.. "/Saves/"

local errorText = {"Looks like jimmy had an accident.", "'Ha. I bet this text is red.'", "Uh-oh.", "That wasn't supposed to happen.", "Why.", "omgagain???", "Just your typical error message.", "Fix it already!", "get rekt", "By reading this, you've wasted time you could've been using fixing the error.", "What's the point of this text again?", "lol", "Dang it, make the game better!", "It was the chair!", "It wasn't me!", "Stop crashing the game!", "Fun.", "Yep.", "Sigh.", "Always with the errors.", "Blame Det.", "AN ERROR HAS OCCURED", "BSOD.", "Gosh darnit!", "Always with the crashes.", "Look at the error, not me.", "How could you!?", "Now with Beach Balls of Death."}
local loadedFiles = {}

_G.reportError = function(fileName, err)
	local errs = {}; for s in string.gmatch(err, "([^:]+)") do errs[#errs + 1] = s end
	local filen = {}; for s in string.gmatch(fileName, "([^/]+)") do filen[#filen + 1] = s end
	local errlog = MainFolder.."errors/"..filen[#filen].."_err"; fs.delete(errlog);
	local file = fs.open(errlog, "w"); math.randomseed(os.time())
	file.writeLine("\\\\ " ..errorText[math.random(#errorText)])
	file.writeLine("Error log generated on day " ..os.day().. " at " ..textutils.formatTime(os.time()).. ".\n")
	file.writeLine("Looks like the error occured on line " ..(errs[2] or "?").. ".\nHere's what went wrong: ")
	file.writeLine("\n  " ..(errs[3] or "MISSING_ERROR_MESSAGE").. "\n\nYou should probably report this error.")
	file.close(); loadedFiles = nil; _G.require = nil; _G.reportError = nil; _G.unload = nil; error(err) 
end

_G.require = function(fileName)
	if loadedFiles[fileName] then return loadedFiles[fileName] end
	if not fs.exists(MainFolder..fileName) then reportError(fileName, "error:n/a: the file " ..MainFolder..fileName.. " does not exist.") end
	local ok, err = loadfile(MainFolder..fileName); if not ok then reportError(fileName, err) end
	local ok, loadedTable = pcall(ok, MainFolder); if not ok then reportError(fileName, loadedTable) end
	loadedFiles[fileName] = type(loadedTable) == "table" and loadedTable or reportError(fileName, fileName.. ":n/a: this file must return a table")
	return loadedFiles[fileName]
end

_G.unload = function(fileName)
	loadedFiles[fileName] = nil
end

local Assets = require "Assets"
local Level = require "API/Level"
local Client = require "API/Client"
local Buffer = require "API/Buffer"
local Chat = require "API/Chat"
local Crafting = require "API/Crafting"
local Player = require "API/Player"
local Entity = require "API/Entity"
local Timer = require "API/Timer"
local Keyboard = require "API/Keyboard"
local Interface = require "API/Interface"
local Keybindings = require "API/Keybindings"

local floor, ceil = math.floor, math.ceil
local tick = os.startTimer(0.05)
local viewWidth = ceil(ScreenWidth*0.0625)
local viewHeight = ceil(ScreenHeight*0.0625)
local player = Player.new(tArgs[1] or "Player", {color = colors[tArgs[2]], x = tonumber(tArgs[3]), y = tonumber(tArgs[4])})
local ox, oy = floor(ScreenWidth*.5 + 0.5), floor(ScreenHeight*.5 + 0.5)
local currentAsset = 1

--[[ Some example Shaders
-- Confetti
Buffer.shader(function(pixel, x, y)
	return pixel[1], math.random(50) == 1 and 2 ^ math.random(0, 15) or pixel[2], pixel[3]
end)

-- Reverse
local reverse = {[1] = 32768, [2] = 16384, [4] = 8192, [8] = 4096, [16] = 2048, [32] = 1024, [64] = 512, [128] = 256, [256] = 128, [512] = 64, [1024] = 32, [2048] = 16, [4096] = 8, [8192] = 4, [16384] = 2, [32768] = 1}
Buffer.shader(function(pixel, x, y)
	return reverse[ pixel[1] ], reverse[ pixel[2] ], pixel[3]
end)

-- Grayscale
local grayscale = {[4096] = 32768, [16384] = 32768, [1024] = 32768, [2048] = 128, [8192] = 128, [4] = 128, [2] = 256, [64] = 256, [512] = 256, [16] = 1, [32] = 1, [8] = 1}
Buffer.shader(function(pixel, x, y)
	return grayscale[ pixel[1] ] or pixel[1], grayscale[ pixel[2] ] or pixel[2], pixel[3]
end)
--]]

local Screen = Buffer.getScreen()
local colorChange = {[1] = 256, [2] = 16384, [4] = 1024, [8] = 512, [16] = 2, [32] = 8192, [64] = 4, [128] = 32768, [256] = 128, [512] = 2048, [1024] = 4, [2048] = 512, [4096] = 128, [8192] = 32, [16384] = 4096, [32768] = 128}
local function drawWorld()
	for y = 2, 17 do
		local Screen_Y = Screen[y]
		for x = 1, ScreenWidth do 
			local pixel = Screen_Y[x]
			pixel[1], pixel[2], pixel[3] = Level.getTexture(0, x - ox + player.x, y - oy + player.y)
		end
	end

	local direction = player.dir; local pixel = Screen[oy][ox]
	pixel[2] = pixel[1] ~= player.color and player.color or colorChange[player.color]
	pixel[3] = (direction == 1 and "^") or (direction == 2 and ">") or (direction == 3 and "V") or "<"
	Buffer.setCursorPos(ox - floor(#player.name * 0.5), oy - 2)
	Buffer.setBackgroundColor(colors.gray); Buffer.setTextColor(colors.white)
	Buffer.write(player.name)
	Buffer.draw()
end

local function drawGUI()
	Buffer.setBackgroundColor(colors.black)
	Buffer.setCursorPos(3, 18)
	Buffer.clearLine()
	Buffer.setTextColor(colors.yellow)
	Buffer.write("MiniatureCraft " ..Assets.getVersion())

	local str = "X: " ..player.x.. ", Y: " ..player.y
	Buffer.setCursorPos(ScreenWidth - #str - 1, 18)
	Buffer.setTextColor(colors.white)
	Buffer.write(str)

	Buffer.setCursorPos(3, 19)
	Buffer.clearLine()
	Buffer.setCursorPos(33, 19)
	Buffer.write("Press 'e' to exit")
	Buffer.setCursorPos(3, 19)
	Buffer.setTextColor(colors.lightGray)
	Buffer.write("Selected: ")
	Buffer.setTextColor(colors.white)
	local asset = Assets[currentAsset]
	Buffer.write("[" ..currentAsset.. "] " ..(asset and asset.name or "None").. " ")
	local bg, fg, tc = asset and asset.texture[1] or colors.black, asset and asset.texture[2] or colors.black, asset and asset.texture[3] or " "
	Buffer.setBackgroundColor(bg)
	Buffer.setTextColor(fg)
	Buffer.write(tc)
	Buffer.draw()
end

drawWorld(); drawGUI()
local mods = Client.getMods()
while true do
	local event, par1, par2, par3 = coroutine.yield(); local x, y = player.x, player.y
	local cx, cy = floor((x - ox - 1) * 0.0625), floor((y - oy - 1) * 0.0625)

	if event == "timer" then
		tick = os.startTimer(0.05)
		for i = 1, #mods do 
			--player.color = 2 ^ math.random(15)
			mods[i].Tick() 
		end

		for vy = 0, viewHeight do
			for vx = 0, viewWidth do
				Level.updateChunk(0, cx + vx, cy + vy)
			end
		end
		drawWorld()

	elseif event == "key" or event == "key_up" then
		Keyboard.updateKeys(event, par1, par2)

		if Keyboard.isDown(Keybindings.up) then player:direction(1); player.y = player.y - (Level.checkForCollision(0, x, y - 1) and 0 or 1) end
		if Keyboard.isDown(Keybindings.left) then player:direction(4); player.x = player.x - (Level.checkForCollision(0, x - 1, y) and 0 or 1) end
		if Keyboard.isDown(Keybindings.down) then player:direction(3); player.y = player.y + (Level.checkForCollision(0, x, y + 1) and 0 or 1) end
		if Keyboard.isDown(Keybindings.right) then player:direction(2); player.x = player.x + (Level.checkForCollision(0, x + 1, y) and 0 or 1) end
		if Keyboard.isDown(Keybindings.lock) then player.lock = not player.lock end

		if Keyboard.isDown(keys.r) then Level.unloadChunk(0) end
		if Keyboard.isDown(keys.e) then break end

		for vy = 0, viewHeight do
			for vx = 0, viewWidth do
				Level.loadChunk(0, cx + vx, cy + vy)
			end
		end
		drawGUI(); drawWorld()

	elseif event == "mouse_scroll" then
		currentAsset = currentAsset - par1
		if currentAsset < 1 then currentAsset = 74 end
		if currentAsset > 74 then currentAsset = 1 end
		drawGUI()

	elseif event == "mouse_click" or event == "mouse_drag" then
		if par1 == 1 then
			local asset = Assets[currentAsset]
			if asset then
				local isTile = asset.type == "tile" or asset.type == "liquid"
				Level.data(0, par2 + x - ox, par3 + y - oy, isTile and currentAsset, _, not isTile and currentAsset)
			end
		elseif par1 == 2 then
			Level.data(0, par2 + x - ox, par3 + y - oy, _, _, false)
		elseif par1 == 3 then
			local spot = Level.data(0, par2 + x - ox, par3 + y - oy)
			currentAsset = (spot and spot[5] or spot[1]) or currentAsset 
			drawGUI()
		end
		drawWorld()
	end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.yellow)
term.clear(); term.setCursorPos(1,1)
print("Thanks for playing MiniatureCraft " ..Assets.getVersion().. "! Hope you enjoyed it! (Created by Detective_Smith)")
term.setTextColor(colors.white); print()

--local ip, port = 29, 25565
--if Client.connect(ip, port) then print("Join successful!") else print("No response.") end