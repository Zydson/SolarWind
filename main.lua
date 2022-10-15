ZYD = {}
ZYD.Threads = {}
ZYD.Proxies = {}

ZYD.LastWind = {
  ["Destination"] = 0,
  ["Speed"] = 0,
  ["SpeedDetectionThreeshold"] = 25,
  ["Temperature"] = 0
}

ZYD.WindAverage = {
  ["Destination"] = 0.46066544632281,
  ["Speed"] = 461.06411112308,
  ["Temperature"] = 98753.253472596
}

ZYD.Explosions = {}

json = require "json" -- HAND Json response
math.randomseed(os.time())

ZYD.LoadProxies = function(file,tabName)
  for line in io.lines(file) do
    table.insert(ZYD.Proxies[tabName],line)
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

ZYD.WaitPC = function(ms)
    local sec = tonumber(ms/1000)
    os.execute("sleep "..sec)
end

ZYD.Wait = function(ms)
    pcall(ZYD.WaitPC, ms)
end

ZYD.GetJson =  function(file)
    local fileJ = assert(io.open(file, "rw"))
    local jsonT = fileJ:read("*all")
    return json.decode(jsonT)
end

noaa_data = json.decode(ZYD.HTTP_GetRequest("https://services.swpc.noaa.gov/products/solar-wind/plasma-7-day.json"))

CurrentC = 0
for ind,handler in pairs(noaa_data) do
  CurrentC = CurrentC + 1
  local date, dest, speed, temp = handler[1],tonumber(handler[2]),tonumber(handler[3]),tonumber(handler[4])
  if speed ~= nil and dest ~= nil and temp ~= nil then
  if CurrentC == 2 then
    CurrentC = 0
    if ZYD.LastWind["Speed"] ~= 0 then
      if speed > (ZYD.LastWind["Speed"]+ZYD.LastWind["SpeedDetectionThreeshold"]) then
        if dest > (ZYD.WindAverage["Destination"]*3) or temp > (ZYD.WindAverage["Temperature"]*3) then
          local year,month,day,hour,minute = date:sub(1,4),date:sub(6,7),date:sub(9,10),date:sub(12,13),date:sub(15,16)
          local video = "https://sdo.gsfc.nasa.gov/assets/img/dailymov/"..year.."/"..month.."/"..day.."/"..year..month..day.."_1024_1700.mp4"
          local tempTab = {}
          tempTab["Date"] = date
          tempTab["Dest"] = dest
          tempTab["Speed"] = speed
          tempTab["Temperature"] = temp
          jsonG = io.open("data.json", "a+")
          local jsonE = json.encode(tempTab)
          jsonG:write(jsonE..",")
          io.close(jsonG)
          
        end
      end
    end
    ZYD.LastWind["Destination"] = dest
    ZYD.LastWind["Speed"] = speed
    ZYD.LastWind["Temperature"] = temp
  end
  end
end