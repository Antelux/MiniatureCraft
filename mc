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

if not term.isColor() then error("Advanced Computer Required to Play.", 2) end

local ScreenWidth, ScreenHeight = term.getSize()
local debugMode, hideGUI = false, true
local askForUpdate = false
local modem, port, ip
local targetFPS = 20 -- Sets the target FPS you want the game to run at. Of course, anything above 20 wouldn't work, as 20 is the max always.
local checkForUpdates = true
 
if checkForUpdates and http then
  local latestVersion = http.get("http://pastebin.com/raw.php?i=N2FmL2Q7")
  if latestVersion then
    if latestVersion.readAll() ~= File.getVersion() then askForUpdate = true end
    latestVersion.close()
    
    if askForUpdate then
      setBackgroundColor(colors.black); setTextColor(colors.white)
      clear(); setCursorPos(1, 1); sWrite("Updating... "); drawScreen()
      print("Grabbing Installer."); drawScreen()
      local updater = http.get("http://pastebin.com/raw.php?i=FgAggvy1")
      local tempFile = fs.open(MainFolder.. "/.tempUpdater", "w")
      tempFile.write(updater.readAll()); tempFile.close()
      print("Installer Downloaded. Running"); drawScreen()
      shell.run(MainFolder.. "/.tempUpdater", MainFolder)
      print("Update Complete. Deleting Installer."); drawScreen()
      fs.delete(MainFolder.. "/.tempUpdater")
      shell.run(MainFolder.. "mc")
    end
  end
end
if askForUpdate then return end

function _G.getMainFolder() return shell.getRunningProgram():sub(1, #shell.getRunningProgram() - #fs.getName(shell.getRunningProgram())) end
local MainFolder = getMainFolder()
local APIFolder, ModsFolder, SavesFolder = MainFolder.. "/API", MainFolder.. "/Mods", MainFolder.. "/Saves"
if MainFolder == "" then MainFolder = "/" end
local currentTerm = term.current()

dofile(APIFolder.. "/Buffer")
_G.Screen = Buffer.createBuffer()
term.redirect(Screen)

_G.Timer = {}
local timers = {}
function Timer.newTimer(time) timers[#timers + 1] = {time, time}; return #timers end
function Timer.wentOff(ID) return timers[ID] and timers[ID][1] <= 0 end
function Timer.restart(ID) if timers[ID] then timers[ID][1] = timers[ID][2] end end
function Timer.remove(ID) timers[ID] = nil end
local function updateTimers()
  for i = 1, #timers do
    if timers[i] and timers[i][1] > 0 then timers[i][1] = timers[i][1] - 0.05 end
  end
end

local ok, err = loadfile(MainFolder.. "Assets")
if not ok then term.redirect(currentTerm); error(err) end; pcall(ok)
local ok, err = loadfile(APIFolder.. "/File")
if not ok then term.redirect(currentTerm); error(err) end; pcall(ok)
for n, sFile in ipairs(fs.list(APIFolder)) do 
  if sFile ~= "File" and sFile ~= "Buffer" then
    local ok, err = loadfile(APIFolder.. "/" ..sFile)
    if not ok then term.redirect(currentTerm); error(err) end; pcall(ok)
  end
end; File.loadMods()

_G.nativeError = error
_G.nativePrintError = printError
_G.error = function(...)
  fs.delete(MainFolder.. "errorlog")
  local file = fs.open(MainFolder.. "errorlog", "w")
  file.writeLine(...); file.close()
  --_G.nativeError()
end
_G.printError = _G.error

local function entityErrorLog(line)
  local file = fs.open(MainFolder.. "entityerr", "w")
  file.writeLine(line); file.close()
end

for k, v in ipairs(peripheral.getNames()) do
  if peripheral.getType(v) == "modem" then
    modem = peripheral.wrap(v); break
  end
end

local World = Level.newWorld(ScreenWidth, ScreenHeight); Level.setWorld(World)
local Width, Height = Level.getSize()
local Assets = File.loadAssets()
local OffsetX, OffsetY = 0, 0

-- Various Timers for the World
local saveWorldTimer = Timer.newTimer(300)
local energyRegenTimer = Timer.newTimer(1)
local moveTimer = Timer.newTimer(0.5)
local deathTimer = Timer.newTimer(0.75)

local currentPlayer = Player.getCurrentPlayer()
local currentTime
local currentInterface = false
local selectedAsset = 1
local Dimension = math.random(-3, 1)
local PlayerX, PlayerY = 0, 0 
local canMove = true
local deathScreen = false

-- Localizes (Is that even a word) a lot of functions for a speed up in use of them.
local setOffset, getOffset, getLightingMap, getTexture, isInGame, checkForCollision, setData, getData, updateArea, setTime, getTime, setInGame, isInGame, getWorld, getSize, isSingleplayer, isPaused = Level.setOffset, Level.getOffset, Level.getLightingMap, Level.getTexture, Level.isInGame, Level.checkForCollision, Level.setData, Level.getData, Level.updateArea, Level.setTime, Level.getTime, Level.setInGame, Level.isInGame, Level.getWorld, Level.getSize, Level.isSingleplayer, Level.isPaused
local getDimension, getMode, updatePlayers, setCoordinates, getCoordinates, getNames, getDirection, getColor, isAlive, getHealth, getEnergy, getHeldItem, getInventory, getCurrentPlayer, setDirection, getFacingCoords, lockDirection, lockedDirection, useItem, canRegenEnergy, setPlayers, getSpeed, setHealth, setEnergy, setDimension = Player.getDimension, Player.getMode, Player.updatePlayers, Player.setCoordinates, Player.getCoordinates, Player.getNames, Player.getDirection, Player.getColor, Player.isAlive, Player.getHealth, Player.getEnergy, Player.getHeldItem, Player.getInventory, Player.getCurrentPlayer, Player.setDirection, Player.getFacingCoords, Player.lockDirection, Player.lockedDirection, Player.useItem, Player.canRegenEnergy, Player.setPlayers, Player.getSpeed, Player.setHealth, Player.setEnergy, Player.setDimension
local setBackgroundColor, setTextColor, clear, setCursorPos, sWrite, drawScreen, setCursorBlink = Screen.setBackgroundColor, Screen.setTextColor, Screen.clear, Screen.setCursorPos, Screen.write, Screen.drawScreen, Screen.setCursorBlink

local startFrame, startTick = os.clock(), os.clock()
local endFrame, endTick = os.clock(), os.clock()
if targetFPS > 20 then targetFPS = 20 elseif targetFPS < 1 then targetFPS = 1 end
local clientTick = 1 / targetFPS 
local sDrawScreen = drawScreen
local currentFPS = targetFPS
local function drawScreen()
  local currentTime = os.clock()
  if debugMode then
    local AssetName = Assets[selectedAsset]
    if AssetName then AssetName = AssetName.name else AssetName = "None" end
    setBackgroundColor(colors.gray); setTextColor(colors.white); setCursorPos(1, 1)
    local FrameDifference, UpdateDifference = startFrame - endFrame, startTick - endTick
    if FrameDifference == 0 then FrameDifference = clientTick end; if UpdateDifference == 0 then UpdateDifference = clientTick end; currentFPS = string.sub(1 / FrameDifference, 1, 2)
    if getMode(currentPlayer) == 0 then sWrite("FPS: " ..currentFPS.. ", UPS: " ..string.sub(1 / UpdateDifference, 1, 2).. ", Time: " ..textutils.formatTime(getTime()).. ", E: " ..Entity.getTotal())
    else sWrite("FPS: " ..currentFPS.. ", UPS: " ..string.sub(1 / UpdateDifference, 1, 2).. ", Time: " ..textutils.formatTime(getTime()).. ", T: " ..AssetName.. ":" ..selectedAsset) end
  end
  sDrawScreen()
end

local restartDeathTimer = true
local function updateGame()
  startTick = os.clock()
  if isSingleplayer() and not isPaused() then
    OffsetX, OffsetY = getOffset()
    Dimension = getDimension(currentPlayer) or demoDimension
    updateArea(Dimension, OffsetX, OffsetY, OffsetX + ScreenWidth, OffsetY + ScreenHeight) 
    updatePlayers() 

    local newTime = getTime() + (tonumber(currentFPS) / 20000)
    if newTime >= 24 then newTime = 0 end; setTime(newTime)

    if not isAlive(currentPlayer) then
      currentInterface = false
      if restartDeathTimer then
        Timer.restart(deathTimer)
        restartDeathTimer = false
      end
      if Timer.wentOff(deathTimer) then deathScreen = true end
    end

    local entities = Entity.getEntities()
    local dime = 0
    for i in pairs(entities) do
      if entities[i] and entities[i].dim == Dimension and type(entities[i].ai) == "thread" and coroutine.status(entities[i].ai) ~= "dead" then
        local ok, err = coroutine.resume(entities[i].ai); dime = dime + 1
        if not ok then entityErrorLog(Assets[entities[i].ID].name.. ":" ..i.. ":" ..err); Entity.removeEntity(i) end
      else Entity.removeEntity(i) end
    end

    if math.random(200) == 1 and dime < 20 then
      if Dimension == 0 then 
        local rx, ry = math.random(Width), math.random(Height)
        local Data = Level.getData(0, rx, ry)
        if not (Data.Block and Data.Block.ID) and Data.Tile and Data.Tile.ID and Assets[Data.Tile.ID].type ~= "liquid" then 
          if newTime < 7 or newTime > 20 then
            if Level.getLightingLevel(Dimension, rx, ry) <= 1 then Entity.spawnEntity(math.random(400, 402), 0, rx, ry) end
          else Entity.spawnEntity(math.random(450, 452), 0, rx, ry) end
        end

      elseif Dimension ~= 1 then
        local rx, ry = math.random(Width), math.random(Height)
        local Data = Level.getData(0, rx, ry)
        if not (Data.Block and Data.Block.ID) and Data.Tile and Data.Tile.ID and Assets[Data.Tile.ID].type ~= "liquid" and Level.getLightingLevel(Dimension, rx, ry) <= 1 then 
          Entity.spawnEntity(math.random(400, 402), Dimension, rx, ry)
        end
      end
    end
  end
  endTick = os.clock()
end

local demoDimension = math.random(-3, 1)
local gameScreen = Screen.Screen
local function updateScreen(drawHere)
  startFrame = os.clock()

  if isInGame() and not isAlive(currentPlayer) then
    setBackgroundColor(colors.black); clear()
    setCursorPos((ScreenWidth / 2) - 4.5, (ScreenHeight / 2) - 1)
    setBackgroundColor(0); setTextColor(1); sWrite("You died.")
    setCursorBlink(false)
    if deathScreen then
      setCursorPos((ScreenWidth / 2) - 13.5, (ScreenHeight / 2) + 1)
      sWrite("Press anything to continue"); setCursorBlink(true) 
    end
  elseif isAlive(currentPlayer) or isSingleplayer() then
    OffsetX, OffsetY = getOffset()
    Dimension = getDimension(currentPlayer) or demoDimension
    local lMap = getLightingMap()

    -- Draws the initial world, directly interfaces with the buffer --
    for y = 1, ScreenHeight do 
      local textLine, tColorLine, bColorLine = "", "", ""
      for x = 1, ScreenWidth do 
        local mx, my = x + OffsetX, y + OffsetY
        if mx > Width then mx = Width end
        if mx < 0 then mx = 0 end
        if my > Height then my = Height end
        if my < 0 then my = 0 end
        if lMap[Dimension] and not(lMap[Dimension][mx] and lMap[Dimension][mx][my]) then
          gameScreen[y][x][1] = " "
          gameScreen[y][x][2] = colors.black
          gameScreen[y][x][3] = colors.black
        else
          local background, foreground, symbol = getTexture(Dimension, mx, my, useAnimations)
          if lMap[Dimension] and lMap[Dimension][mx] and lMap[Dimension][mx][my] and type(lMap[Dimension][mx][my]) == "string" then symbol = lMap[Dimension][mx][my]; foreground = colors.black end
          gameScreen[y][x][1] = symbol or "#"
          gameScreen[y][x][2] = foreground or colors.black
          gameScreen[y][x][3] = background or colors.purple
        end
      end
    end

    local entities = Entity.getEntities()
    for i = 1, #entities do
      if entities[i] and entities[i].dim == Dimension then 
        local CursorPosX, CursorPosY = entities[i].coordinates[1], entities[i].coordinates[2]
        if Level.getLightingLevel(Dimension, CursorPosX, CursorPosY) >= 2 then
          local backColor = getTexture(Dimension, CursorPosX, CursorPosY, useAnimations) or colors.black 
          if CursorPosX >= OffsetX and CursorPosX <= ScreenWidth + OffsetX and CursorPosY >= OffsetY and CursorPosY <= ScreenHeight + OffsetY then
            CursorPosX, CursorPosY = CursorPosX - OffsetX, CursorPosY - OffsetY
            setCursorPos(CursorPosX, CursorPosY); setBackgroundColor(backColor)
            setTextColor(Assets[entities[i].ID].texture[1]); sWrite(Assets[entities[i].ID].texture[2])
          end
        end
      end
    end

    local players = getNames()
    for i = 1, #players do
      if isAlive(players[i]) and getDimension(players[i]) == Dimension then
        local PlayerX, PlayerY = getCoordinates(players[i])
        if Level.getLightingLevel(Dimension, PlayerX, PlayerY) >= 2 then
          local backColor, foreColor = getTexture(Dimension, PlayerX, PlayerY, useAnimations) or colors.black 
          local direction = getDirection(players[i])
          local playerColor = getColor(players[i])
          local CursorPosX, CursorPosY = PlayerX, PlayerY 

          if CursorPosX >= OffsetX and CursorPosX <= ScreenWidth + OffsetX and CursorPosY >= OffsetY and CursorPosY <= ScreenHeight + OffsetY then
            CursorPosX, CursorPosY = CursorPosX - OffsetX, CursorPosY - OffsetY
            setCursorPos(CursorPosX, CursorPosY)
            setBackgroundColor(backColor)
            if playerColor == backColor or playerColor == foreColor then
              if playerColor == colors.white then playerColor = colors.black return end
              if playerColor == colors.black then playerColor = colors.white return end
              playerColor = playerColor / 2
            end

            if Player.isTakingDamage(players[i]) then 
              if playerColor == colors.red then playerColor = colors.pink
              else playerColor = colors.red end
            end

            setTextColor(playerColor)
            if direction == 1 then sWrite("^")
            elseif direction == 2 then sWrite(">")
            elseif direction == 3 then sWrite("V")
            else sWrite("<") end
            if not hideGUI then 
              setBackgroundColor(colors.gray)
              setTextColor(colors.white)
              local playername = players[i]
              if players[i] == "" then playername = "Player" end
              setCursorPos(CursorPosX - math.floor(#playername / 2), CursorPosY - 2)
              sWrite(playername)
            end
          end
        end
      end
    end

    if not hideGUI and not debugMode and isAlive(currentPlayer) then 
      -- Health and Energy Meters
      if getMode(currentPlayer) ~= 1 then
        setTextColor(colors.lightGray)
        setCursorPos(ScreenWidth - 17, ScreenHeight); sWrite("|"); setCursorPos(ScreenWidth - 17, ScreenHeight - 1); sWrite("|")
        setCursorPos(ScreenWidth - 10, ScreenHeight); sWrite("|"); setCursorPos(ScreenWidth - 10, ScreenHeight - 1); sWrite("|")
        setCursorPos(ScreenWidth - 17, ScreenHeight - 2); sWrite("|" ..string.rep("-", 17)); setTextColor(colors.yellow)
        setCursorPos(ScreenWidth - 16, ScreenHeight - 1); sWrite("Health"); setCursorPos(ScreenWidth - 16, ScreenHeight); sWrite("Energy")
        setBackgroundColor(colors.black); setTextColor(colors.gray); setCursorPos(ScreenWidth - 9, ScreenHeight - 1)
        sWrite(string.rep("=", 10)); setCursorPos(ScreenWidth - 9, ScreenHeight); sWrite(string.rep("=", 10))

        local health, energy = getHealth(currentPlayer), getEnergy(currentPlayer)
        setBackgroundColor(colors.red); setTextColor(colors.white); setCursorPos(ScreenWidth - 9, ScreenHeight - 1)
        if (health % 2 == 0) then sWrite(string.rep("=", health / 2)) else sWrite(string.rep("=", (health - 1) / 2)); sWrite("-") end
        setBackgroundColor(colors.cyan); setTextColor(colors.lightBlue); setCursorPos(ScreenWidth - 9, ScreenHeight)
        if energy >= 1 then if (energy % 2 == 0) then sWrite(string.rep("=", energy / 2)) else sWrite(string.rep("=", (energy - 1) / 2)); sWrite("-") end end
      end
      
      -- Shows if the player is holding anything
      local currentItem = getHeldItem(currentPlayer)
      if currentItem then
        local playerInventory = getInventory(currentPlayer)
        if not playerInventory[currentItem] or not playerInventory[currentItem].ID then return end
        local item = Assets[playerInventory[currentItem].ID]

        if playerInventory[currentItem].Durability then
          for i = 1, 3 do paintutils.drawLine(1, (ScreenHeight - 3) + i, 15,(ScreenHeight - 3) + i, colors.gray) end
          setTextColor(colors.yellow)
          setCursorPos(8 - math.floor((#item.name / 2)), ScreenHeight - 2)
          sWrite(item.name)
          if playerInventory[currentItem].Durability > 0 then
            local currentDurability = 13 / (item.durability / playerInventory[currentItem].Durability) + 1
            local currentColor = colors.lime

            if currentDurability <= 9.75 then currentColor = colors.yellow end
            if currentDurability <= 6.5 then currentColor = colors.orange end
            if currentDurability <= 3.25 then currentColor = colors.red end

            paintutils.drawLine(2, ScreenHeight - 1, 14, ScreenHeight - 1, colors.black)
            paintutils.drawLine(2, ScreenHeight - 1, math.ceil(currentDurability), ScreenHeight - 1, currentColor)
            setBackgroundColor(colors.gray)
            setCursorPos(8 - string.len(playerInventory[currentItem].Durability), ScreenHeight)
            setTextColor(colors.white)
            sWrite(playerInventory[currentItem].Durability.. "/" ..item.durability)
          end
        else
          setBackgroundColor(colors.gray)
          setCursorPos(1, ScreenHeight)
          setTextColor(colors.yellow)
          sWrite(" " ..item.name)
          setTextColor(colors.white)
          sWrite(" x" ..playerInventory[currentItem].Amount.. " ")
          setBackgroundColor(item.texture[1] or colors.gray)
          setTextColor(item.texture[2] or colors.gray)
          sWrite(item.texture[3] or "?")
          setBackgroundColor(colors.gray)
          sWrite(" ")
        end
      end
    end
  end

  if not currentInterface and not drawHere then drawScreen() end
  endFrame = os.clock()
end

local fadeOutColors = {
    [colors.white] = {colors.lightGray, colors.gray},
    [colors.lightGray] = {colors.gray},

    [colors.yellow] = {colors.orange, colors.red, colors.brown},
    [colors.orange] = {colors.red, colors.brown, colors.gray},
    [colors.red] = {colors.brown, colors.gray},

    [colors.lightBlue] = {colors.cyan, colors.blue, colors.gray},
    [colors.cyan] = {colors.blue, colors.gray},
    [colors.blue] = {colors.gray},

    [colors.lime] = {colors.green, colors.gray},
    [colors.green] = {colors.gray},

    [colors.pink] = {colors.magenta, colors.purple, colors.gray},
    [colors.magenta] = {colors.purple, colors.gray},
    [colors.purple] = {colors.gray}
}

local fadeInColors = {
    [colors.white] = {colors.gray, colors.lightGray},
    [colors.lightGray] = {colors.gray},
    [colors.gray] = {colors.black},

    [colors.yellow] = {colors.brown, colors.red, colors.orange},
    [colors.orange] = {colors.gray, colors.brown, colors.red},
    [colors.red] = {colors.black, colors.gray, colors.brown},

    [colors.lightBlue] = {colors.gray, colors.blue, colors.cyan},
    [colors.cyan] = {colors.gray, colors.blue},
    [colors.blue] = {colors.gray},

    [colors.lime] = {colors.gray, colors.green},
    [colors.green] = {colors.gray},

    [colors.pink] = {colors.gray, colors.purple, colors.magenta},
    [colors.magenta] = {colors.gray, colors.purple},
    [colors.purple] = {colors.gray}
}

local function fadeScreenIn(useSleep)
  setBackgroundColor(colors.black); clear(); drawScreen()
  for i = 1, 4 do
    for y = 1, ScreenHeight do 
      local textLine, tColorLine, bColorLine = "", "", ""
      for x = 1, ScreenWidth do 
        local mx, my = x + OffsetX, y + OffsetY
        if mx > Width then mx = Width end; if mx < 0 then mx = 0 end
        if my > Height then my = Height end; if my < 0 then my = 0 end
        local background, foreground, symbol = getTexture(demoDimension, mx, my, useAnimations)
        if fadeInColors[background] then background = fadeInColors[background][i] or background end
        if fadeInColors[foreground] then foreground = fadeInColors[foreground][i] or foreground end
        gameScreen[y][x][1] = symbol or "#"
        gameScreen[y][x][2] = foreground or colors.black
        gameScreen[y][x][3] = background or colors.purple
      end
    end
    Screen.isDirty = true
    drawScreen(); if useSleep then sleep() else coroutine.yield() end
  end
end 

local function fadeScreenOut(useSleep)
  for i = 5, 1, -1 do
    for y = 1, ScreenHeight do 
      local textLine, tColorLine, bColorLine = "", "", ""
      for x = 1, ScreenWidth do 
        local mx, my = x + OffsetX, y + OffsetY
        if mx > Width then mx = Width end; if mx < 0 then mx = 0 end
        if my > Height then my = Height end; if my < 0 then my = 0 end
        local background, foreground, symbol = getTexture(demoDimension, mx, my, useAnimations)
        if fadeOutColors[background] then background = fadeOutColors[background][i] or background end; background = (i <= 0 and colors.black) or background
        if fadeOutColors[foreground] then foreground = fadeOutColors[foreground][i] or foreground end; foreground = (i <= 0 and colors.black) or foreground
        if (background == colors.gray or background == colors.black) and foreground == colors.black then symbol = " " end
        gameScreen[y][x][1] = symbol or "#"
        gameScreen[y][x][2] = foreground or colors.black
        gameScreen[y][x][3] = background or colors.purple 
      end
    end
    Screen.isDirty = true
    drawScreen(); if useSleep then sleep() else coroutine.yield() end
  end
  setBackgroundColor(colors.black); clear(); drawScreen()
end

local function checkOffset(ValueX, ValueY)
  local OffsetX2, OffsetY2 = OffsetX + (ValueX or 0), OffsetY + (ValueY or 0)
  if PlayerX - OffsetX2 < math.floor(ScreenWidth / 2) or math.floor(ScreenWidth / 2) < PlayerX - OffsetX2 then OffsetX2 = OffsetX end
  if PlayerY - OffsetY2 < math.floor(ScreenHeight / 2) or math.floor(ScreenHeight / 2) < PlayerY - OffsetY2 then OffsetY2 = OffsetY end
  if OffsetX2 < 0 then OffsetX2 = 0 end; if OffsetY2 < 0 then OffsetY2 = 0 end
  setOffset(OffsetX2, OffsetY2)
  updateScreen()
end

local ip, port = 14, 25565
local function sendPacket(request)
  request = {currentPlayer, request, port}
  -- channel, replyChannel, message
  modem.transmit(ip, os.getComputerID(), request)
  local waitTimer = os.startTimer(10)
  local eventData = {os.pullEvent()}
  if eventData[1] == "modem_message" then
    local message = eventData[5] --textutils.unserialize(eventData[5])
    if type(message) ~= "table" then return end; if #message ~= 3 then return end
    local player, reply, mPort = message[1], message[2], message[3]
    if type(player) ~= "string" or type(reply) ~= "table" or type(mPort) ~= "number" then return end
    if mPort ~= port then return end; if player ~= currentPlayer then return end
    if request[2] == "join" then
      if type(reply) == "table" then
        --World[0] = reply["world"]; Level.setWorld(World)
        Level.setWorld(reply["world"])
        Level.setTime(reply["time"])
        fadeScreenIn(true)
        gameTick = os.startTimer(clientTick)
        return true
      end
    else return message end
  elseif eventData[1] == "timer" and eventData[2] == waitTimer then return end
end

local function inputHandler(eventData)
  currentPlayer = getCurrentPlayer(); 
  if not isAlive(currentPlayer) then
    if deathScreen and eventData[1] == "key" then
      local spawnX, spawnY = unpack(Level.getSpawnPoint())
      setHealth(currentPlayer, 20); setEnergy(currentPlayer, 20)
      lockDirection(currentPlayer, false); setCoordinates(currentPlayer, spawnX, spawnY)
      isAlive(currentPlayer, true); setDimension(currentPlayer, 0); deathScreen = false; restartDeathTimer = true
      setOffset(spawnX - math.ceil(ScreenWidth / 2), spawnY - math.ceil(ScreenHeight / 2)); checkOffset()
    end  
    return 
  end
  PlayerX, PlayerY = getCoordinates(currentPlayer)
  if eventData[1] == "key" then -- Key events
    if (eventData[2] == 17 or eventData[2] == 200) then -- Up Key
      if not isSingleplayer() then sendPacket("up"); return end
      setDirection(currentPlayer, 1)
      --if not canMove then return end; moveTimer = os.startTimer(1 / getSpeed(currentPlayer)); canMove = false
      if checkForCollision(Dimension, PlayerX, PlayerY - 1) then return end
      if OffsetY > 0 then checkOffset(_, -1) end
      if PlayerY > 1 then setCoordinates(currentPlayer, _, "sub1") end

    elseif (eventData[2] == 31 or eventData[2] == 208) then -- Down Key
      if not isSingleplayer() then sendPacket("down"); return end
      setDirection(currentPlayer, 3)
      --if not canMove then return end; moveTimer = os.startTimer(1 / getSpeed(currentPlayer)); canMove = false
      if checkForCollision(Dimension, PlayerX, PlayerY + 1) then return end
      if OffsetY < Height - ScreenHeight then checkOffset(_, 1) end
      if PlayerY < Height then setCoordinates(currentPlayer, _, "add1") end

    elseif (eventData[2] == 30 or eventData[2] == 203) then -- Left Key
      if not isSingleplayer() then sendPacket("left"); return end
      setDirection(currentPlayer, 4)
      --if not canMove then return end; moveTimer = os.startTimer(1 / getSpeed(currentPlayer)); canMove = false
      if checkForCollision(Dimension, PlayerX - 1, PlayerY) then return end
      if OffsetX > 0 then checkOffset(-1) end
      if PlayerX > 1 then setCoordinates(currentPlayer, "sub1") end

    elseif (eventData[2] == 32 or eventData[2] == 205) then -- Right Key
      if not isSingleplayer() then sendPacket("right"); return end
      setDirection(currentPlayer, 2)
      --if not canMove then return end; moveTimer = os.startTimer(1 / getSpeed(currentPlayer)); canMove = false
      if checkForCollision(Dimension, PlayerX + 1, PlayerY) then return end
      if OffsetX < Width - ScreenWidth then checkOffset(1) end
      if PlayerX < Width then setCoordinates(currentPlayer, "add1") end

    elseif eventData[2] == 18 then -- E
      --if multiplayer then getData(textutils.serialize({currentPlayer, "interact"})); return end
      local interactionCoords = {getFacingCoords(currentPlayer)}
      local Block = getData(Dimension, interactionCoords[1], interactionCoords[2]).Block
      --currentInterface = Menu.getInterface("Inventory"); if not Block then return end
      currentInterface = "Inventory"
      if Block and Block.ID then 
        if Crafting.isCraftingTable(Block.ID) then currentInterface = Menu.getInterface("Crafting") 
        elseif Assets[Block.ID].interface then currentInterface = Assets[Block.ID].interface end
      end

    elseif eventData[2] == 14 then currentInterface = Menu.getInterface("PauseMenu") -- Backspace
    elseif eventData[2] == 42 then lockDirection(currentPlayer, not lockedDirection(currentPlayer)) -- Shift
    elseif eventData[2] == 59 then hideGUI = not hideGUI -- F1
    --elseif eventData[2] == 60 then Entity.spawnEntity(400, Dimension, PlayerX + 1, PlayerY) -- F2
    elseif eventData[2] == 61 then debugMode = not debugMode  -- F3
    elseif eventData[2] == 57 then useItem(currentPlayer); canRegenEnergy(currentPlayer, false); Timer.restart(energyRegenTimer) --if multiplayer then getData(textutils.serialize({"Player", "useItem"})); return end -- Space Bar
    elseif eventData[2] == 20 then currentInterface = Menu.getInterface("Chat"); os.queueEvent("key", 14) -- T
    elseif eventData[2] == 53 then currentInterface = Menu.getInterface("Chat") end -- /

  elseif eventData[1] == "mouse_scroll" and getMode(currentPlayer) == 1 then selectedAsset = selectedAsset - eventData[2]
  elseif string.find(eventData[1], "mouse_") and getMode(currentPlayer) == 1 then
    if eventData[2] == 1 then
      if Assets[selectedAsset] then
        if Assets[selectedAsset].type == "tile" or Assets[selectedAsset].type == "liquid" then setData(Dimension, eventData[3] + OffsetX, eventData[4] + OffsetY, {Tile = {ID = selectedAsset}})
        elseif Assets[selectedAsset].type == "block" or Assets[selectedAsset].type == "blocktile" then setData(Dimension, eventData[3] + OffsetX, eventData[4] + OffsetY, {Block = {ID = selectedAsset}}) end
      end
    elseif eventData[2] == 2 then setData(Dimension, eventData[3] + OffsetX, eventData[4] + OffsetY, {Block = {ID = false}}) 
    elseif eventData[2] == 3 then 
      local area = Level.getData(Dimension, eventData[3] + OffsetX, eventData[4] + OffsetY) 
      selectedAsset = area.Tile.ID; if area.Block and area.Block.ID then selectedAsset = area.Block.ID end
    end
  end
end

local justOpened, command = true
local function drawInterface(eventData)
  if currentInterface and eventData then
    if justOpened then eventData = {}; justOpened = false end
    if type(currentInterface) == "string" then 
      local interface = Menu.getInterface(currentInterface)
      if interface then command = interface(eventData, currentPlayer) 
      else command = Interface.updateInterface(currentInterface, eventData, currentPlayer) end

    elseif type(currentInterface) == "function" then command = currentInterface(eventData, currentPlayer) end
    if command then currentInterface = false; justOpened = true end; if command == "quit" then File.saveWorld(File.getCurrentWorldName()); setPlayers({}); setInGame(false) return true end
  end 
end

function singlePlayer()
  OffsetX, OffsetY = Level.getOffset(); checkOffset()
  Level.setSingleplayer(true); setInGame(true); fadeScreenIn(true)
  local gameTick, gameTickWentOff, lastTime = os.startTimer(clientTick), false, os.time()

  while isInGame() and isSingleplayer() do 
    local eventData = {coroutine.yield()}; World = getWorld(); gameTickWentOff = false
    if eventData[1] == "term_resize" then ScreenWidth, ScreenHeight = Screen.getSize(); _G.Screen.Width, _G.Screen.Height = ScreenWidth, ScreenHeight; updateScreen() 
    elseif eventData[1] == "timer" and eventData[2] == gameTick then 
      gameTickWentOff, gameTick = true, os.startTimer(clientTick)
      updateGame(); updateScreen(); updateTimers()

      if Timer.wentOff(energyRegenTimer) then canRegenEnergy(currentPlayer, true) end
      if Timer.wentOff(saveWorldTimer) then File.saveWorld(File.getCurrentWorldName()); Chat.sendMessage("/say World Saved", currentPlayer); Timer.restart(saveWorldTimer) end
      if Timer.wentOff(moveTimer) then canMove = true end
    elseif not currentInterface then inputHandler(eventData) end

    if currentInterface then drawInterface(eventData); drawScreen() end; local currentTime = os.time()
    if (currentTime - lastTime) >= 0.002 then gameTick = os.startTimer(clientTick); lastTime = currentTime end
    --if Timer.wentOff(failsafe) and not gameTickWentOff then gameTick = os.startTimer(clientTick); Timer.restart(failsafe) end
  end
  setInGame(false); lasttime = os.time()
end

function multiplayer()
  modem.open(ip); Level.setSingleplayer(false); setInGame(true); sendPacket("join")
  local gameTick = os.startTimer(clientTick); checkOffset()
  while isInGame() and not isSingleplayer() do 
    local eventData = {os.pullEvent()}; World = getWorld() 
    if eventData[1] == "term_resize" then ScreenWidth, ScreenHeight = Screen.getSize(); _G.Screen.Width, _G.Screen.Height = ScreenWidth, ScreenHeight; updateScreen() end
    if eventData[1] == "timer" then
      if eventData[2] == gameTick then
        gameTick = os.startTimer(clientTick)
        updateGame(); 
        updateScreen()
      end
    elseif not currentInterface then inputHandler(eventData) end
    if currentInterface then drawInterface(eventData); drawScreen() end
  end
  Level.setSingleplayer(true); setInGame(false); modem.close(ip)
end 

fadeScreenIn(true)
local gameTick = os.startTimer(clientTick)
local gameTickWentOff = false
local fails = 0
local lasttime = os.time()

while true do
  local eventData = {os.pullEvent()}; gameTickWentOff = false
  if eventData[1] == "term_resize" then ScreenWidth, ScreenHeight = currentTerm.getSize(); _G.Screen.Width, _G.Screen.Height = ScreenWidth, ScreenHeight; drawScreen() 
  elseif eventData[1] == "timer" and eventData[2] == gameTick then 
    gameTick = os.startTimer(clientTick); updateScreen(true); Menu.getInterface("StartMenu")({""}, demoDimension); drawScreen()  
    --if Timer.wentOff(failsafe) then Timer.restart(failsafe) end; gameTickWentOff = true
  elseif eventData[1] == "key" or string.find(eventData[1], "mouse_") or eventData[1] == "char" then 
    local action = Menu.getInterface("StartMenu")(eventData, demoDimension); drawScreen()  
    if action == "singlePlayer" then hideGUI = false; Width, Height = getSize(); World = getWorld(); currentTime = getTime(); singlePlayer()
    elseif action == "multiplayer" then hideGUI = false; drawScreen(); multiplayer() end
  end

  local currentTime = os.time()
  if (currentTime - lasttime) >= 0.002 then gameTick = os.startTimer(clientTick); lasttime = currentTime end
 -- if Timer.wentOff(failsafe) and not gameTickWentOff then gameTick = os.startTimer(clientTick); Timer.restart(failsafe) end
end