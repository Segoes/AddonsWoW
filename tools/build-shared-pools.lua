---@diagnostic disable: undefined-global
-- The workspace language server is set up for WoW addons, which have no io, os, dofile or loadfile; this is a plain Lua tool.
-- Builds AnglersCompanion/Data/SharedPools.lua from pool submissions.
--
-- Usage (from the repository root, Lua 5.1):
--   lua tools/build-shared-pools.lua [--csv <file or URL>] [--saved <SavedVariables/AnglersCompanion.lua>]... [--min-reports N]
--
-- Without --csv, the published form CSV URL is read from .pools-csv-url, which stays out of the repository.
-- --saved adds the precise pools of a player's own SavedVariables file.
-- The output is a pure function of the inputs: deleting a row from the form sheet drops its pools on the next build.

local ROOT = (arg[0]:match("^(.*)/tools/[^/]+$") or ".")
local ADDON = ROOT .. "/AnglersCompanion"
local OUTPUT = ADDON .. "/Data/SharedPools.lua"

local PREFIX = "ANGLER1:"
local FORMAT_VERSION = 1
local POSITION_SCALE = 10000
-- Zone maps are a few thousand yards across, so 30 units of 1/10000 is roughly 10 yards.
local MERGE_DISTANCE = 30
local TEXT_COLUMN = "Angler text"

local LibSerialize = dofile(ADDON .. "/Libs/LibSerialize/LibSerialize.lua")
local LibDeflate = dofile(ADDON .. "/Libs/LibDeflate/LibDeflate.lua")

local function Fail(message)
    io.stderr:write("error: " .. message .. "\n")
    os.exit(1)
end

local function ReadFile(path)
    local file = io.open(path, "rb")
    if not file then return end
    local data = file:read("*a")
    file:close()
    return data
end

local function Fetch(url)
    local pipe = io.popen("curl -sfL " .. ("%q"):format(url))
    local data = pipe:read("*a")
    local ok = pipe:close()
    if not ok or data == "" then return end
    return data
end

local function ParseArgs()
    local options = { saved = {}, minReports = 1 }
    local i = 1
    while i <= #arg do
        local name, value = arg[i], arg[i + 1]
        if name == "--csv" and value then
            options.csv = value
        elseif name == "--saved" and value then
            options.saved[#options.saved + 1] = value
        elseif name == "--min-reports" and tonumber(value) then
            options.minReports = tonumber(value)
        else
            Fail("unknown or incomplete option: " .. tostring(name))
        end
        i = i + 2
    end
    return options
end

-- Google quotes fields that hold commas, quotes or line breaks, and doubles the quotes inside them.
local function ParseCSV(text)
    local rows, row, field = {}, {}, {}
    local i, n, quoted = 1, #text, false
    while i <= n do
        local c = text:sub(i, i)
        if quoted then
            if c == '"' then
                if text:sub(i + 1, i + 1) == '"' then
                    field[#field + 1] = '"'
                    i = i + 1
                else
                    quoted = false
                end
            else
                field[#field + 1] = c
            end
        elseif c == '"' then
            quoted = true
        elseif c == "," then
            row[#row + 1] = table.concat(field)
            field = {}
        elseif c == "\n" or c == "\r" then
            if c == "\r" and text:sub(i + 1, i + 1) == "\n" then i = i + 1 end
            row[#row + 1] = table.concat(field)
            rows[#rows + 1] = row
            row, field = {}, {}
        else
            field[#field + 1] = c
        end
        i = i + 1
    end
    if #field > 0 or #row > 0 then
        row[#row + 1] = table.concat(field)
        rows[#rows + 1] = row
    end
    return rows
end

local function KnownKinds()
    local ns = {}
    _G.GetLocale = function() return "enUS" end
    assert(loadfile(ADDON .. "/Pools.lua"))(nil, ns)
    local kinds = {}
    for _, kind in pairs(ns.POOL_NAMES) do kinds[kind] = true end
    return kinds
end

local KINDS = KnownKinds()

local reports = {}
local problems = {}

local function Problem(source, message)
    problems[#problems + 1] = ("%s: %s"):format(source, message)
end

local function ValidPosition(value)
    return type(value) == "number" and value >= 0 and value <= POSITION_SCALE
end

local function AddReport(source, mapID, kind, x, y)
    if type(mapID) ~= "number" or mapID ~= math.floor(mapID) or mapID <= 0 then
        Problem(source, "invalid map " .. tostring(mapID))
    elseif not KINDS[kind] then
        Problem(source, "unknown pool type " .. tostring(kind))
    elseif not ValidPosition(x) or not ValidPosition(y) then
        Problem(source, "position out of range")
    else
        reports[#reports + 1] = { source = source, mapID = mapID, kind = kind, x = x, y = y }
        return true
    end
end

local function DecodeExport(text)
    text = text:gsub("%s", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, "does not start with " .. PREFIX end
    local compressed = LibDeflate:DecodeForPrint(text:sub(#PREFIX + 1))
    local serialized = compressed and LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil, "damaged text (incomplete copy?)" end
    local ok, payload = LibSerialize:Deserialize(serialized)
    if not ok or type(payload) ~= "table" or type(payload.pools) ~= "table" then
        return nil, "damaged text"
    end
    if payload.v ~= FORMAT_VERSION then return nil, "unsupported format version " .. tostring(payload.v) end
    return payload.pools
end

local function ReadSubmissions(location)
    local text = location:match("^https?://") and Fetch(location) or ReadFile(location)
    if not text then Fail("could not read the CSV from " .. location) end
    local rows = ParseCSV(text)
    local header = rows[1] or {}
    local column
    for i, name in ipairs(header) do
        if name == TEXT_COLUMN then column = i end
    end
    if not column then Fail(("the CSV has no %q column"):format(TEXT_COLUMN)) end
    local submissions = 0
    for i = 2, #rows do
        local source = ("form row %d"):format(i)
        local text = rows[i][column]
        if text and text:match("%S") then
            submissions = submissions + 1
            local maps, err = DecodeExport(text)
            if not maps then
                Problem(source, err)
            else
                local added = 0
                for mapID, list in pairs(maps) do
                    if type(list) == "table" then
                        for _, entry in ipairs(list) do
                            if type(entry) == "table" and entry[4] == 1
                                    and AddReport(source, mapID, entry[1], entry[2], entry[3]) then
                                added = added + 1
                            end
                        end
                    end
                end
                print(("  %s: %d pools"):format(source, added))
            end
        end
    end
    return submissions
end

local function ReadSaved(path)
    local chunk = loadfile(path)
    if not chunk then Fail("could not read " .. path) end
    local env = {}
    setfenv(chunk, env)
    chunk()
    local pools = env.AnglersCompanionDB and env.AnglersCompanionDB.pools
    if type(pools) ~= "table" then Fail(path .. " has no recorded pools") end
    local added = 0
    for mapID, spots in pairs(pools) do
        for _, spot in ipairs(spots) do
            if spot.precise and type(spot.x) == "number" and type(spot.y) == "number"
                    and AddReport(path, mapID, spot.kind,
                        math.floor(spot.x * POSITION_SCALE + 0.5), math.floor(spot.y * POSITION_SCALE + 0.5)) then
                added = added + 1
            end
        end
    end
    print(("  %s: %d precise pools"):format(path, added))
end

-- Reports of the same pool land a few yards apart; each cluster becomes one pool at the average position.
local function Merge()
    local clusters = {}
    for _, report in ipairs(reports) do
        local found
        for _, cluster in ipairs(clusters) do
            if cluster.mapID == report.mapID and cluster.kind == report.kind then
                local dx, dy = cluster.x - report.x, cluster.y - report.y
                if dx * dx + dy * dy <= MERGE_DISTANCE * MERGE_DISTANCE then
                    found = cluster
                    break
                end
            end
        end
        if found then
            local n = found.count
            found.x = (found.x * n + report.x) / (n + 1)
            found.y = (found.y * n + report.y) / (n + 1)
            found.count = n + 1
        else
            clusters[#clusters + 1] = { mapID = report.mapID, kind = report.kind, x = report.x, y = report.y, count = 1 }
        end
    end
    return clusters
end

local function Write(clusters, minReports)
    local byMap, mapIDs = {}, {}
    local kept = 0
    for _, cluster in ipairs(clusters) do
        if cluster.count >= minReports then
            if not byMap[cluster.mapID] then
                byMap[cluster.mapID] = {}
                mapIDs[#mapIDs + 1] = cluster.mapID
            end
            local list = byMap[cluster.mapID]
            list[#list + 1] = cluster
            kept = kept + 1
        end
    end
    table.sort(mapIDs)
    local out = {
        "local _, ns = ...",
        "",
        "-- Generated by tools/build-shared-pools.lua from player submissions. Rebuild it instead of editing by hand.",
        "-- Each pool is { English type, x, y } with positions in 1/10000 of the zone map.",
        "ns.SHARED_POOLS = {",
    }
    for _, mapID in ipairs(mapIDs) do
        local list = byMap[mapID]
        table.sort(list, function(a, b)
            if a.kind ~= b.kind then return a.kind < b.kind end
            if a.x ~= b.x then return a.x < b.x end
            return a.y < b.y
        end)
        out[#out + 1] = ("    [%d] = {"):format(mapID)
        for _, cluster in ipairs(list) do
            out[#out + 1] = ("        { %q, %d, %d },"):format(cluster.kind,
                math.floor(cluster.x + 0.5), math.floor(cluster.y + 0.5))
        end
        out[#out + 1] = "    },"
    end
    out[#out + 1] = "}"
    local file = assert(io.open(OUTPUT, "wb"))
    file:write(table.concat(out, "\n"), "\n")
    file:close()
    return kept, #mapIDs
end

local options = ParseArgs()
local csv = options.csv
if not csv then
    local saved = ReadFile(ROOT .. "/.pools-csv-url")
    csv = saved and saved:match("%S+")
    if not csv then Fail("no --csv given and no .pools-csv-url file") end
end

print("Reading submissions:")
local submissions = ReadSubmissions(csv)
for _, path in ipairs(options.saved) do ReadSaved(path) end

local clusters = Merge()
local kept, maps = Write(clusters, options.minReports)

print(("\n%d form submissions, %d pool reports, %d distinct pools."):format(submissions, #reports, #clusters))
if options.minReports > 1 then
    print(("%d pools reported at least %d times."):format(kept, options.minReports))
end
print(("Wrote %d pools on %d maps to %s"):format(kept, maps, OUTPUT))
if #problems > 0 then
    print(("\n%d problems:"):format(#problems))
    for _, problem in ipairs(problems) do print("  " .. problem) end
end
