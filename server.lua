LoadConfig()
ValidateConfig()
ExecuteConfig()

AddEventHandler('onResourceStop', function (name)
  if name == GetCurrentResourceName() then
    ExecuteConfig(RemoveRoleAce, RemoveRolePrincipal)
  end
end)

AddEventHandler('playerConnecting', function (name, setKickReason, deferrals)
  local src = source
  local identifiers = ParsePlayerIdentifiers(source)
  deferrals.defer()
  Wait(0)

  if Config.Convars.Discord and identifiers.discord then
    local success, data = DiscordFetchMember(identifiers.discord)
    local whitelists = nil
    if not success then
      if data.code ~= 404 then
        -- something went wrong
        local json = json.decode(data.json)
        if json and json.message then
          Citizen.Trace(json.message .. '\n')
        end
      end
      goto discord_end
    end

    whitelists = GetDiscordRoleWhitelists()
    for _, role in ipairs(data.json.roles) do
      if whitelists[role] then
        local success = AddPlayerWhitelist(src, 'hwhitelist.role.' .. whitelists[role])
        if not success then
          Citizen.Trace(
            'Could not add student Discord id ' .. identifiers.discord                ..
            ' to whitelist '                    .. whitelists[role]                   ..
            ' using preffered identifier '      .. Config.Convars.PreferredIdentifier ..
            '\n'
          )
        end
      end
    end

    ::discord_end::
  end

  AddPlayerWhitelist(src, 'hwhitelist.role.everyone')
  deferrals.done()
end)

AddEventHandler('playerDropped', function (reason)
  local src = source
  RemoveAllPlayerWhitelists(src)
end)

local commands = {}
local aliases = {
  a = 'add',
  r = 'remove',
  rem = 'remove',
  i = 'info',
}

function commands.add (source, args, raw)
  local serverId = args[2]
  local whitelist = args[3]
end

function commands.remove (source, args, raw)

end

function commands.refresh (source, args, raw)
  CommandMessage(source, 'refreshing...')
  ExecuteConfig(RemoveRoleAce)
  LoadConfig()
  ValidateConfig()
  ExecuteConfig()
  CommandMessage(source, 'done!')
end

function commands.me (source, args, raw)
  local whitelists = FilterArray(GetTableKeys(GetPlayerWhitelists(source)), function (value)
    if value:sub(1, 16) == 'hwhitelist.role.' then
      return true
    end
  end)
  if #whitelists > 0 then
    local str = ''
    for index, name in ipairs(whitelists) do
      name = name:sub(17)
      if index == #whitelists then
        str = str .. name .. '.'
      else
        str = str .. name .. ', '
      end
    end
    CommandMessage(source, 'your whitelists:')
    TriggerClientEvent('chat:addMessage', source, { args = { str } })
  else
    CommandMessage(source, 'you don\'t have any whitelists')
  end
end

function commands.info (source, args, raw)
  CommandMessage(source, GetResourceMetadata(GetCurrentResourceName(), 'author', 0), 'hWhitelist author')
  CommandMessage(source, GetResourceMetadata(GetCurrentResourceName(), 'version', 0), 'hWhitelist version')
  CommandMessage(source, GetResourceMetadata(GetCurrentResourceName(), 'repository', 0), 'hWhitelist source')
  CommandMessage(source, GetResourceMetadata(GetCurrentResourceName(), 'description', 0), 'hWhitelist about')
end

RegisterFrameworkCommand({ 'hwhitelist', 'hwl' }, function (source, args, raw)
  local handleId = args[1]
  if type(handleId) ~= 'string' or handleId == '' then
    -- return CommandMessage(source, 'a command must be supplied')
    handleId = 'me'
  end
  handleId = aliases[handleId] or handleId
  local handle = commands[handleId]
  if handle == nil then
    return CommandMessage(source, 'unknown command \'' .. handleId .. '\'')
  end
  if not IsPlayerAceAllowed(source, 'hwhitelist.command.' .. handleId) then
    return CommandMessage(source, 'you are not authorised to use this command')
  end
  handle(source, args, raw)
end, false)

function CommandMessage(src, message, author)
  TriggerClientEvent('chat:addMessage', src, { args = { author or 'hWhitelist', message } })
end