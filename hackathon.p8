pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--game of death
--by computereindringlinge

BLACK = 0
DARK_BLUE = 1
DARK_PURPLE = 2
DARK_GREEN = 3
BROWN = 4
DARK_GREY = 5
LIGHT_GREY = 6
WHITE = 7
RED = 8
ORANGE = 9
YELLOW = 10
GREEN = 11
BLUE = 12
LAVENDER = 13
PINK = 14
LIGHT_PEACH = 15

AS_IS = 0
SECONDS = 1
PERCENTAGE = 2
PROMILLAGE = 3

function createConfig(value, min, max, step, displayName, displayMode)
  return {
    value = value,
    min = min,
    max = max,
    step = step,
    displayName = displayName,
    displayMode = displayMode or AS_IS
  }
end

function createPercentageConfig(value, displayName)
  return createConfig(value, 0, 1, 0.05, displayName, PERCENTAGE)
end

mapWidth = 128
mapHeight = 128

people = {}
peopleAmount = createConfig(500, 100, 1000, 100, "population")
bedAmount = createConfig(5, 0, 500, 10, "intensivbetten")
peopleSize = 1 -- Der Radius
turnChance = 0.75

peopleLayer = {}

distanceForInfection = createConfig(1, 1, 5, 1, "mindestabstand")
keepDistanceChance = createPercentageConfig(0.5, "abstand-halten-chance")

infectionChanceNeighbour = createPercentageConfig(0.5, "infektionsrate")
infectionChanceMaskInfectingOthers = createPercentageConfig(0.1, "infektion anderer trotz maske")
infectionChanceMaskGettingInfected = createPercentageConfig(0.2, "infektion selbst trotz maske")
initialChanceToWearMask = createPercentageConfig(0.25, "anzahl maskentraeger")
vacinationRate = createConfig(0.01, 0, 1, 0.01, "geimpfte pro knopfdruck", PERCENTAGE)
immunityIncrease = createConfig(0.005, 0, 1, 0.001, "immunitaetssteigerung nach impfung", PROMILLAGE)

infectionDelay1 = createConfig(150, 0, 2 * 60 * 15, 5 * 15, "dauer gelb", SECONDS) -- INCUBATION_PERIOD_NOT_INFECTIOUS -> INCUBATION_PERIOD_INFECTIOUS
infectionDelay2 = createConfig(300, 0, 2 * 60 * 15, 5 * 15, "dauer orange", SECONDS)  -- INCUBATION_PERIOD_INFECTIOUS -> INFECTED oder INFECTED_ASYMPTOMATIC
infectionDuration = createConfig(150, 0, 2 * 60 * 15, 5 * 15, "dauer rot", SECONDS) -- INFECTED oder INFECTED_ASYMPTOMATIC -> CURED oder DEAD
asymptomaticChance = createPercentageConfig(0.05, "asymptomatischer-verlauf-chance")
heavyInfectionChance = createPercentageConfig(0.2, "schwerer-verlauf-chance")
chanceForDeath = createPercentageConfig(0.8, "todesrate")
chanceToMoveWhenInfected = 0.25

simulationTickCounter = 0
ticksPerSimulation = 2

INFECTED_TMP = -1
HEALTHY = 0
INCUBATION_PERIOD_NOT_INFECTIOUS = 1
INCUBATION_PERIOD_INFECTIOUS = 2
INFECTED_ASYMPTOMATIC = 3
INFECTED = 4
INFECTED_HEAVILY = 5
CURED = 6
DEAD = 7

confCurrentIndex = 0
configNameLengthMax = 16
configTotalWidth = 88
chosenConfig = 1
configOffsetX = 0
configScrollSpeed = 0.5
config = {}

NOTHING = 0
OPTIONS = 1
STATS = 2
openMenu = NOTHING

UP = 0
UP_RIGHT = 1
RIGHT = 2
DOWN_RIGHT = 3
DOWN = 4
DOWN_LEFT = 5
LEFT = 6
UP_LEFT = 7

function randomDirection()
  return flr(rnd(8))
end

stats = {}

function coordsToIndex(x, y)
  return x .. "," .. y
end

function createPerson(x, y, state, cooldown, wearsMask)
  p = {}
	p.x = x
	p.y = y
  p.state = state
  p.cooldown = cooldown
  p.mask = wearsMask
  p.direction = randomDirection()
  p.vaccinated = false
  p.immunity = rnd() * 0.1
  p.intensiveCare = false

  peopleLayer[coordsToIndex(p.x, p.y)] = p

	return p
end

function pow(num, exponent)
  result = num
  for i=1, exponent do
    result *= exponent
  end
  return result
end

function move(p, newX, newY)
  peopleLayer[coordsToIndex(p.x, p.y)] = nil
  p.x = newX
  p.y = newY
  peopleLayer[coordsToIndex(newX, newY)] = p
end

function createConfigElement(conf)
  confCurrentIndex += 1
  config[confCurrentIndex] = conf
end

function initPeople()
  people = {}
  peopleLayer = {}

  for i=1, peopleAmount.value do
      x = flr(rnd(mapWidth))
      y = flr(rnd(mapHeight))

      state = HEALTHY
      cooldown = 0
      wearsMask = rnd() < initialChanceToWearMask.value

      if i == 1 then
        state = INCUBATION_PERIOD_INFECTIOUS
        cooldown = infectionDelay2.value
        if wearsMask then
          stats.infectedWithMask += 1
        else
          stats.infectedWithoutMask += 1
        end
      end

      people[i] = createPerson(x, y, state, cooldown, wearsMask)
    end
end

function reset()
  simulationTickCounter = 0
  stats.infectedWithMask = 0
  stats.infectedWithoutMask = 0
  stats.deadWithMask = 0
  stats.deadWithoutMask = 0
  stats.vaccinated = 0
  stats.infectedDespiteVaccinated = 0
  stats.cured = 0
  stats.fullyImmunized = 0
  stats.timer = 0
  stats.foundInfected = false
  stats.intensiveCare = 0
  initPeople()
end

function _init()
  --camera(4,4)
  
  reset()

  createConfigElement(peopleAmount)
  createConfigElement(bedAmount)
  createConfigElement(initialChanceToWearMask)
  createConfigElement(distanceForInfection)
  createConfigElement(keepDistanceChance)
  createConfigElement(infectionChanceNeighbour)
  createConfigElement(infectionChanceMaskInfectingOthers)
  createConfigElement(infectionChanceMaskGettingInfected)
  createConfigElement(vacinationRate)
  createConfigElement(immunityIncrease)
  createConfigElement(infectionDelay1)
  createConfigElement(infectionDelay2)
  createConfigElement(infectionDuration)
  createConfigElement(heavyInfectionChance)
  createConfigElement(asymptomaticChance)
  createConfigElement(chanceForDeath)
end

function vacinate()
  for i=1,#people do
    p = people[i]

    if p.state == HEALTHY and not p.vaccinated and rnd() < vacinationRate.value then
      p.vaccinated = true
      stats.vaccinated += 1
    end
  end
end

function _update()
  if btnp(4, 1) then
    if openMenu == OPTIONS then
      openMenu = NOTHING
    else
      openMenu = OPTIONS
    end
  end
  
  if btnp(0, 1) then
    if openMenu == STATS then
      openMenu = NOTHING
    else
      openMenu = STATS
    end
  end

  if openMenu == OPTIONS then
    conf = config[chosenConfig]

    if btnp(➡️) then
      conf.value = min(conf.value + conf.step, conf.max)
    end
    if btnp(⬇️) then
    chosenConfig = min(chosenConfig + 1, #config)
    configOffsetX = 0
    end
    if btnp(⬅️) then
      conf.value = max(conf.value - conf.step, conf.min)
    end
    if btnp(⬆️) then 
    chosenConfig = max(chosenConfig - 1, 1)
    configOffsetX = 0
    end
  end

  if btnp(5) then
    reset()
    return
  end

  if btnp(1, 1) then
    vacinate()
  end

  if simulationTickCounter == 0 then

    stats.foundInfected = false

    for i=1,#people do
      local p = people[i]

      x = p.x
      y = p.y

      if rnd() < turnChance then
        p.direction = randomDirection()
      end

      if p.direction == UP then
        y -= 1
      elseif p.direction == UP_RIGHT then
        y -= 1
        x += 1
      elseif p.direction == RIGHT then
        x += 1
      elseif p.direction == DOWN_RIGHT then
        y += 1
        x += 1
      elseif p.direction == DOWN then
        y += 1
      elseif p.direction == DOWN_LEFT then
        y += 1
        x -= 1
      elseif p.direction == LEFT then
        x -= 1
      elseif p.direction == UP_LEFT then
        y -= 1
        x -= 1
      end
    
      x = (x + mapWidth) % mapWidth
      y = (y + mapHeight) % mapHeight

      mayMove = true

      for n= -distanceForInfection.value, distanceForInfection.value do
        for m= -distanceForInfection.value, distanceForInfection.value do
          p2 = peopleLayer[coordsToIndex(x + n, y + m)]

          if p ~= p2 then

            if p2 ~= nil then

              if (p2.state == INFECTED or p.state == INFECTED_HEAVILY) and rnd() < keepDistanceChance.value then
                mayMove = false
                goto weiter
              end
            end
          end
        end
      end

      ::weiter::

      if mayMove then
        if p.state == DEAD or p.state == INFECTED_HEAVILY then
          -- Nix machen
        elseif p.state == INFECTED  then
          if rnd() < chanceToMoveWhenInfected then
            move(p, x, y)
          end
        else
          move(p, x, y)
        end
      end

      --  INFECTED_HEAVILY wird nicht gezählt, weil die ja hoffentlich keinen Kontakt zu Anderen haben
      if p.state == INFECTED  or p.state == INFECTED_ASYMPTOMATIC or p.state == INCUBATION_PERIOD_INFECTIOUS then

        for n= -distanceForInfection.value, distanceForInfection.value do
          for m= -distanceForInfection.value, distanceForInfection.value do

            if not (n == 0 and m == 0) then
              p2 = peopleLayer[coordsToIndex(x + n, y + m)]

              if p2 ~= nil and p2.state == HEALTHY then
    	          chance = infectionChanceNeighbour.value
                inverseImmunity = 1 - p2.immunity
                chance *= inverseImmunity

                if p.mask then
                  chance *= infectionChanceMaskInfectingOthers.value
                end

                if p2.mask then
                  chance *= infectionChanceMaskGettingInfected.value
                end

                if rnd() < chance then
                  p2.state = INFECTED_TMP

                  if p2.vaccinated then
                    stats.infectedDespiteVaccinated += 1
                  end
                end
              end
            end
          end
        end
      end

      if p.state == INCUBATION_PERIOD_NOT_INFECTIOUS or p.state == INCUBATION_PERIOD_INFECTIOUS or p.state == INFECTED or p.state == INFECTED_HEAVILY or p.state == INFECTED_ASYMPTOMATIC then
        stats.foundInfected = true
      end
    end
  end

  for i=1,#people do
    p = people[i]
    if p.state == INFECTED_TMP then
      p.state = INCUBATION_PERIOD_NOT_INFECTIOUS
      p.cooldown = infectionDelay1.value * (1 - p.immunity)

      if p.mask then
        stats.infectedWithMask += 1
      else
        stats.infectedWithoutMask += 1
      end

    elseif p.state == INCUBATION_PERIOD_NOT_INFECTIOUS and p.cooldown == 0 then
      p.state = INCUBATION_PERIOD_INFECTIOUS
      p.cooldown = infectionDelay2.value * (1 - p.immunity)

    elseif p.state == INCUBATION_PERIOD_INFECTIOUS and p.cooldown == 0 then
      if rnd() * (1 - p.immunity) < asymptomaticChance.value then
        p.state = INFECTED_ASYMPTOMATIC
      elseif rnd() * (1 - p.immunity) < heavyInfectionChance.value then
        p.state = INFECTED_HEAVILY
      else
        p.state = INFECTED
      end
      p.cooldown = infectionDuration.value * (1 - p.immunity)

    elseif (p.state == INFECTED or p.state == INFECTED_HEAVILY or p.state == INFECTED_ASYMPTOMATIC) and p.cooldown == 0 then

      if p.state == INFECTED_HEAVILY and not p.intensiveCare and rnd() < chanceForDeath.value then
        p.state = DEAD

        if p.mask then
          stats.deadWithMask += 1
        else
          stats.deadWithoutMask += 1
        end
      else
        p.state = CURED
        stats.cured += 1
      end

      if p.intensiveCare then
          stats.intensiveCare -= 1
          p.intensiveCare = false
      end
    end

    if p.state == INFECTED_HEAVILY and not p.intensiveCare and stats.intensiveCare < bedAmount.value then
      stats.intensiveCare += 1
      p.intensiveCare = true
    end

    if p.vaccinated and p.state == HEALTHY then
      p.immunity = min(p.immunity + immunityIncrease.value, 1)

      if p.immunity == 1 then
        p.state = CURED
        stats.fullyImmunized += 1
      end
    end

    p.cooldown = max(p.cooldown - 1, 0)
  end

  if stats.foundInfected then
    stats.timer += 1
  end

  simulationTickCounter = (simulationTickCounter + 1) % ticksPerSimulation
  configOffsetX += configScrollSpeed
end

function drawPeople(state)
  for i=1,#people do
	  p = people[i]

    if p.state == state then
      color = 7

      if p.state == HEALTHY then
        color = DARK_GREY
      elseif p.state == INCUBATION_PERIOD_NOT_INFECTIOUS then
        color = YELLOW
      elseif p.state == INCUBATION_PERIOD_INFECTIOUS then
        color = ORANGE
      elseif p.state == INFECTED_ASYMPTOMATIC then
        color = PINK
      elseif p.state == INFECTED then
        color = RED
      elseif p.state == INFECTED_HEAVILY and p.intensiveCare then
        color = DARK_PURPLE
      elseif p.state == INFECTED_HEAVILY then
        color = BROWN
      elseif p.state == CURED then
        color = DARK_GREEN
      elseif p.state == DEAD then
        color = BLACK
      end

      rectfill(p.x - peopleSize, p.y - peopleSize,  p.x + peopleSize, p.y + peopleSize, color)
      
      if p.mask then
        line(p.x - 1, p.y + 1, p.x + 1, p.y + 1, 7)
      end
      
      if p.vaccinated then
        line(p.x - 1, p.y - 1, p.x + 1, p.y - 1, 6)
      end
    end
  end
end

function fillString(string, length, char, left)
  string = string .. ""
  while #string < length do
    if left or false then
      string = char .. string
    else
      string = string .. char
    end
  end

  return string
end

function formatTime(seconds)
  minutes = flr(seconds / 60)
  seconds -= minutes * 60

  return minutes .. ":" .. fillString(seconds, 2, "0", true)
end

function formatNumber(num, decimals)
  withoutDecimals = flr(num)
  length = #(withoutDecimals .. "")
  result = sub(num .. "", 1, length)
  result = result .. "."
  decimalPart = (num - withoutDecimals) .. ""
  if #decimalPart == 1 then
    decimalPart = decimalPart .. "."
  end
  decimalPart = fillString(decimalPart, decimals + 2, "0")
  decimalPart = sub(decimalPart, 3, #decimalPart)
  result = result .. sub(decimalPart, 1, decimals)
  return result
end

function drawConfig(conf, index)
  value = conf.value
  if conf.displayMode == SECONDS then
    value = formatTime(flr(value / (30 / ticksPerSimulation)))
  elseif conf.displayMode == PERCENTAGE then
    value = flr(value * 100 + 0.5) .. "%"
  elseif conf.displayMode == PROMILLAGE then
    value = formatNumber(flr(value * 1000 + 0.5) / 10, 1) .. "%"
  end

  spacer = "    "

  x = 0
  y = (index - 1) * 7
  color = WHITE
  offsetX = x + 1

  key = fillString(conf.displayName, configNameLengthMax, " ")  
  val = fillString(value, 4, " ", true)
  widthClipped = 1 + (4 * 16)
  width = (4 * (#key + #spacer))

  if chosenConfig == index then
    rectfill(x, y, configTotalWidth, y + 6, WHITE)
    color = DARK_GREY
    if (#key > configNameLengthMax) then
      offsetX -= (configOffsetX % width)
    end
  elseif (#key > configNameLengthMax) then
    key = sub(key, 1, configNameLengthMax - 2) .. ".."
  end

  clip(0, 0, widthClipped, mapHeight)
  print(key .. spacer .. key, offsetX, y + 1, color)
  clip()
  print(val, x + 1 + 72, y + 1, color)
end

function filterPopulation(state)
  local result = 0
  for i=1,#people do
    local p = people[i]

    if p.state == state then
      result += 1
    end
  end

  return result
end

function drawBalkendiagramm(x, y, width, height)
  local healthy = filterPopulation(HEALTHY)
  local cured = filterPopulation(CURED)
  local infected = filterPopulation(INCUBATION_PERIOD_NOT_INFECTIOUS) + filterPopulation(INCUBATION_PERIOD_INFECTIOUS) + filterPopulation(INFECTED) + filterPopulation(INFECTED_HEAVILY) + filterPopulation(INFECTED_ASYMPTOMATIC)
  local dead = filterPopulation(DEAD)
  local total = healthy + cured + infected + dead

  local deadX = ceil((dead / total) * (width - 2))
  local curedX = ceil(((cured + dead) / total) * (width - 2))
  local infectedX = ceil(((infected + cured + dead) / total) * (width - 2))

  rectfill(x + 1, y + 1, x + 1 + width - 3, y + height - 1, DARK_GREY)
  if infected > 0 then
    rectfill(x + 1, y + 1, x + 1 + infectedX - 1, y + height - 1, RED)
  end
  if cured > 0 then
    rectfill(x + 1, y + 1, x + 1 + curedX - 1, y + height - 1, GREEN)
  end
  if dead > 0 then
    rectfill(x + 1, y + 1, x + 1 + deadX - 1, y + height - 1, BLACK)
  end

  rect(x, y, x + width - 1, y + height, WHITE)

end

function _draw()
  cls()
  
  rectfill(0, 0, mapWidth - 1, mapHeight - 1, 1)
  -- rect(0, 0, 127, 127, 7)
  
  drawPeople(DEAD)
  drawPeople(HEALTHY)
  drawPeople(CURED)
  drawPeople(INCUBATION_PERIOD_INFECTIOUS)
  drawPeople(INCUBATION_PERIOD_NOT_INFECTIOUS)
  drawPeople(INFECTED_ASYMPTOMATIC)
  drawPeople(INFECTED_HEAVILY)
  drawPeople(INFECTED)

  if openMenu == OPTIONS then
    rectfill(0, 0, configTotalWidth, mapHeight - 1, DARK_GREY)
    line(configTotalWidth + 1, 0, configTotalWidth + 1, 127, WHITE)


    for i=1,#config do
      drawConfig(config[i], i)
    end
  elseif openMenu == STATS then
    rectfill(0, 0, mapWidth, mapHeight - 1, DARK_GREY)

    drawBalkendiagramm(1, 1, mapWidth - 2, 10)
    print("infiziert (mit maske)", 1, 13, WHITE)
    print(fillString(stats.infectedWithMask, 3, " ", true), 116, 13, WHITE)
    print("infiziert (ohne maske)", 1, 20, WHITE)
    print(fillString(stats.infectedWithoutMask, 3, " ", true), 116, 20, WHITE)
    print("tot (mit maske)", 1, 27, WHITE)
    print(fillString(stats.deadWithMask, 3, " ", true), 116, 27, WHITE)
    print("tot (ohne maske)", 1, 34, WHITE)
    print(fillString(stats.deadWithoutMask, 3, " ", true), 116, 34, WHITE)
    print("geimpft", 1, 41, WHITE)
    print(fillString(stats.vaccinated, 3, " ", true), 116, 41, WHITE)
    print("immunisiert", 1, 48, WHITE)
    print(fillString(stats.fullyImmunized, 3, " ", true), 116, 48, WHITE)
    print("geimpft + infiziert", 1, 55, WHITE)
    print(fillString(stats.infectedDespiteVaccinated, 3, " ", true), 116, 55, WHITE)
    print("genesen", 1, 62, WHITE)
    print(fillString(stats.cured, 3, " ", true), 116, 62, WHITE)

    local text = "simulierte sekunden"
    if not stats.foundInfected then
      text = "pandemie vorbei nach"
    end

    print(text, 1, 69, WHITE)
    print(formatTime(flr(stats.timer / (30 / ticksPerSimulation))), 112, 69, WHITE)

    print("-", 62, 76, WHITE)

    print("belegte intensivbetten", 1, 83, WHITE)
    print(fillString(stats.intensiveCare, 3, " ", true), 116, 83, WHITE)
  end

  rectfill(0, 121, mapWidth, 127, DARK_GREY)
  line(0, 120, mapWidth, 120, WHITE)

  if openMenu == OPTIONS then
    rectfill(0, 121, 49, 127, WHITE)
    print("[tab]", 1, 122, DARK_GREY)
    print("options", 22, 122, DARK_GREY)
  else
    print("[tab]", 1, 122, WHITE)
    print("options", 22, 122, WHITE)
  end

  if openMenu == STATS then
    rectfill(55, 121, 88, 127, WHITE)
    print("[s]", 56, 122, DARK_GREY)
    print("stats", 69, 122, DARK_GREY)
  else
    print("[s]", 56, 122, WHITE)
    print("stats", 69, 122, WHITE)
  end

  print("[x] ", 95, 122, WHITE)
  print("reset ", 108, 122, WHITE)

end

__gfx__

__label__

__gff__

__map__

__sfx__

__music__
