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

function DiscordFetchMember(userId)
  local response = {}
  PerformHttpRequest(
    Constants.Discord.Base .. Config.Convars.Discord.Version .. '/guilds/' .. Config.Convars.Discord.GuildId .. '/members/' .. userId,
    function (code, result, headers)
      response.code = code
      response.json = result
    end,
    'GET',
    {
      ['Content-Type'] = 'application/json',
      ['Authorization'] = Config.Convars.Discord.Token,
      ['User-Agent'] = Config.Convars.Discord.UserAgent,
    }
  )

  while response.code == nil do Citizen.Wait(0) end
  if response.code ~= 200 then return false, response end
  response.json = json.decode(response.json)
  return true, response
end

function GetDiscordRoleWhitelists()
  local roles = {}

  for _, role in pairs(Config.Hierarchy) do
    if role.role then
      if type(role.role) == 'table' then
        for _, r in ipairs(role.role) do
          roles[r] = role.name
        end
      else
        roles[role.role] = role.name
      end
    end
  end

  return roles
end

function LoadConfig()
  Config = nil
  local jsonChunk = LoadResourceFile(GetCurrentResourceName(), 'config.json')
  if jsonChunk and jsonChunk ~= '' then
    Config = json.decode(jsonChunk)
  end
  if not Config or Config.Convars and not Config.Convars.UseJSON then
    assert(load(LoadResourceFile(GetCurrentResourceName(), 'config.lua')))()
  end
end

function IsInArray(arr, item)
  for _, value in ipairs(arr) do
    if value == item then return true end
  end
  return false
end

function ArrayToString(arr, sep)
  local str = ''
  if not sep then sep = ', ' end
  for index, name in ipairs(arr) do
    if index == #arr then
      str = str .. name
    else
      str = str .. name .. sep
    end
  end
  return str
end

function ParsePlayerIdentifiers (source)
  local array = GetPlayerIdentifiers(source)
  local ret = {}
  for _, value in ipairs(array) do
    for _, identifier in ipairs(Constants.Identifiers) do
      if value:sub(1, identifier:len()) == identifier then
        ret[identifier] = value:sub(identifier:len() + 1, value:len())
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
  ExecuteCommand('add_principal identifier.' .. Config.Convars.PreferredIdentifier .. ':' .. identifier .. ' ' .. whitelist)
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

function AddRolePrincipal (role, ace, allow)
  if allow == false then
    allow = 'deny'
  else
    allow = 'allow'
  end
  ExecuteCommand('add_principal ' .. ace .. ' hwhitelist.role.' .. role)
end

function RemoveRoleAce (role, ace, allow)
  if allow == false then
    allow = 'deny'
  else
    allow = 'allow'
  end
  ExecuteCommand('remove_ace hwhitelist.role.' .. role .. ' "' .. ace .. '" ' .. allow)
end

function RemoveRolePrincipal (role, ace, allow)
  if allow == false then
    allow = 'deny'
  else
    allow = 'allow'
  end
  ExecuteCommand('remove_principal ' .. ace .. ' hwhitelist.role.' .. role)
end

function RemovePlayerWhitelist (player, whitelist)
  local identifier = ParsePlayerIdentifiers(player)[Config.Convars.PreferredIdentifier]
  if identifier == nil then
    return false
  end
  ExecuteCommand('remove_principal identifier.' .. Config.Convars.PreferredIdentifier .. ':' .. identifier .. ' ' .. whitelist)
  return true
end

function IterateGroups (iterator)
  for key, Group in pairs(Config.Groups) do
    if type(key) == 'string' and type(Group) == 'table' then
      Config.Group[key].name = key
    end
    iterator(Group, key)
  end
end

function IterateRoles (iterator)
  for key, Role in pairs(Config.Hierarchy) do
    if type(key) == 'string' and type(Role) == 'table' then
      Config.Hierarchy[key].name = key
    end
    iterator(Role, key)
  end
end

function ValidateConfig()
  if type(Config) ~= 'table' then
    error('Config must be type of table, got \'' .. type(Config) .. '\'')
  end
  Config.Convars = ValidateConvars(Config.Convars)
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

  local groups = {}
  IterateGroups(function (Group)
    local group = ValidateGroup(Group)
    if groups[Group.name] then
      error('Group \'' .. Group.name .. '\' already exists')
    end
    groups[group.name] = group
  end)
  Config.Groups = groups

  local roles = {}
  IterateRoles(function (Role)
    local role = ValidateRole(Role)
    if roles[Role.name] then
      error('Role \'' .. Role.name .. '\' already exists')
    end
    roles[Role.name] = role
  end)
  Config.Hierarchy = roles

  if not roles.everyone then
    Config.Hierarchy.everyone = {
      name = 'everyone'
    }
  end
end

function ExecuteConfig(SetRoleAce, SetRoleAceOwner)
  if not SetRoleAce then SetRoleAce = AddRoleAce end
  if not SetRoleAceOwner then SetRoleAceOwner = AddRolePrincipal end
  IterateRoles(function (Role)
    if Role.group then
      local Group = Config.Groups[Role.group]
      if Group.allowed then
        for _, ace in ipairs(Group.allowed) do
          SetRoleAce(Role.name, ace)
        end
      end
      if Group.denied then
        for _, ace in ipairs(Group.denied) do
          SetRoleAce(Role.name, ace, false)
        end
      end
    end

    if Role.allowed then
      for _, ace in ipairs(Role.allowed) do
        SetRoleAce(Role.name, ace)
      end
    end
    if Role.denied then
      for _, ace in ipairs(Role.denied) do
        SetRoleAce(Role.name, ace, false)
      end
    end

    if Role.allowedPrincipal then
      for _, ace in ipairs(Role.allowedPrincipal) do
        SetRoleAceOwner(Role.name, ace)
      end
    end
    if Role.deniedPrincipal then
      for _, ace in ipairs(Role.deniedPrincipal) do
        SetRoleAceOwner(Role.name, ace, false)
      end
    end
  end)
end

function ValidateConvars (Convars)
  if type(Convars) ~= 'table' then
    error('Convars must be type of table, got \'' .. type(Convars) .. '\'')
  end

  if Convars.Discord then
    if type(Convars.Discord) ~= 'table' then
      error('Convars.Discord must be type of table or nil, got \'' .. type(Convars.Discord) .. '\'')
    end
    if type(Convars.Discord.Token) ~= 'string' then
      error('Convars.Discord.Token must be type of string, got \'' .. type(Convars.Discord.Token) .. '\'')
    end
    if not Convars.Discord.Token:match('%w+%.%w+%.%w+$') then
      error('Invalid Discord bot token')
    end
    if string.sub(Convars.Discord.Token, 1, string.len('Bot ')) ~= 'Bot ' then
      Convars.Discord.Token = 'Bot ' .. Convars.Discord.Token
    end
    if type(Convars.Discord.GuildId) ~= 'string' then
      error('Convars.Discord.GuildId must be type of string, got \'' .. type(Convars.Discord.GuildId) .. '\'')
    end
    if Convars.Discord.UserAgent then
      if type(Convars.Discord.UserAgent) ~= 'string' then
        error('Convars.Discord.UserAgent must be type of string or nil, got \'' .. type(Convars.Discord.UserAgent) .. '\'')
      end
    else
      Convars.Discord.UserAgent = 'hWhitelist ' .. (GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'v0.0.0')
    end
    if Convars.Discord.Version then
      if type(Convars.Discord.Version) ~= 'string' then
        error('Convars.Discord.Version must be type of string or nil, got \'' .. type(Convars.Discord.Version) .. '\'')
      elseif not Convars.Discord.Version:match('^v%d+$') then
        error('Invalid Discord API version, got \'' .. Convars.Discord.Version .. '\'')
      end
    else
      Convars.Discord.Version = Constants.Discord.Version
    end
  end

  return Convars
end

function ValidateGroup (Group)
  if type(Group) ~= 'table' then
    error('Group must be type of table, got \'' .. type(Group) .. '\'')
  end
  if type(Group.name) ~= 'string' then
    error('<Group>.name must be type of string, got \'' .. type(Group.name) .. '\'')
  end
  if Group.displayName then Group.display = Group.displayName end
  if Group.display and type(Group.display) ~= 'string' then
    error('<Group>.display must be type of string or nil, got \'' .. type(Group.display) .. '\'')
  end
  if Group.allowed and not type(Group.allowed) == 'table' then
    if type(Group.allowed) == 'string' then
      Group.allowed = { Group.allowed }
    else
      error('<Group>.allowed must be type of string, table or nil, got \'' .. type(Group.allowed) .. '\'')
    end
  end
  if Group.denied and not type(Group.denied) == 'table' then
    if type(Group.denied) == 'string' then
      Group.denied = { Group.denied }
    else
      error('<Group>.denied must be type of string, table or nil, got \'' .. type(Group.denied) .. '\'')
    end
  end

  return Group
end

function ValidateRole (Role)
  if type(Role) ~= 'table' then
    error('Role must be type of table, got \'' .. type(Role) .. '\'')
  end
  if type(Role.name) ~= 'string' then
    error('<Role>.name must be type of string, got \'' .. type(Role.name) .. '\'')
  end
  if Role.displayName then Role.display = Role.displayName end
  if Role.display and type(Role.display) ~= 'string' then
    error('<Role>.display must be type of string or nil, got \'' .. type(Role.display) .. '\'')
  end
  if Role.group then
    if type(Role.group) ~= 'string' then
      error('<Role>.group must be type of string or nil, got \'' .. type(Role.group) .. '\'')
    end
    if not Config.Groups[Role.group] then
      error('Group \'' .. Role.group .. '\' does not exist for role \'' .. Role.name .. '\'')
    end
  end
  if Role.allowed and not type(Role.allowed) == 'table' then
    if type(Role.allowed) == 'string' then
      Role.allowed = { Role.allowed }
    else
      error('<Role>.allowed must be type of string, table or nil, got \'' .. type(Role.allowed) .. '\'')
    end
  end
  if Role.denied and not type(Role.denied) == 'table' then
    if type(Role.denied) == 'string' then
      Role.denied = { Role.denied }
    else
      error('<Role>.denied must be type of string, table or nil, got \'' .. type(Role.denied) .. '\'')
    end
  end
  if Role.allowedPrincipal and not type(Role.allowedPrincipal) == 'table' then
    if type(Role.allowedPrincipal) == 'string' then
      Role.allowedPrincipal = { Role.allowedPrincipal }
    else
      error('<Role>.allowedPrincipal must be type of string, table or nil, got \'' .. type(Role.allowedPrincipal) .. '\'')
    end
  end
  if Role.deniedPrincipal and not type(Role.deniedPrincipal) == 'table' then
    if type(Role.deniedPrincipal) == 'string' then
      Role.deniedPrincipal = { Role.deniedPrincipal }
    else
      error('<Role>.deniedPrincipal must be type of string, table or nil, got \'' .. type(Role.deniedPrincipal) .. '\'')
    end
  end
  if Role.name == 'everyone' then
    if not Role.allowedPrincipal then
      Role.allowedPrincipal = { 'builtin.everyone' }
    end
  end

  return Role
end