--[[
  MiniatureCraft, a game by Detective_Smith
  Current Version: 1.98b-Beta

  This game is under the Creative Commons Attribution-NonCommercial 4.0 
  International Public License which basically means that you are free to:

  Share — copy and redistribute the material in any medium or format
  Adapt — remix, transform, and build upon the material

  Under the following terms:
  
  Attribution — You must give appropriate credit, provide a link to the license, 
  and indicate if changes were made. You may do so in any reasonable manner, but 
  not in any way that suggests the licensor endorses you or your use.
  
  NonCommercial — You may not use the material for commercial purposes.
  
  No additional restrictions — You may not apply legal terms or technological measures 
  that legally restrict others from doing anything the license permits.

  Enjoy and have fun! :D
--]]

if not term.isColor() then error("Advanced Computer Required to Play.", 2) end

local decToHex = {[1] = "0", [2] = "1", [4] = "2", [8] = "3", [16] = "4", [32] = "5", [64] = "6", [128] = "7", [256] = "8", [512] = "9", [1024] = "a", [2048] = "b", [4096] = "c", [8192] = "d", [16384] = "e", [32768] = "f"}
local ScreenWidth, ScreenHeight = term.getSize()
local debugMode, hideGUI = false, true
local multiplayer = false
local askForUpdate = false
local targetFPS = 20 -- Sets the target FPS you want the game to run at. Of course, anything above 20 wouldn't work, as 20 is the max always.
local checkForUpdates = true
 
local MainFolder = shell.getRunningProgram():sub(1, #shell.getRunningProgram() - #fs.getName(shell.getRunningProgram()))
local APIFolder, ModsFolder, SavesFolder = MainFolder.. "/API", MainFolder.. "/Mods", MainFolder.. "/Saves"
if MainFolder == "" then MainFolder = "/" end

dofile(APIFolder.. "/Buffer")
_G.Screen = Buffer.createBuffer()
term.redirect(Screen)

_G.nativeError = error
_G.nativePrintError = printError
_G.error = function(...)
  fs.delete(MainFolder.. "errorlog")
  local file = fs.open(MainFolder.. "errorlog", "w")
  file.writeLine(...); file.close()
  --_G.nativeError()
end
_G.printError = _G.error

dofile(MainFolder.. "/Assets")
for n, sFile in ipairs(fs.list(APIFolder)) do dofile(APIFolder.. "/" ..sFile) end; File.loadMods()
local World = Level.newWorld(ScreenWidth, ScreenHeight); Level.setWorld(World)
local Width, Height = Level.getSize()
local Assets = File.loadAssets()
local OffsetX, OffsetY = 0, 0

-- Various Timers for the World
local drawUpdateTimer = os.startTimer(0.5)
local saveWorldTimer = os.startTimer(300)

local currentPlayer = Player.getCurrentPlayer()
local currentTime
local currentInterface = false
local selectedAsset = 1
local Dimension = 0
local PlayerX, PlayerY = 0, 0 

if checkForUpdates and http then
  local latestVersion = http.get("http://pastebin.com/raw.php?i=N2FmL2Q7")
  if not latestVersion then return end
  if latestVersion.readAll() ~= File.getVersion() then askForUpdate = true end
  latestVersion.close()
  
  if askForUpdate then
    Screen.setBackgroundColor(colors.black); Screen.setTextColor(colors.white)
    Screen.clear(); Screen.setCursorPos(1, 1); Screen.write("Updating... "); Screen.drawScreen()
    print("Grabbing Installer."); Screen.drawScreen()
    local updater = http.get("http://pastebin.com/raw.php?i=FgAggvy1")
    local tempFile = fs.open(MainFolder.. "/.tempUpdater", "w")
    tempFile.write(updater.readAll())
    tempFile.close()
    print("Installer Downloaded. Running"); Screen.drawScreen()
    shell.run(MainFolder.. "/.tempUpdater", MainFolder)
    print("Update Complete. Deleting Installer."); Screen.drawScreen()
    fs.delete(MainFolder.. "/.tempUpdater")
    shell.run(MainFolder.. "mc"); nativeError()
  end
end

local draw = Screen.drawScreen
local startFrame, startTick = os.clock(), os.clock()
local endFrame, endTick = os.clock(), os.clock()
if targetFPS > 20 then targetFPS = 20 elseif targetFPS < 1 then targetFPS = 1 end
local clientTick = 1 / targetFPS 
_G.Screen.drawScreen = function()
  local currentTime = os.clock()
  if debugMode then
    local AssetName = Assets[selectedAsset]
    if AssetName then AssetName = AssetName.name else AssetName = "None" end
    Screen.setBackgroundColor(colors.gray); Screen.setTextColor(colors.white); Screen.setCursorPos(1, 1)
    local FrameDifference, UpdateDifference = startFrame - endFrame, startTick - endTick
    if FrameDifference == 0 then FrameDifference = clientTick end; if UpdateDifference == 0 then UpdateDifference = clientTick end
    if Player.getMode(currentPlayer) == 0 then Screen.write("FPS: " ..string.sub(1 / FrameDifference, 1, 2).. ", UPS: " ..string.sub(1 / UpdateDifference, 1, 2).. ", Time: " ..textutils.formatTime(Level.getTime()))
    else Screen.write("FPS: " ..string.sub(1 / FrameDifference, 1, 2).. ", UPS: " ..string.sub(1 / UpdateDifference, 1, 2).. ", Time: " ..textutils.formatTime(Level.getTime()).. ", T: " ..AssetName.. ":" ..selectedAsset) end
  end
  draw()
end

local function updateGame()
  OffsetX, OffsetY = Level.getOffset()
  Dimension = Player.getDimension(currentPlayer) or demoDimension
  Level.updateArea(Dimension, OffsetX, OffsetY, OffsetX + ScreenWidth, OffsetY + ScreenHeight) 

  local newTime = Level.getTime() + (clientTick / targetFPS) / 2
  if newTime >= 25 then newTime = 1 end; Level.setTime(newTime)

  local entities = Entity.getEntities()
  for i = 1, #entities do
    if entities[i] and entities[i].currentDim == Dimension then 
      if entities[i].script then entities[i].script(i) end
    end
  end
end

local demoDimension = math.random(-3, 0)
local function updateScreen()
  OffsetX, OffsetY = Level.getOffset()
  Dimension = Player.getDimension(currentPlayer) or demoDimension
  local lMap = Level.getLightingMap()

  -- Draws the initial world, directly interfaces with the buffer --
  for y = 1, ScreenHeight do 
    local textLine, tColorLine, bColorLine = "", "", ""
    for x = 1, ScreenWidth do 
      local mx, my = x + OffsetX, y + OffsetY
      if mx > Width then mx = Width end
      if mx < 0 then mx = 0 end
      if my > Height then my = Height end
      if my < 0 then my = 0 end
      if Level.isInGame() and lMap[Dimension] and not(lMap[Dimension][mx] and lMap[Dimension][mx][my]) then
        bColorLine = bColorLine.. "" ..decToHex[colors.black]
        tColorLine = tColorLine.. "" ..decToHex[colors.black]
        textLine = textLine.. " "
      else
        local background, foreground, symbol = Level.getTexture(Dimension, mx, my, useAnimations)
        if lMap[Dimension] and lMap[Dimension][mx] and lMap[Dimension][mx][my] and type(lMap[Dimension][mx][my]) == "string" then symbol = lMap[Dimension][mx][my]; foreground = colors.black end
        if type(background) == "number" then bColorLine = bColorLine.. "" ..decToHex[background] else bColorLine = bColorLine.. "" ..decToHex[colors.purple] end 
        if type(foreground) == "number" then tColorLine = tColorLine.. "" ..decToHex[foreground] else tColorLine = tColorLine.. "" ..decToHex[colors.black] end
        if type(symbol) == "string" then textLine = textLine.. "" ..symbol else textLine = textLine.. "#" end 
      end
    end
    _G.Screen.textScreen[y] = textLine
    _G.Screen.textColor[y] = tColorLine
    _G.Screen.backColor[y] = bColorLine
  end

  local entities = Entity.getEntities()
  for i = 1, #entities do
    if entities[i] and entities[i].currentDim == Dimension then 
      local CursorPosX, CursorPosY = entities[i].coordinates[1], entities[i].coordinates[2]
      local backColor = Level.getTexture(Dimension, CursorPosX, CursorPosY, useAnimations) or colors.black 
      if CursorPosX >= OffsetX and CursorPosX <= ScreenWidth + OffsetX and CursorPosY >= OffsetY and CursorPosY <= ScreenHeight + OffsetY then
        CursorPosX, CursorPosY = CursorPosX - OffsetX, CursorPosY - OffsetY
        Screen.setCursorPos(CursorPosX, CursorPosY)
        Screen.setBackgroundColor(backColor)
        Screen.setTextColor(entities[i].texture[1])
        Screen.write(entities[i].texture[2])
      end
    end
  end

  local players = Player.getNames()
  for i = 1, #players do
    local PlayerX, PlayerY = Player.getCoordinates(players[i])
    local backColor = Level.getTexture(Dimension, PlayerX, PlayerY, useAnimations) or colors.black 
    local direction = Player.getDirection(players[i])
    local playerColor = Player.getColor(players[i])
    local CursorPosX, CursorPosY = PlayerX, PlayerY 
    if CursorPosX >= OffsetX and CursorPosX <= ScreenWidth + OffsetX and CursorPosY >= OffsetY and CursorPosY <= ScreenHeight + OffsetY then
      CursorPosX, CursorPosY = CursorPosX - OffsetX, CursorPosY - OffsetY
      Screen.setCursorPos(CursorPosX, CursorPosY)
      Screen.setBackgroundColor(backColor)
      if playerColor == backColor then
        if playerColor == colors.white then playerColor = colors.black return end
        if playerColor == colors.black then playerColor = colors.white return end
        playerColor = playerColor / 2
      end
      Screen.setTextColor(playerColor)
      if direction == 1 then Screen.write("^")
      elseif direction == 2 then Screen.write(">")
      elseif direction == 3 then Screen.write("V")
      else Screen.write("<") end
      if hideGUI then return end
      Screen.setBackgroundColor(colors.gray)
      Screen.setTextColor(colors.white)
      Screen.setCursorPos(CursorPosX - math.floor(#players[i] / 2), CursorPosY - 2)
      Screen.write(players[i])
    end
  end

  if not hideGUI and not debugMode and Player.isAlive(currentPlayer) then -- Top-Left UI
    Screen.setTextColor(colors.white)
    for i = 1, 2 do paintutils.drawLine(1, i, 10, i, colors.black)  end
    paintutils.drawLine(1, 1, Player.getHealth(currentPlayer) / 2, 1, colors.red)
    Screen.setCursorPos(1, 1); Screen.write("HEALTH")
    paintutils.drawLine(1, 2, Player.getEnergy(currentPlayer) / 2, 2, colors.cyan)
    Screen.setCursorPos(1, 2); Screen.write("ENERGY")

    -- Shows if the player is holding anything
    local currentItem = Player.getHeldItem(currentPlayer)
    if currentItem then
      local playerInventory = Player.getInventory(currentPlayer)
      if not playerInventory[currentItem] or not playerInventory[currentItem].ID then return end
      local item = Assets[playerInventory[currentItem].ID]

      if playerInventory[currentItem].Durability then
        for i = 1, 3 do
          paintutils.drawLine(1, (ScreenHeight - 3) + i, 15,(ScreenHeight - 3) + i, colors.gray)
        end
        Screen.setTextColor(colors.yellow)
        Screen.setCursorPos(8 - math.floor((#item.name / 2)), ScreenHeight - 2)
        Screen.write(item.name)
        if playerInventory[currentItem].Durability > 0 then
          paintutils.drawLine(2, ScreenHeight - 1, math.ceil(13 / (item.durability / playerInventory[currentItem].Durability) + 1), ScreenHeight - 1, colors.lime)
          Screen.setBackgroundColor(colors.gray)
          Screen.setCursorPos(8 - string.len(playerInventory[currentItem].Durability), ScreenHeight)
          Screen.setTextColor(colors.white)
          Screen.write(playerInventory[currentItem].Durability.. "/" ..item.durability)
        end
      else
        Screen.setBackgroundColor(colors.gray)
        Screen.setCursorPos(1, ScreenHeight)
        Screen.setTextColor(colors.yellow)
        Screen.write(" " ..item.name)
        Screen.setTextColor(colors.white)
        Screen.write(" x" ..playerInventory[currentItem].Amount.. " ")
        Screen.setBackgroundColor(item.texture[1] or colors.gray)
        Screen.setTextColor(item.texture[2] or colors.gray)
        Screen.write(item.texture[3] or "?")
        Screen.setBackgroundColor(colors.gray)
        Screen.write(" ")
      end
    end
  end

  if not currentInterface then Screen.drawScreen() end
end

local function checkOffset(ValueX, ValueY)
  local OffsetX2, OffsetY2 = OffsetX + (ValueX or 0), OffsetY + (ValueY or 0)
  if PlayerX - OffsetX2 < math.floor(ScreenWidth / 2) or math.floor(ScreenWidth / 2) < PlayerX - OffsetX2 then OffsetX2 = OffsetX end
  if PlayerY - OffsetY2 < math.floor(ScreenHeight / 2) or math.floor(ScreenHeight / 2) < PlayerY - OffsetY2 then OffsetY2 = OffsetY end
  if OffsetX2 < 0 then OffsetX2 = 0 end; if OffsetY2 < 0 then OffsetY2 = 0 end
  Level.setOffset(OffsetX2, OffsetY2)
  updateScreen()
end

local function inputHandler(eventData)
  currentPlayer = Player.getCurrentPlayer(); if not Player.isAlive(currentPlayer) then return end
  PlayerX, PlayerY = Player.getCoordinates(currentPlayer)
  if eventData[1] == "key" then -- Key events
    if eventData[2] == 17 or eventData[2] == 200 then -- Up Key
      --if multiplayer then getData(textutils.serialize({"Player", "up"})); return end
      Player.setDirection(currentPlayer, 1)
      if Level.checkForCollision(Dimension, PlayerX, PlayerY - 1) then return end
      if OffsetY > 0 then checkOffset(_, -1) end
      if PlayerY > 1 then Player.setCoordinates(currentPlayer, _, "sub1") end

    elseif eventData[2] == 31 or eventData[2] == 208 then -- Down Key
      --if multiplayer then getData(textutils.serialize({"Player", "down"})); return end
      Player.setDirection(currentPlayer, 3)
      if Level.checkForCollision(Dimension, PlayerX, PlayerY + 1) then return end
      if OffsetY < Height - ScreenHeight then checkOffset(_, 1) end
      if PlayerY < Height then Player.setCoordinates(currentPlayer, _, "add1") end

    elseif eventData[2] == 30 or eventData[2] == 203 then -- Left Key
      --if multiplayer then getData(textutils.serialize({"Player", "left"})); return end
      Player.setDirection(currentPlayer, 4)
      if Level.checkForCollision(Dimension, PlayerX - 1, PlayerY) then return end
      if OffsetX > 0 then checkOffset(-1) end
      if PlayerX > 1 then Player.setCoordinates(currentPlayer, "sub1") end

    elseif eventData[2] == 32 or eventData[2] == 205 then -- Right Key
      --if multiplayer then getData(textutils.serialize({"Player", "right"})); return end
      Player.setDirection(currentPlayer, 2)
      if Level.checkForCollision(Dimension, PlayerX + 1, PlayerY) then return end
      if OffsetX < Width - ScreenWidth then checkOffset(1) end
      if PlayerX < Width then Player.setCoordinates(currentPlayer, "add1") end

    elseif eventData[2] == 18 then -- E
      --if multiplayer then getData(textutils.serialize({"Player", "interact"})); return end
      local interactionCoords = {Player.getFacingCoords(currentPlayer)}
      local Block = Level.getData(Dimension, interactionCoords[1], interactionCoords[2]).Block
      --currentInterface = Menu.getInterface("Inventory"); if not Block then return end
      currentInterface = "Inventory"; if not Block then return end
      if Crafting.isCraftingTable(Block.ID) then currentInterface = Menu.getInterface("Crafting") 
      elseif Block.ID and Assets[Block.ID].interface then currentInterface = Assets[Block.ID].interface end

    elseif eventData[2] == 14 then currentInterface = Menu.getInterface("PauseMenu") -- Backspace
    elseif eventData[2] == 42 then Player.lockDirection(currentPlayer, not Player.lockedDirection(currentPlayer)) -- Shift
    elseif eventData[2] == 59 then hideGUI = not hideGUI -- F1
    -- Disabled temporarily
    -- elseif eventData[2] == 60 then Entity.spawnEntity(452, Dimension, PlayerX + 1, PlayerY); Entity.spawnEntity(451, Dimension, PlayerX + 1, PlayerY); Entity.spawnEntity(450, Dimension, PlayerX + 1, PlayerY) -- F2
    elseif eventData[2] == 61 then debugMode = not debugMode  -- F3
    elseif eventData[2] == 57 then Player.useItem(currentPlayer) --if multiplayer then getData(textutils.serialize({"Player", "useItem"})); return end -- Space Bar
    elseif eventData[2] == 20 then currentInterface = Menu.getInterface("Chat"); os.queueEvent("key", 14) -- T
    elseif eventData[2] == 53 then currentInterface = Menu.getInterface("Chat"); os.queueEvent("key", 14); os.queueEvent("char", "/") end -- /

  elseif eventData[1] == "mouse_scroll" and Player.getMode(currentPlayer) == 1 then selectedAsset = selectedAsset - eventData[2]
  elseif string.find(eventData[1], "mouse_") and Player.getMode(currentPlayer) == 1 then
    if eventData[2] == 1 then
      if Assets[selectedAsset] then
        if Assets[selectedAsset].type == "tile" or Assets[selectedAsset].type == "liquid" then Level.setData(Dimension, eventData[3] + OffsetX, eventData[4] + OffsetY, {Tile = {ID = selectedAsset}})
        elseif Assets[selectedAsset].type == "block" or Assets[selectedAsset].type == "blocktile" then Level.setData(Dimension, eventData[3] + OffsetX, eventData[4] + OffsetY, {Block = {ID = selectedAsset}}) end
      end
    elseif eventData[2] == 2 then Level.setData(Dimension, eventData[3] + OffsetX, eventData[4] + OffsetY, {Block = {ID = false}}) end
  end
  Screen.drawScreen()
end

local justOpened, command = true
local function drawInterface(eventData)
  if currentInterface and eventData then
    if justOpened then eventData = {}; justOpened = false end
    if type(currentInterface) == "string" then command = Interface.updateInterface(currentInterface, eventData, currentPlayer)
    elseif type(currentInterface) == "function" then command = currentInterface(eventData, currentPlayer) end
    if command then currentInterface = false; justOpened = true end; if command == "quit" then File.saveWorld(File.getCurrentWorldName()); Player.setPlayers({}); Level.setInGame(false) return true end
  end 
end

local Game = coroutine.create(function() while true do updateGame(); coroutine.yield() end end) 
local Render = coroutine.create(function() while true do updateScreen(); coroutine.yield() end end) 

function singlePlayer()
  local gameTick = os.startTimer(clientTick); checkOffset()
  while Level.isInGame() do 
    local eventData = {os.pullEvent()}; World = Level.getWorld()
    if eventData[1] == "term_resize" then ScreenWidth, ScreenHeight = term.getSize(); _G.Screen.Width, _G.Screen.Height = ScreenWidth, ScreenHeight; updateScreen() end
    if eventData[1] == "timer" then
      if eventData[2] == gameTick then
        gameTick, startTick = os.startTimer(clientTick), os.clock()
        local ok, result = coroutine.resume(Game); if not ok then error(result) end; endTick, startFrame = os.clock(), os.clock()
        local ok, result = coroutine.resume(Render); if not ok then error(result) end; endFrame = os.clock()
      elseif eventData[2] == saveWorldTimer then File.saveWorld(File.getCurrentWorldName()); Chat.sendMessage("/say World Saved", currentPlayer); saveWorldTimer = os.startTimer(300) end
    elseif eventData[1] ~= "rednet" and not currentInterface then inputHandler(eventData) end
    if eventData[1] ~= "rednet" and currentInterface then drawInterface(eventData); Screen.drawScreen() end
  end
  drawUpdateTimer = os.startTimer(0.5)
end

while true do
  local eventData = {os.pullEvent()}
  if eventData[1] == "term_resize" then ScreenWidth, ScreenHeight = term.getSize(); _G.Screen.Width, _G.Screen.Height = ScreenWidth, ScreenHeight; Screen.drawScreen() end
  if (eventData[1] == "timer" and eventData[2] == drawUpdateTimer) or eventData[1] == "key" or string.find(eventData[1], "mouse_") or eventData[1] == "char" then 
    if eventData[1] == "timer" then drawUpdateTimer = os.startTimer(0.5); updateScreen(true) end
    local action = Menu.getInterface("StartMenu")(eventData, currentPlayer); Screen.drawScreen()  
    if action == "singlePlayer" then hideGUI = false; Width, Height = Level.getSize(); World = Level.getWorld(); updateScreen();
    Screen.drawScreen(); Level.setInGame(true); drawUpdateTimer = os.startTimer(0.5); singlePlayer(); currentTime = Level.getTime() end
  end
end