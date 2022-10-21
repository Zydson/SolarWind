ZYD = {}
ZYD.Noaa = {}
ZYD.NoaaCheckList = {}
json = require "modules/json/json"
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

ZYD.LoadHistory = function()
	local temp = ZYD.LoadJsonFile("noaa_data.json")
	if temp == "free" then
		ZYD.Noaa = {}
	else
		ZYD.Noaa = temp
		for a,b in pairs(temp) do
			local date = b[1]
			if date ~= nil then
				ZYD.NoaaCheckList[date] = true
			end
		end
	end
end

ZYD.LoadHistory()

while true do
	noaa_data = json.decode(ZYD.HTTP_GetRequest("https://services.swpc.noaa.gov/products/solar-wind/plasma-7-day.json"))
	for a,b in pairs(noaa_data) do
		local date = b[1]
		if date ~= nil and date ~= "time_tag" then
			if ZYD.NoaaCheckList[date] ~= true then
				table.insert(ZYD.Noaa,b)
			end
		end
	end
	ZYD.SaveJson("noaa_data.json",ZYD.Noaa,true)
	ZYD.Wait(30000)
end
