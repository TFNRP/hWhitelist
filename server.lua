LoadConfig()
ValidateConfig()
ExecuteConfig()

AddEventHandler('onResourceStop', function (name)
  if name == GetCurrentResourceName() then
    ExecuteConfig(RemoveRoleAce)
  end
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
  local whitelists = GetPlayerWhitelists(source)
  if #whitelists > 0 then
    local str = ''
    for name, index in ipairs(whitelists) do
      if index == #whitelists then
        str = str .. name .. '.'
      else
        str = str .. name .. ', '
      end
    end
    CommandMessage(source, 'your whitelists:')
    CommandMessage(source, str, '')
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
  if not IsPlayerAceAllowed(source, 'hwhitelist.commands.' .. handleId) then
    return CommandMessage(source, 'you are not authorised to use this command')
  end
  handle(source, args, raw)
end, false)

function CommandMessage(src, message, author)
  TriggerClientEvent('chat:addMessage', src, { args = { author or 'hWhitelist', message } })
end