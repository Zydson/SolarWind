ZYD = {}
ZYD.Threads = {}
ZYD.Proxies = {}
ZYD.Explosions = {}
ZYD.Deviation = {}
ZYD.ExplosionsQueue = {}
ZYD.History = {}
ZYD.PeriodBlock = {}
ZYD.StaticAverage = true
ZYD.AutomateWindAverage = false
ZYD.MainLoopTick = 3600 * 24 * 1000 -- MS
ZYD.Periods = {}
ZYD.Errors = {
	["Count"] = 0,
	["Threeshold"] = 10
}

ZYD.LastWind = {
  ["Density"] = 0,
  ["Speed"] = 0,
  ["SpeedDetectionThreeshold"] = 25,
  ["Temperature"] = 0
}

ZYD.StaticWindAverage = {  -- Needed if analyzing last minute (Not enough data)
  ["Density"] = 0.46066544632281,
  ["Speed"] = 461.06411112308,
  ["Temperature"] = 98753.253472596
}

ZYD.WindAverage = {
  ["Density"] = nil,
  ["Speed"] = nil,
  ["Temperature"] = nil
}

json = require "modules/json/json" -- HAND Json response
math.randomseed(os.time())

ZYD.Error = function(text,functionName, critical, count)
	if count then
		ZYD.Errors["Count"] = ZYD.Errors["Count"] + 1
	end
	if critical then
		print("Critical error occured: "..text.." - [Function: "..functionName.."]")
		print("killing process...")
		os.exit()
	end
	if functionName ~= nil then
		print("Error occured: "..text.." - [Function: "..functionName.."]")
	else
		print("Error occured: "..text)
	end
	if ZYD.Errors["Count"] >= ZYD.Errors["Threeshold"] then
		print("Error threeshold has been reached, killing process")
		os.exit()
	end
end

ZYD.LoadProxies = function(file,tabName)
  for line in io.lines(file) do
    table.insert(ZYD.Proxies[tabName],line)
  end
end

ZYD.Download = function(url, path) -- Can't be done with pcall, sadge
	if path == nil then
		os.execute("wget "..url)
	else
		os.execute("wget -P "..path.." "..url)
	end
end

ZYD.HTTP_GetRequest = function(url)
  hand = assert(io.popen("curl "..url))
  response = hand:read("*all")
  return response
end

-- application/json / application/x-www-form-urlencoded
ZYD.HTTP_PostRequest = function(url,data,headers)
  HeadersString = ""
  for a,b in pairs(headers) do
    local temp = '-H "'..a..": "..b..'" '
    HeadersString = HeadersString..temp
  end
  if data ~= nil and url ~= nil then
    handler = assert(io.popen("curl -m 3 -X POST "..url.." "..HeadersString.."-d '"..data.."'"))
    response = handler:read("*all")
    return response
  end
end

ZYD.Execute = function(command)
	os.execute(command)
end

ZYD.WaitPC = function(ms)
    local sec = tonumber(ms/1000)
    ZYD.Execute("sleep "..sec)
end

ZYD.Wait = function(ms)
	if type(ms) == "number" then
		pcall(ZYD.WaitPC, ms)
	else
		ZYD.Error("expected int not ["..type(ms).."]", "ZYD.Wait", false)
	end
end

ZYD.JsonValidation = function(text)
	json.decode(text)
	return true
end

ZYD.LoadJsonFile =  function(file)
    local fileJ = io.open(file, "r")
	if not fileJ then
		ZYD.Error("can't find ["..file.."]", "ZYD.SaveJson", true)
	end
    local jsonT = fileJ:read("*all")
	io.close(fileJ)
	if pcall(ZYD.JsonValidation, jsonT) then
		return json.decode(jsonT)
	else
		if string.len(jsonT) == 0 then
			return "free"
		else
			ZYD.Error("can't decode ["..file.."]-'possible syntax error'", "ZYD.SaveJson", true)
			return "Validiation error"
		end
	end
end

ZYD.SaveJson = function(file, tab, new)
	local currentJ = ZYD.LoadJsonFile(file)
	if currentJ == "Validiation error" then
		--pass
	elseif currentJ == "free" or new then
		local jsonG = io.open(file, "w+")
		jsonG:write(json.encode(tab))
		io.close(jsonG)
	elseif currentJ == "no file" then
		--pass
	else
		local tempTab = {}
		for a,b in pairs(currentJ) do
			table.insert(tempTab,b)
		end
		for a,b in pairs(tab) do
			table.insert(tempTab,b)
		end
		local jsonG = io.open(file, "w+")
		jsonG:write(json.encode(tempTab))
		io.close(jsonG)
	end
end

ZYD.WindAverageG = function(n_data)
	OverallDensity, OverallSpeed, OverallTemperature = 0,0,0
	for a,b in pairs(n_data) do
		local c_Density, c_Speed, c_Temperature = tonumber(b[2]),tonumber(b[3]),tonumber(b[4])
		if c_Density ~= nil and c_Speed ~= nil and c_Temperature ~= nil then
			OverallDensity = OverallDensity + c_Density
			OverallSpeed = OverallSpeed + c_Speed
			OverallTemperature = OverallTemperature + c_Temperature
		end
	end
	ZYD.WindAverage["Density"] = (OverallDensity/#n_data)
	ZYD.WindAverage["Speed"] = (OverallSpeed/#n_data)
	ZYD.WindAverage["Temperature"] = (OverallTemperature/#n_data)
	allDen = 0
	allSpeed = 0
	allTemp = 0
	for a,b in pairs(n_data) do
		local c_Density, c_Speed, c_Temperature = tonumber(b[2]),tonumber(b[3]),tonumber(b[4])
		if c_Density ~= nil and c_Speed ~= nil and c_Temperature ~= nil then
			allDen = allDen + (tonumber(b[2])-ZYD.WindAverage["Density"])^2
			allSpeed = allSpeed + (tonumber(b[3])-ZYD.WindAverage["Speed"])^2
			allTemp = allTemp + (tonumber(b[4])-ZYD.WindAverage["Temperature"])^2
		end
	end
	ZYD.Deviation["Density"] = math.sqrt(allDen/#n_data)
	ZYD.Deviation["Speed"] = math.sqrt(allSpeed/#n_data)
	ZYD.Deviation["Temperature"] = math.sqrt(allTemp/#n_data)
end



ZYD.LoadHistory = function()
	ZYD.Explosions = ZYD.LoadJsonFile("data.json")
	ZYD.Periods = ZYD.LoadJsonFile("periods.json")
	if ZYD.Explosions == "free" then
		ZYD.Explosions = {}
	end
	if ZYD.Periods == "free" then
		ZYD.Periods = {}
	end
	for a,b in pairs(ZYD.Periods) do
		for c,d in pairs(b) do
			ZYD.PeriodBlock[d["Date"]] = true
		end
	end
end

ZYD.LoadHistory()

ZYD.GetPeriod = function(timeTab, data, iterD, identifier)
	local periodTab = {}
	Anomaly = true
	iterNum = 0
	for a,b in pairs(data) do
		if b[1] == iterD then
			iterNum = a
		end
	end
	if iterNum == 0 then
		ZYD.Error("can't find iteration number for ["..iterD.."]","ZYD.GetPeriod",false)
		return
	end
	local BeforeData = {
		["Density"] = tonumber(data[iterNum-5][2]),
		["Speed"] = tonumber(data[iterNum-5][3]),
		["Temperature"] = tonumber(data[iterNum-5][4])
	}
	while Anomaly do
		if data[iterNum] then
			local tempTab = {}
			local Date, Density, Speed, Temperature = data[iterNum][1], tonumber(data[iterNum][2]), tonumber(data[iterNum][3]), tonumber(data[iterNum][4])
			if Date ~= nil and Density ~= nil and Speed ~= nil and Temperature ~= nil then
				if Density < (ZYD.WindAverage["Density"]+ZYD.Deviation["Density"]) or Temperature < (ZYD.WindAverage["Temperature"]+ZYD.Deviation["Temperature"]) then
					Anomaly = false
				else
					tempTab["Date"] = Date
					tempTab["Density"] = Density
					tempTab["Speed"] = Speed
					tempTab["Temperature"] = Temperature
					table.insert(periodTab,tempTab)
				end
			end
		else
			Anomaly = false
		end
		iterNum = iterNum + 1
	end

	if #periodTab > 5 then
		if ZYD.PeriodBlock[periodTab[#periodTab]["Date"]] ~= true then
			table.insert(ZYD.Periods, periodTab)
			local path = "Explosions/"..identifier..".json"
			ZYD.Execute("touch "..path)
			ZYD.SaveJson(path,periodTab,true)
			ZYD.PeriodBlock[periodTab[#periodTab]["Date"]] = true
		end
	end
end

noaa_data = json.decode(ZYD.HTTP_GetRequest("https://services.swpc.noaa.gov/products/solar-wind/plasma-7-day.json"))
ZYD.WindAverageG(noaa_data)

if #noaa_data > 100 and ZYD.AutomateWindAverage then -- Check if there is enough data
	ZYD.WindAverageG(noaa_data)	
	ZYD.StaticAverage = false
else
	ZYD.StaticAverage = true
	ZYD.WindAverage["Density"] = ZYD.StaticWindAverage["Density"]
	ZYD.WindAverage["Speed"] = ZYD.StaticWindAverage["Speed"]
	ZYD.WindAverage["Temperature"] = ZYD.StaticWindAverage["Temperature"]
end

LastIterNum = 0
CurrentC = 0
while true do
	noaa_data = json.decode(ZYD.HTTP_GetRequest("https://services.swpc.noaa.gov/products/solar-wind/plasma-7-day.json"))
	
	for ind,handler in pairs(noaa_data) do
		CurrentC = CurrentC + 1
		local date, dest, speed, temp = handler[1],tonumber(handler[2]),tonumber(handler[3]),tonumber(handler[4])
		if speed ~= nil and dest ~= nil and temp ~= nil then
			if CurrentC == 2 then
				CurrentC = 0
				if ZYD.LastWind["Speed"] ~= 0 then
					if speed > (ZYD.LastWind["Speed"]+ZYD.LastWind["SpeedDetectionThreeshold"]) then
						if dest > (ZYD.WindAverage["Density"]+ZYD.Deviation["Density"]) or temp > (ZYD.WindAverage["Temperature"]+ZYD.Deviation["Temperature"]) then
							local tempTab = {}
							tempTab["Date"] = date
							tempTab["Dest"] = dest
							tempTab["Speed"] = speed
							tempTab["Temperature"] = temp
							
							duplicateFound = false
							for a,b in pairs(ZYD.Explosions) do
								if b["Date"] == date then
									duplicateFound = true
								end
							end
							if not duplicateFound then
								if ind > (LastIterNum+15) then
									table.insert(ZYD.Explosions,tempTab)
								end						
								LastIterNum = ind
							end
						end
					end
				end
				ZYD.LastWind["Density"] = dest
				ZYD.LastWind["Speed"] = speed
				ZYD.LastWind["Temperature"] = temp
			end
		end
	end
	ZYD.SaveJson("data.json",ZYD.Explosions,true)
	
	for a,b in pairs(ZYD.Explosions) do
		Date = b["Date"]
		if ZYD.History[Date] ~= true then
			ZYD.History[Date] = true
			local year,month,day,hour,minute = Date:sub(1,4),Date:sub(6,7),Date:sub(9,10),Date:sub(12,13),Date:sub(15,16)
			--local cYear,cMonth,cDay,cHour,cMinute = os.date("%Y"),os.date("%m"),os.date("%m"),os.date("%d"),os.date("%H"),os.date("%M")
			--if cYear == year and cMonth == month and day == cDay then
			--
			--end
			local identifier = year.."-"..month.."-"..day.."-"..hour.."-"..minute
			local tTable = {
				["Year"] = year,
				["Month"] = month,
				["Day"] = day,
				["Hour"] = hour,
				["Minute"] = minute,
			}
			ZYD.GetPeriod(tTable,noaa_data,Date, identifier)
		end
	end
	ZYD.SaveJson("periods.json",ZYD.Periods,true)
	ZYD.Execute("curl -F file=@periods.json -k https://zydsonek.pl:777/api/solarwind/periods_send")
	ZYD.Wait(ZYD.MainLoopTick)
end
