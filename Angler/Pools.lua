local _, ns = ...

-- Pools are server spawns, absent from the client data, so they are recognised by the name in the mouseover
-- tooltip. Keys are tooltip names in any client language; values are the English name used as a shared key.
ns.POOL_NAMES = {
    ["Firefin Snapper School"] = "Firefin Snapper School",
    ["Floating Debris"] = "Floating Debris",
    ["Floating Wreckage"] = "Floating Wreckage",
    ["Greater Sagefish School"] = "Greater Sagefish School",
    ["Muddy Churning Waters"] = "Muddy Churning Waters",
    ["Oily Blackmouth School"] = "Oily Blackmouth School",
    ["Sagefish School"] = "Sagefish School",
    ["School of Deviate Fish"] = "School of Deviate Fish",
    ["School of Fish"] = "School of Fish",
    ["School of Tastyfish"] = "School of Tastyfish",
    ["School of Whimsyfin"] = "School of Whimsyfin",
    ["Stonescale Eel Swarm"] = "Stonescale Eel Swarm",

    ["Aguas Fangosas"] = "Muddy Churning Waters",
    ["Banco de aletantojos"] = "School of Whimsyfin",
    ["Banco de anguilas Escama Tormentosa"] = "Stonescale Eel Swarm",
    ["banco de bocanegra graso"] = "Oily Blackmouth School",
    ["Banco de pargos de fuego"] = "Firefin Snapper School",
    ["banco de peces"] = "School of Fish",
    ["Banco de peces descarriados"] = "School of Deviate Fish",
    ["banco de pezrico"] = "School of Tastyfish",
    ["Banco de sabiolas"] = "Sagefish School",
    ["banco superior de sabiolas"] = "Greater Sagefish School",
    ["Restos de un naufragio"] = "Floating Wreckage",
    ["Restos flotando"] = "Floating Debris",
}

-- Localized pool names not mapped yet are still recorded under their own name when they match one of these.
-- Patterns are matched against the lowercased tooltip name.
ns.POOL_NAME_PATTERNS = {
    "^banco ",
    "^aguas ",
    "^restos ",
}

-- Wowhead lists some names in lowercase, and the tooltip capitalisation may differ, so lookups ignore case.
local namesByLower = {}
for name, key in pairs(ns.POOL_NAMES) do
    namesByLower[name:lower()] = key
end

function ns.PoolKey(tooltipName)
    local key = ns.POOL_NAMES[tooltipName]
    if key then return key end
    local lower = tooltipName:lower()
    key = namesByLower[lower]
    if key then return key end
    for _, pattern in ipairs(ns.POOL_NAME_PATTERNS) do
        if lower:find(pattern) then return tooltipName end
    end
end

-- Display names per addon language, keyed by the English name. Missing entries fall back to the name the client
-- showed when its language is the addon language, and otherwise to English.
ns.POOL_LABELS = {
    esES = {
        ["Firefin Snapper School"] = "Banco de pargos de fuego",
        ["Floating Debris"] = "Restos flotando",
        ["Floating Wreckage"] = "Restos de un naufragio",
        ["Greater Sagefish School"] = "Banco superior de sabiolas",
        ["Muddy Churning Waters"] = "Aguas fangosas",
        ["Oily Blackmouth School"] = "Banco de bocanegra graso",
        ["Sagefish School"] = "Banco de sabiolas",
        ["School of Deviate Fish"] = "Banco de peces descarriados",
        ["School of Fish"] = "Banco de peces",
        ["School of Tastyfish"] = "Banco de pezrico",
        ["School of Whimsyfin"] = "Banco de aletantojos",
        ["Stonescale Eel Swarm"] = "Banco de anguilas Escama Tormentosa",
    },
}

function ns.PoolLabel(kind, seenName, language)
    local label = ns.POOL_LABELS[language] and ns.POOL_LABELS[language][kind]
    if label then return label end
    if seenName and language == GetLocale() then return seenName end
    if ns.POOL_NAMES[kind] == kind then return kind end
    return seenName or kind
end
