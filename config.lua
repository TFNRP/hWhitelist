Config = {
  Convars = {
    --[[
      The identifier you would prefer to be used in add_principal.
      Can be one of the following:
      - steam (preferred)
      - license
      - license2
      - discord
      - xbl
      - live
      - fivem
      - ip
    --]]
    PreferredIdentifier = 'steam',
    Discord = {
      -- The id of the server to check roles from
      GuildId = '463778631551025187',
      -- The token of the bot account to use
      Token = 'MTk4NjIyNDgzNDcxOTI1MjQ4.Cl2FMQ.ZnCjm1XVW7vRze4b7Cq4se7kKWs',
    },
  },

  Groups = {
    {
      name = 'staff',
      -- The display name for this group. Can be used by external resources for displaying in chat, etc
      displayName = 'staff',
      -- Base allowed ACEs for the 'staff' group, gets added on to their role's allowed
      allowed = {
        'hwhitelist.whitelist.add',
        'hwhitelist.whitelist.remove',
        -- You can also add external ACEs, EasyAdmin for example:
        'easyadmin.player.kick',
        'easyadmin.player.spectate',
        'easyadmin.player.teleport.single',
      },
      -- Base denied ACEs for the 'staff' group, gets added on to their role's denied
      denied = {
        'hwhitelist.whitelist.group.staff',
      },
    },

    {
      name = 'member'
      -- You can add base config for all member roles here
    },
  },


  Hierarchy = {
    {
      name = 'owner',
      displayName = 'Owner',
      group = 'staff',
      allowed = {
        'hwhitelist.whitelist.add.all',
        'hwhitelist.whitelist.remove.all',
        'hwhitelist.whitelist.manage',
        'hwhitelist.commands.refresh',
      },
    },

    {
      name = 'admin',
      displayName = 'Administrator',
      group = 'staff',
      allowed = {
        'hwhitelist.whitelist.manage',
        'hwhitelist.commands.refresh',
      },
    },

    {
      name = 'moderator',
      displayName = 'Moderator',
      group = 'staff',
    },

    -- Supply access to donor vehicles/peds/weapons if you use a resource like DynamicBlacklist
     {
      name = 'donator2',
      displayName = 'VIP+',
      group = 'member',
      allowed = {
        'dblacklist.donator2',
      },
    },

    {
      name = 'donator',
      role = '891105525381599284',
      displayName = 'VIP',
      group = 'member',
      allowed = {
        'dblacklist.donator',
      },
    },

    -- The base permissions *everyone* has
    -- This cannot be removed nor added as a whitelist
    {
      name = 'everyone',
      displayName = 'Member',
      group = 'member',
      allowed = {
        'hwhitelist.commands.info', -- Allows everyone to use the info command (/hwl info)
        'hwhitelist.commands.me', -- Allows everyone to see what they're whitelisted for (/hwl me)
      },
    },
  },
}

--[[

  Terminology
    In this documentation,
    - the words 'role' and 'whitelist' are used interchangeably with the same meaning,
    - the words 'table' and 'object' are used interchangeably with the same meaning,
    - an 'array' is a table without any keys or a table with only numeric keys,
    - a role is a whitelist which can be given and removed,
    - a group is a whitelist which cannot be given nor removed directly, and relies o,
    the roles the user has and
    - a user can have multiple groups, the same goes for roles.

  Hierarchy Information
    Users do not count to be a part of a role unless they explicitly have the role.
    Meaning, a user with the 'admin' role *does not* inherit any roles below them (i.e. moderator) and
    therefore you should add anything you've added to moderator to admin.

    Due to Lua using alphanumerical order for tables, Config.Hierarchy must be Array<table>.
    JSON, however, keeps the order of objects. Using JSON, Config.Hierarchy can be Array<object> *or*
    Object<string, object>.

  Allowed/Denied ACEs in roles
    The denied ACEs are applied *after* the allowed ACEs, prioritising them.
    ACEs for all whitelists are applied sequentially, with the lowest role
    being applied first and the highest role applied last.

  Whitelist
    hwhitelist.whitelist.add                -- Inherits 'hwhitelist.commands.add', allows the ability to add all roles below their highest role
    hwhitelist.whitelist.add.all            -- Allows the ability to add all roles regardless of hierarchy
    hwhitelist.whitelist.add.group.staff    -- Allows the ability to add any role of the 'staff' group regardless if it's higher then their highest role
    hwhitelist.whitelist.add.role.vip       -- Allows the ability to add the 'vip' role regardless if it's higher then their highest role
    hwhitelist.whitelist.remove             -- Inherits 'hwhitelist.commands.remove', allows the ability to remove all roles below their highest role
    hwhitelist.whitelist.remove.all         -- Allows the ability to remove all roles regardless of hierarchy
    hwhitelist.whitelist.remove.group.staff -- Allows the ability to remove any role of the 'staff' group regardless if it's higher then their highest role
    hwhitelist.whitelist.remove.role.vip    -- Allows the ability to remove the 'vip' role regardless if it's higher then their highest role

  Commands
    hwhitelist.commands.add     -- Command can be used, but cannot add any without an allowed 'hwhitelist.whitelist.add'
    hwhitelist.commands.remove  -- Command can be used, but cannot remove any without an allowed 'hwhitelist.whitelist.remove'
    hwhitelist.commands.info    -- Command can be used
    hwhitelist.commands.me      -- Command can be used
    hwhitelist.commands.refresh -- Command can be used

--]]