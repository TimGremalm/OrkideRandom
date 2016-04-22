pinButtonWifi = 3
buttonHasBeenRelesed = true
isConnectedToNetwork = false
isMoist = false

pinMoistSensor = 7

ledWS2812 = {}
ledWS2812.pin = 5
ledWS2812.leds = 12

randomFetched = false
randomLastFetched = -300000000

stateNotConnected = 0
stateError = 1
stateNeedWater = 2
stateRandomize = 3

randomizeStartTime = 0
randomizeStartValueA = 0
randomizeStartValueB = 0

randomizeGoalTime = 0
randomizeGoalValueA = 0
randomizeGoalValueB = 0

function wificonfig()
	enduser_setup.start(
		function()
			print("Connected to wifi as:" .. wifi.sta.getip())
			isConnectedToNetwork = true
		end,
		function(err, str)
			print("enduser_setup: Err #" .. err .. ": " .. str)
			isConnectedToNetwork = false
		end
	);
end

function checkRandomSeed()
	if isConnectedToNetwork then
		--print("Time: "..tmr.now())
		--print("Last: "..randomLastFetched)
		--print("Diff: "..tmr.now() - randomLastFetched)
		if tmr.now() - randomLastFetched > 300000000 then
			print("Checking random seed at random.org...")
			conn = nil
			conn = net.createConnection(net.TCP, 0)

			-- show the retrieved web page
			conn:on("receive", function(conn, payload)
					parsePayload(payload)
					end)

			-- once connected, request page (send parameters to a php script)
			conn:on("connection", function(conn, payload)
					print('\nConnected')
					conn:send("GET /random.php"
					.." HTTP/1.1\r\n"
					.."Host: tim.gremalm.se\r\n"
					.."Connection: close\r\n"
					.."Accept: */*\r\n"
					.."User-Agent: Mozilla/4.0 "
					.."(compatible; esp8266 Lua; "
					.."Windows NT 5.1)\r\n"
					.."\r\n")
					end)

			-- when disconnected, let it be known
			conn:on("disconnection", function(conn, payload) print('\nConnection closed') end)

			conn:connect(80,'tim.gremalm.se')
		end
	else
		fetchFailed("Not connected to network")
	end
end

function fetchFailed(sError)
	randomFetched = false
	print("Fetch failed. "..sError)
end

function splitInTwo(inputString, Separator)
	local start = string.find(inputString, Separator, 1)
	local a = ""
	local b = ""
	if start == nil then
		a = inputString
		b = ""
	else
		a = string.sub(inputString, 1, start-1)
		b = string.sub(inputString, start)
	end
	return a, b
end

function parsePayload(sPayload)
	print("Payload received")

	--Remove HTTP header
	local iDoubleNewline = string.find(sPayload, "\r\n\r\n", 1)
	if iDoubleNewline ~= nil then
		iDoubleNewline = iDoubleNewline + 4
		sPayload = string.sub(sPayload, iDoubleNewline)

		--Get first line
		local iNextNewline = string.find(sPayload, "\n", 1)
		if iNextNewline ~= nil then
			currentRow = string.sub(sPayload, 1, iNextNewline-1)
			print("Current row: "..currentRow)
			local randomSeed = tonumber(currentRow)
			if randomSeed ~= nil then
				randomFetched = true
				randomLastFetched = tmr.now()
				math.randomseed(randomSeed)
				print("Random seed is: "..randomSeed)
			else
				fetchFailed("No a number")
			end
		else
			fetchFailed("No next line")
		end
	else
		fetchFailed("Missing HTTP header double CRLF")
	end
end

function checkGPIO()
	if buttonHasBeenRelesed == true and gpio.read(pinButtonWifi) == 0 then
		print("Enter WiFi Setup")

		--Clear old config
		wifi.sta.config("","")

		isConnectedToNetwork = false

		wificonfig()

		buttonHasBeenRelesed = false
	end
	if buttonHasBeenRelesed == false and gpio.read(pinButtonWifi) == 1 then
		print("Button released")
		buttonHasBeenRelesed = true
	end
	
	--Check moisture sensor
	if gpio.read(pinMoistSensor) == 1 then
		isMoist = false
	else
		isMoist = true
	end
end

function render()
	local renderState = stateRandomize
	if randomFetched == false then
		renderState = stateError
	end
	if isConnectedToNetwork == false then
		renderState = stateNotConnected
	end
	if isMoist == false then
		renderState = stateNeedWater
	end


	if renderState == stateError then
		renderError()
	end
	if renderState == stateNeedWater then
		renderNeedWater()
	end
	if renderState == stateNotConnected then
		renderNotConnected()
	end
	if renderState == stateRandomize then
		renderRandomize()
	end
end

--Convert HSL to RGB using integers
--based on https://github.com/mjackson/mjijackson.github.com/blob/master/2008/02/rgb-to-hsl-and-rgb-to-hsv-color-model-conversion-algorithms-in-javascript.txt
--H 0-360
--S 0-100
--L 0-100
function hue2rgb360(p, q, t)
	t = t % 360
	if t < 60 then
		return p + (((((q - p)*100) / 60) * t) / 100)
	end
	if t < 180 then
		return q
	end
	if t < 240 then
		return p + (q - p) * (240 - t) / 60
	end
	return p
end
function HSLtoRGB(h, s, l)
	if s == 0 then
		r, g, b = l, l, l
	else
		if l < 50 then
			q = (l * (100 + s))/100
		else
			q = l + s - ((l * s)/100)
		end
		p = 2 * l - q

		r = hue2rgb360(p, q, h + 120)
		g = hue2rgb360(p, q, h)
		b = hue2rgb360(p, q, h - 120)
	end

	r = (r*255)/100
	g = (g*255)/100
	b = (b*255)/100

	return r,g,b
end

function renderError()
	local pixelArray = ""
	for i=1,ledWS2812.leds do
		local colorR,colorG,colorB = HSLtoRGB(0, 100, 50)
		local colorPixel = string.char(colorR, colorG, colorB)
		pixelArray = pixelArray .. colorPixel
	end
	ws2812.writergb(ledWS2812.pin, pixelArray)
end

function renderNeedWater()
	local pixelArray = ""
	for i=1,ledWS2812.leds do
		local colorR,colorG,colorB = HSLtoRGB(200, 100, 70)
		local colorPixel = string.char(colorR, colorG, colorB)
		pixelArray = pixelArray .. colorPixel
	end
	ws2812.writergb(ledWS2812.pin, pixelArray)
end

function renderNotConnected()
	local pixelArray = ""
	for i=1,ledWS2812.leds do
		local colorR,colorG,colorB = HSLtoRGB(50, 70, 50)
		local colorPixel = string.char(colorR, colorG, colorB)
		pixelArray = pixelArray .. colorPixel
	end
	ws2812.writergb(ledWS2812.pin, pixelArray)
end

function renderRandomize()
	--Time to choose new goal values?
	if tmr.now() > randomizeGoalTime then
		--print("Choose new goal")
		randomizeStartTime = tmr.now()
		randomizeStartValueA = randomizeGoalValueA
		randomizeStartValueB = randomizeGoalValueB

		randomizeGoalTime = randomizeStartTime + 5000000
		randomizeGoalValueA = math.random(0, 359)
		randomizeGoalValueB = math.random(0, 359)
	end

	--Calculate and interpolate from start to goal
	local timeDuration = randomizeGoalTime - randomizeStartTime
	local timeFromStart = tmr.now() - randomizeStartTime
	local timeRatio = timeFromStart / timeDuration

	local closestA = closestDistance(randomizeStartValueA, randomizeGoalValueA) * timeRatio
	local posA = randomizeStartValueA + closestA
	posA = math.floor(posA) % 360
	local closestB = closestDistance(randomizeStartValueB, randomizeGoalValueB) * timeRatio
	local posB = randomizeStartValueB + closestB
	posB = math.floor(posB) % 360

	local iLedRatio = 1 / ledWS2812.leds
	local closestHuePath = closestDistance(posA, posB) * iLedRatio
	local pixelArray = ""
	for i=1,ledWS2812.leds do
		local iLedHue = i * closestHuePath
		iLedHue = math.floor(iLedHue) % 360
		local colorR,colorG,colorB = HSLtoRGB(iLedHue, 100, 50)
		local colorPixel = string.char(colorR, colorG, colorB)
		pixelArray = pixelArray .. colorPixel
	end
	ws2812.writergb(ledWS2812.pin, pixelArray)
end
function closestDistance(posStart, posEnd)
	local small = 0
	local big = 0
	local direction = 0
	if posStart < posEnd then
		small = posStart
		big = posEnd
		direction = 1
	else
		small = posEnd
		big = posStart
		direction = -1
	end

	local distanceInner = big - small
	local distanceOuter = small + (360-big)
	local distance = 0
	if distanceInner < distanceOuter then
		distance = distanceInner * direction * 1
	else
		distance = distanceOuter * direction * -1
	end
	return distance
end

function initOrkideRandom()
	print("Loading OrkideRandom")

	--Connect to WiFi or open
	wificonfig()

	--Prepare wifi-button and moisture sensor
	gpio.mode(pinButtonWifi, gpio.INPUT, gpio.FLOAT)
	gpio.mode(pinMoistSensor, gpio.INPUT, gpio.FLOAT)
	tmr.alarm(1, 100, 1, function() checkGPIO() end)

	--Check for new random feed
	tmr.alarm(2, 10000, 1, function() checkRandomSeed() end)

	--Start render
	tmr.alarm(3, 100, 1, function() render() end)
end
initOrkideRandom()

