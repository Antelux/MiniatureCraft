--[[
  MiniatureCraft, a game by Detective_Smith
  Current Version: 2.0

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

if not term.isColor then error("Advanced Computer Required to Play.", 2) end

local ScreenWidth, ScreenHeight = term.getSize()
local debugMode, hideGUI = false, true
local multiplayer = false
local askForUpdate = false
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
end
_G.printError = _G.error

--[[
local attachedPeripherals = peripheral.getNames()
local port = 25565
for i = 1, #attachedPeripherals do
  if peripheral.getType(attachedPeripherals[i]) ~= "modem" then return end
  modem = peripheral.wrap(attachedPeripherals[i])
  if not modem.isWireless() then return end
  modem.open(port)
end
--]]

dofile(MainFolder.. "/Assets")
for n, sFile in ipairs(fs.list(APIFolder)) do dofile(APIFolder.. "/" ..sFile) end; File.loadMods()
local World = Level.newWorld(ScreenWidth, ScreenHeight); Level.setWorld(World)
local Width, Height = Level.getSize()
local Assets = File.loadAssets()
local OffsetX, OffsetY = 0, 0

-- Various Timers for the World
local drawUpdateTimer = os.startTimer(0.5)
local timeUpdateTimer = os.startTimer(0.05)
local saveWorldTimer = os.startTimer(300)

local currentPlayer = Player.getCurrentPlayer()
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

local startTime, endTime
local draw = Screen.drawScreen
_G.Screen.drawScreen = function()
  endTime = os.clock()
  if debugMode then
    local AssetName = Assets[selectedAsset]
    if AssetName then AssetName = AssetName.name else AssetName = "None" end
    Screen.setBackgroundColor(colors.gray)
    Screen.setTextColor(colors.white)
    Screen.setCursorPos(1, 1)
    Screen.write("X: " ..PlayerX.. ", Y: " ..PlayerY.. ", T: " ..AssetName.. ":" ..selectedAsset.. ", FPS: " ..string.sub(tostring((endTime - startTime) * 4), 1, 3))
  end
  draw()
end

local function checkOffset(ValueX, ValueY)
  local OffsetX2, OffsetY2 = OffsetX + (ValueX or 0), OffsetY + (ValueY or 0)
  if PlayerX - OffsetX2 < math.floor(ScreenWidth / 2) or math.floor(ScreenWidth / 2) < PlayerX - OffsetX2 then OffsetX2 = OffsetX end
  if PlayerY - OffsetY2 < math.floor(ScreenHeight / 2) or math.floor(ScreenHeight / 2) < PlayerY - OffsetY2 then OffsetY2 = OffsetY end
  Level.setOffset(OffsetX2, OffsetY2)
end

local demoDimension = math.random(-3, 0)
local function updateScreen(update, useAnimations)
  OffsetX, OffsetY = Level.getOffset()
  Dimension = Player.getDimension(currentPlayer) or demoDimension
  if not update then Level.updateArea(Dimension, OffsetX, OffsetY, OffsetX + ScreenWidth, OffsetY + ScreenHeight) end

  -- Draws the initial world --
  for x = 1, ScreenWidth do 
    for y = 1, ScreenHeight do 
      local mx, my = x + OffsetX, y + OffsetY
      if mx > Width then mx = Width end
      if mx < 0 then mx = 0 end
      if my > Height then my = Height end
      if my < 0 then my = 0 end
      Screen.setCursorPos(x, y)
      local background, foreground, symbol = Level.getTexture(Dimension, mx, my, useAnimations)
      if type(background) == "number" then Screen.setBackgroundColor(background) else Screen.setBackgroundColor(colors.purple) end
      if type(foreground) == "number" then Screen.setTextColor(foreground) else Screen.setTextColor(colors.black) end
      if type(symbol) == "string" then Screen.write(symbol) else Screen.write("#") end
    end
  end

  local entities = Entity.getEntities()
  for i = 1, #entities do
    if entities[i] and entities[i].currentDim == Dimension then 
      if not update and entities[i].script then entities[i].script(i) end
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
        if item.type == "block" or item.type == "blocktile" or item.type == "tile" then
          Screen.setBackgroundColor(item.texture[1] or colors.gray)
          Screen.setTextColor(item.texture[2] or colors.gray)
          Screen.write(item.texture[3] or " ")
        else
          Screen.setTextColor(item.texture[1] or colors.white)
          Screen.write(item.texture[2] or "?")
        end
      end
    end
  end
end

--[[
local function getData(message)
  modem.transmit(port, port, message)
  local waitTimer = os.startTimer(10)
  while true do 
    local eventData = {os.pullEvent()}
    if eventData[1] == "timer" and eventData[2] == waitTimer then return "timeout" end
    if eventData[1] == "modem_message" then
      local data = textutils.unserialize(eventData[5])
      --if not data or type(data) ~= "table" or type(data[1]) ~= "table" or type(data[2]) ~= "table" then return end
      Player.setPlayers(data)
      --Level.setWorld(data[2])
    end
  end
end
--]]

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
      currentInterface = Menu.getInterface("Inventory"); if not Block then return end
      if Crafting.isCraftingTable(Block.ID) then currentInterface = Menu.getInterface("Crafting") 
      elseif Block.ID and Assets[Block.ID].interface then currentInterface = Menu.getInterface(Assets[Block.ID].interface) end

    elseif eventData[2] == 14 then currentInterface = Menu.getInterface("PauseMenu") -- Backspace
    elseif eventData[2] == 42 then Player.lockDirection(currentPlayer, not Player.lockedDirection(currentPlayer)) -- Shift
    elseif eventData[2] == 59 then hideGUI = not hideGUI -- F1
    --elseif eventData[2] == 60 then Entity.spawnEntity(452, Dimension, PlayerX + 1, PlayerY) -- F2
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
end

local function drawInterface(eventData) 
  if currentInterface then 
    local command = currentInterface(eventData, currentPlayer)
    if command then currentInterface = false; if command == "quit" then File.saveWorld(File.getCurrentWorldName()); Player.setPlayers({}) return true end; return end
  end 
end

function singlePlayer()
  while true do startTime = os.clock()
    local eventData = {os.pullEvent()}; World = Level.getWorld()
    if eventData[1] == "timer" then
      if eventData[2] == drawUpdateTimer then updateScreen(); if drawInterface(eventData) then break end; Screen.drawScreen(); drawUpdateTimer = os.startTimer(0.5)  
      elseif eventData[2] == saveWorldTimer then File.saveWorld(File.getCurrentWorldName()); Chat.sendMessage("/say World Saved", currentPlayer); saveWorldTimer = os.startTimer(300) end
    elseif eventData[1] == "key" or string.find(eventData[1], "mouse_") or eventData[1] == "char" then 
      if not currentInterface and (eventData[1] == "key" or string.find(eventData[1], "mouse_")) then inputHandler(eventData); updateScreen(true) else updateScreen(true); if drawInterface(eventData) then break end; end
      Screen.drawScreen()
    end
  end
end

while true do
  local eventData = {os.pullEvent()}
  if eventData[1] == "term_resize" then ScreenWidth, ScreenHeight = term.getSize() end
  if (eventData[1] == "timer" and eventData[2] == drawUpdateTimer) or eventData[1] == "key" or string.find(eventData[1], "mouse_") or eventData[1] == "char" then 
    if eventData[1] == "timer" then drawUpdateTimer = os.startTimer(0.5); updateScreen(true) end
    local action = Menu.getInterface("StartMenu")(eventData, currentPlayer); Screen.drawScreen()  
    if action == "singlePlayer" then hideGUI = false; Width, Height = Level.getSize(); World = Level.getWorld();
    updateScreen(); Screen.drawScreen(); drawUpdateTimer = os.startTimer(0.5); singlePlayer() end
  end
end

--[[
function multiPlayer()
  multiplayer = true
  while true do
    local eventData = {os.pullEvent()}
    if eventData[1] == "timer" and eventData[2] == drawUpdateTimer then updateScreen(true); drawInterface(eventData); Screen.drawScreen(); drawUpdateTimer = os.startTimer(0.5) end
    if eventData[1] == "key" or string.find(eventData[1], "mouse_") or eventData[1] == "char" then 
      if not currentInterface and (eventData[1] == "key" or string.find(eventData[1], "mouse_")) then inputHandler(eventData); updateScreen(true) else updateScreen(true); drawInterface(eventData) end
      Screen.drawScreen()
    end
  end
  multiplayer = false
end

multiPlayer()
--]]
