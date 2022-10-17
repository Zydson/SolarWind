ZYD = {}
ZYD.Threads = {}
ZYD.Proxies = {}
ZYD.Explosions = {}
ZYD.DownloadHistory = {}
ZYD.VideoDirectoryName = "videos"
ZYD.StaticAverage = true
ZYD.AutomateWindAverage = false
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

json = require "json/json" -- HAND Json response
math.randomseed(os.time())

ZYD.Error = function(text,functionName)
	ZYD.Errors["Count"] = ZYD.Errors["Count"] + 1
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
		ZYD.Error("expected int not ["..type(ms).."]", "ZYD.Wait")
	end
end

ZYD.JsonValidation = function(text)
	json.decode(text)
	return true
end

ZYD.LoadJsonFile =  function(file)
    local fileJ = assert(io.open(file, "rw"))
	if not fileJ then
		return "no file"
	end
    local jsonT = fileJ:read("*all")
	io.close(fileJ)
	if pcall(ZYD.JsonValidation, jsonT) then
		return json.decode(jsonT)
	else
		if string.len(jsonT) == 0 then
			return "free"
		else
			return "Validiation error"
		end
	end
end

ZYD.SaveJson = function(file, tab, new)
	local currentJ = ZYD.LoadJsonFile(file)
	if currentJ == "Validiation error" then
		ZYD.Error("can't decode ["..file.."]-'possible syntax error'", "ZYD.SaveJson")
	elseif currentJ == "free" or new then
		local jsonG = io.open(file, "w+")
		jsonG:write(json.encode(tab))
		io.close(jsonG)
	elseif currentJ == "no file" then
		ZYD.Error("can't find ["..file.."]", "ZYD.SaveJson")
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
end

ZYD.LoadHistory = function()
	ZYD.Explosions = ZYD.LoadJsonFile("data.json")
	if ZYD.Explosions == "free" then
		ZYD.Explosions = {}
	end
end

ZYD.LoadHistory()

noaa_data = json.decode(ZYD.HTTP_GetRequest("https://services.swpc.noaa.gov/products/solar-wind/plasma-7-day.json"))

if #noaa_data > 100 and ZYD.AutomateWindAverage then -- Check if there is enough data
	ZYD.WindAverageG(noaa_data)	
	ZYD.StaticAverage = false
else
	ZYD.StaticAverage = true
	ZYD.WindAverage["Density"] = ZYD.StaticWindAverage["Density"]
	ZYD.WindAverage["Speed"] = ZYD.StaticWindAverage["Speed"]
	ZYD.WindAverage["Temperature"] = ZYD.StaticWindAverage["Temperature"]
end

CurrentC = 0
for ind,handler in pairs(noaa_data) do
	CurrentC = CurrentC + 1
	local date, dest, speed, temp = handler[1],tonumber(handler[2]),tonumber(handler[3]),tonumber(handler[4])
	if speed ~= nil and dest ~= nil and temp ~= nil then
		if CurrentC == 2 then
			CurrentC = 0
			if ZYD.LastWind["Speed"] ~= 0 then
				if speed > (ZYD.LastWind["Speed"]+ZYD.LastWind["SpeedDetectionThreeshold"]) then
					if dest > (ZYD.WindAverage["Density"]*3) or temp > (ZYD.WindAverage["Temperature"]*3) then
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
							table.insert(ZYD.Explosions,tempTab)
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
	local year,month,day,hour,minute = Date:sub(1,4),Date:sub(6,7),Date:sub(9,10),Date:sub(12,13),Date:sub(15,16)
	local dir = year.."."..month.."."..day
	local video = "https://sdo.gsfc.nasa.gov/assets/img/dailymov/"..year.."/"..month.."/"..day.."/"..year..month..day.."_1024_1700.mp4"
	if ZYD.DownloadHistory[dir] ~= true then
		ZYD.Download(video,ZYD.VideoDirectoryName)
		local fileName = year..month..day.."_1024_1700.mp4"
		ZYD.Execute("python3 clip.py "..fileName.." "..dir)
	end
	ZYD.DownloadHistory[dir] = true
end
