local function debugPrint(message)
    if Config.debug then
        print(message)
    end
end

local function isInArray(array, value)
    for _, v in ipairs(array) do
        debugPrint("Checking array value: " .. tostring(v) .. " against: " .. tostring(value))
        if v == value then
            return true
        end
    end
    return false
end

local function performVehicleLookup(plate, callback)
    local url = Config.cadURL .. plate
    
    PerformHttpRequest(url, function(err, text, headers)
        if err == 200 then
            local responseData = json.decode(text)
            if responseData then
                debugPrint("HTTP request successful: " .. text)
                if responseData.error then
                    debugPrint("API returned error: " .. responseData.error)
                    callback(false)
                else
                    callback(true, responseData)
                end
            else
                debugPrint("Failed to decode JSON response.")
                callback(false)
            end
        else
            debugPrint("HTTP error while performing request: " .. err .. "\nResponse body: " .. text)
            callback(false)
        end
    end, 'GET', nil, nil)    
end

RegisterNetEvent('wk:onPlateScanned')
AddEventHandler('wk:onPlateScanned', function(cam, plate, index, vehicle)
    local src = source
    debugPrint("Source captured: " .. tostring(src))
    if isInArray(Config.vehicleTypeFilter, tonumber(vehicle.class)) then
        debugPrint("Vehicle class " .. vehicle.class .. " is filtered; skipping...")
        return
    end

    local camCapitalized = (cam == 'front' and 'Front' or 'Rear')

    performVehicleLookup(plate, function(success, data)
        if success then
            handleVehicleData(src, cam, plate, data)
        else
            if Config.noRegistrationAlerts then
                notifyClient(src, camCapitalized, plate, "Ej Registrerad", "error")
            end
        end
    end)
end)

RegisterNetEvent('wk:onPlateLocked')
AddEventHandler('wk:onPlateLocked', function(cam, plate, index, vehicle)
    local src = source
    debugPrint("Source captured: " .. tostring(src))

    local camCapitalized = (cam == 'front' and 'Front' or 'Rear')
    performVehicleLookup(plate, function(success, data)
        if success then
            handleVehicleData(src, cam, plate, data)
        else
            if Config.noRegistrationAlerts then
                notifyClient(src, camCapitalized, plate, "Ej Registrerad", "error")
            end
        end
    end)
end)

function handleVehicleData(src, cam, plate, vehicleData)
    local camCapitalized = (cam == 'front' and 'Front' or 'Rear')
    
    -- Determine status based on vehicle data
    local status = "Registrerad"
    local type = "success"
    
    if vehicleData.efterlyst == 1 then
        status = "EFTERLYST"
        type = "warning"
    elseif vehicleData.in_traffic == 0 then
        status = "Avställd"
        type = "error"
    elseif vehicleData.insurance == 0 then
        status = "Oförsäkrad"
        type = "error"
    end
    
    local owner = vehicleData.owner or 'Okänd'
    local model = vehicleData.model or 'Okänd'
    local color = vehicleData.color or 'Okänd'
    
    notifyClient(src, camCapitalized, plate, status, type, model, owner, color)
    debugPrint("Notifying client: " .. tostring(src) .. ", " .. status)
end

function notifyClient(src, cam, plate, status, type, model, owner, color)
    local textColor = 'white'
    local backgroundColor = '#333'
    if type == "error" then
        backgroundColor = '#C53030'
        textColor = 'white'
    elseif type == "success" then
        backgroundColor = '#2F855A'
        textColor = 'white'
    elseif type == "warning" then
        backgroundColor = '#DD6B20' 
        textColor = 'black'
    end

    local message = string.format(
        "<div style='color: %s; background-color: %s; padding: 8px; border-radius: 5px;'>"
        .. "<strong>%s ALPR</strong><br/>"
        .. "Reg: <strong>%s</strong><br/>"
        .. "Status: <strong>%s</strong><br/>"
        .. "Modell: <strong>%s</strong><br/>"
        .. "Färg: <strong>%s</strong><br/>"
        .. "Ägare: <strong>%s</strong>"
        .. "</div>",
        textColor, backgroundColor, cam, plate:upper(), status, model, color, owner
    )

    TriggerClientEvent('pNotify:SendNotification', src, {
        text = message,
        type = type,
        queue = 'alpr',
        timeout = type == "success" and 30000 or 5000,
        layout = 'centerLeft'
    })
end
