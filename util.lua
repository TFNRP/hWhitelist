RegisterFrameworkCommand = exports.framework.RegisterFrameworkCommand
if RegisterFrameworkCommand == nil then
  -- polyfill
  RegisterFrameworkCommand = function (name, handler, restricted)
    if type(name) == 'table' then
      for _, c in ipairs(name) do
        RegisterFrameworkCommand(c, handler, restricted)
      end
    else
      RegisterCommand(name, handler, restricted)
    end
  end
end

Constants = {
  Identifiers = {
    'steam', 'license', 'license2', 'discord',
    'xbl', 'live', 'fivem', 'ip',
  },
}

function LoadConfig()
  Config = nil
  local jsonChunk = LoadResourceFile(GetCurrentResourceName(), 'config.json')
  if jsonChunk and jsonChunk ~= '' then
    Config = json.decode(jsonChunk)
  end
  if not Config and not Config.Convars and not Config.Convars.UseJSON then
    assert(load(LoadResourceFile(GetCurrentResourceName(), 'config.lua')))()
  end
end

function IsInArray(arr, item)
  for value in ipairs(arr) do
    if value == item then return true end
  end
  return false
end

function ArrayToString(arr, sep)
  local str = ''
  if not sep then sep = ', ' end
  for name, index in ipairs(arr) do
    if index == #arr then
      str = str .. name
    else
      str = str .. name .. sep
    end
  end
end

function ParsePlayerIdentifiers (source)
  local array = GetPlayerIdentifiers(source)
  local ret = {}
  for value in ipairs(array) do
    for identifier in ipairs(Constants.Identifiers) do
      if string.sub(value, 1, string.len(identifier)) == identifier then
        ret[identifier] = value
        break
      end
    end
  end
  return ret
end

function GetPlayerWhitelists (source)
  local whitelists = {}
  for name in pairs(Config.Hierarchy) do
    if IsPlayerAceAllowed(source, 'hwhitelist.whitelist.role.' .. name) then
      table.insert(whitelists, name)
    end
  end
  return whitelists
end

function AddPlayerWhitelist (player, whitelist)
  local identifier = ParsePlayerIdentifiers(player)[Config.Convars.PreferredIdentifier]
  if identifier == nil then
    return false
  end
  ExecuteCommand('add_principal identifier:' .. identifier .. ' ' .. whitelist)
  return true
end

function AddRoleAce (role, ace, allow)
  if allow == false then
    allow = 'deny'
  else
    allow = 'allow'
  end
  ExecuteCommand('add_ace hwhitelist.role.' .. role .. ' "' .. ace .. '" ' .. allow)
end

function RemoveRoleAce (role, ace, allow)
  if allow == false then
    allow = 'deny'
  else
    allow = 'allow'
  end
  ExecuteCommand('remove_ace hwhitelist.role.' .. role .. ' "' .. ace .. '" ' .. allow)
end

function RemovePlayerWhitelist (player, whitelist)
  local identifier = ParsePlayerIdentifiers(player)[Config.Convars.PreferredIdentifier]
  if identifier == nil then
    return false
  end
  ExecuteCommand('remove_principal identifier:' .. identifier .. ' ' .. whitelist)
  return true
end

function IterateGroups (iterator)
  for key, Group in pairs(Config.Groups) do
    if type(key) == 'string' and type(Group) == 'table' then
      Config.Group[key].name = key
    end
    iterator(Group)
  end
end

function IterateRoles (iterator)
  for key, Role in pairs(Config.Hierarchy) do
    if type(key) == 'string' and type(Role) == 'table' then
      Config.Hierarchy[key].name = key
    end
    iterator(Role)
  end
end

function ValidateConfig()
  if type(Config) ~= 'table' then
    error('Config must be type of table, got \'' .. type(Config) .. '\'')
  end
  if type(Config.Convars) ~= 'table' then
    error('Convars must be type of table, got \'' .. type(Config.Convars) .. '\'')
  end
  if type(Config.Groups) ~= 'table' then
    error('Groups must be type of table, got \'' .. type(Config.Groups) .. '\'')
  end
  if type(Config.Hierarchy) ~= 'table' then
    error('Hierarchy must be type of table, got \'' .. type(Config.Hierarchy) .. '\'')
  end

  if type(Config.Convars.PreferredIdentifier) ~= 'string' then
    error('PreferredIdentifier must be type of string, got \'' .. type(Config.Convars.PreferredIdentifier) .. '\'')
  end
  if not IsInArray(Constants.Identifiers, Config.Convars.PreferredIdentifier) then
    error('PreferredIdentifier must be one of \'' .. ArrayToString(Constants.Identifiers, '\', \'') .. '\', got \'' .. Config.Convars.PreferredIdentifier .. '\'')
  end

  local registeredGroups = {}
  IterateGroups(function (Group)
    ValidateGroup(Group)
    if registeredGroups[Group.name] then
      error('Group \'' .. Group.name .. '\' already exists')
    end
    registeredGroups[Group.name] = true
  end)

  local registeredRoles = {}
  IterateRoles(function (Role)
    ValidateRole(Role)
    if registeredRoles[Role.name] then
      error('Role \'' .. Role.name .. '\' already exists')
    end
    registeredRoles[Role.name] = true
  end)

  if not registeredRoles.everyone then
    table.insert(Config.Hierarchy, {
      name = 'everyone'
    })
  end
end

function ExecuteConfig(SetRoleAce)
  if not SetRoleAce then SetRoleAce = AddRoleAce end
  IterateRoles(function (Role)
    if Role.group then
      local Group = Config.Groups[Role.group]
      if Group.allowed then
        for ace in ipairs(Group.allowed) do
          SetRoleAce(Role.name, ace)
        end
      end
      if Group.denied then
        for ace in ipairs(Group.denied) do
          SetRoleAce(Role.name, ace, false)
        end
      end
    end

    if Role.allowed then
      for ace in ipairs(Role.allowed) do
        SetRoleAce(Role.name, ace)
      end
    end
    if Role.denied then
      for ace in ipairs(Role.denied) do
        SetRoleAce(Role.name, ace, false)
      end
    end
  end)
end

function ValidateGroup (Group)
  if type(Group) ~= 'table' then
    error('Group must be type of table, got \'' .. type(Group) .. '\'')
  end
  if type(Group.name) ~= 'string' then
    error('<Group>.name must be type of string, got \'' .. type(Group.name) .. '\'')
  end
  if Group.displayName and type(Group.displayName) ~= 'string' then
    error('<Group>.displayName must be type of string or nil, got \'' .. type(Group.displayName) .. '\'')
  end
  if Group.allowed and not IsInArray({ 'string', 'table' }, type(Group.allowed)) then
    error('<Group>.allowed must be type of string, table or nil, got \'' .. type(Group.allowed) .. '\'')
  end
  if Group.denied and not IsInArray({ 'string', 'table' }, type(Group.denied)) then
    error('<Group>.denied must be type of string, table or nil, got \'' .. type(Group.denied) .. '\'')
  end
end

function ValidateRole (Role)
  if type(Role) ~= 'table' then
    error('Role must be type of table, got \'' .. type(Role) .. '\'')
  end
  if type(Role.name) ~= 'string' then
    error('<Role>.name must be type of string, got \'' .. type(Role.name) .. '\'')
  end
  if Role.displayName and type(Role.displayName) ~= 'string' then
    error('<Role>.displayName must be type of string or nil, got \'' .. type(Role.displayName) .. '\'')
  end
  if Role.group then
    if type(Role.group) ~= 'string' then
      error('<Role>.group must be type of string or nil, got \'' .. type(Role.group) .. '\'')
    end
    if not Config.Groups[Role.group] then
      error('Group \'' .. Role.group .. '\' does not exist for role \'' .. Role.name .. '\'')
    end
  end
  if Role.allowed and not IsInArray({ 'string', 'table' }, type(Role.allowed)) then
    error('<Role>.allowed must be type of string, table or nil, got \'' .. type(Role.allowed) .. '\'')
  end
  if Role.denied and not IsInArray({ 'string', 'table' }, type(Role.denied)) then
    error('<Role>.denied must be type of string, table or nil, got \'' .. type(Role.denied) .. '\'')
  end
end