---@class TermManager
local M = {}

---@param sequence string
local function forward_to_host(sequence)
  local ok = pcall(vim.uv.fs_write, 2, sequence)
  if not ok then
    pcall(function()
      io.stderr:write(sequence)
      io.stderr:flush()
    end)
  end
end

---@param selectors string[]
local function setup_osc_forwarding(selectors)
  local allowed = vim.iter(selectors):fold({}, function(allowed, selector) allowed[tostring(selector)] = true end)
  local group = vim.api.nvim_create_augroup('TermOscForwarding', { clear = true })
  vim.api.nvim_create_autocmd('TermRequest', {
    group = group,
    desc = 'Forward allowed OSC requests from embedded terminals',
    callback = function(event)
      local sequence = event?.data?.sequence
      if sequence then
        local selector = type(sequence) == 'string' and sequence:match('^\27%](%d+)') or nil
        if selector and allowed[selector] then
          forward_to_host(sequence)
        end
      end
    end,
  })
end

--- Setup configuration
---@public
---@param opts? TermManagerConfig
function M.setup(opts)
  local ok, config = pcall(require, 'term.config')
  if not ok then
    vim.notify('term: failed to load config module: ' .. tostring(config), vim.log.levels.ERROR)
    return
  end

  config.config = vim.tbl_deep_extend('force', config.defaults, opts or {})

  if opts and opts.forward_osc then
    setup_osc_forwarding(opts.forward_osc)
  end

  ok = pcall(M.setup_user_commands)
  if not ok then
    vim.notify('term: failed to setup user commands', vim.log.levels.ERROR)
  end
end

---@public
function M.setup_user_commands()
  local ok, Core = pcall(require, 'term.core')
  if not ok then
    vim.notify('term: failed to load core module: ' .. tostring(Core), vim.log.levels.ERROR)
    return
  end

  -- Define User commands
  vim.api.nvim_create_user_command('TermToggle', function(args)
    local name = args.args ~= '' and args.args or nil
    Core.toggle(name)
  end, { nargs = '?', desc = 'Toggle terminal' })

  vim.api.nvim_create_user_command('ToggleTerminal', function(args)
    local name = args.args ~= '' and args.args or nil
    Core.toggle(name)
  end, { nargs = '?', desc = 'Toggle terminal' })

  vim.api.nvim_create_user_command('TermNew', function() Core.new() end, { desc = 'Create new terminal' })
  vim.api.nvim_create_user_command('TermNext', function() Core.next() end, { desc = 'Next terminal' })
  vim.api.nvim_create_user_command('TermPrev', function() Core.prev() end, { desc = 'Previous terminal' })
  vim.api.nvim_create_user_command('TermClose', function() Core.close() end, { desc = 'Close terminal' })

  vim.api.nvim_create_autocmd('VimResized', {
    pattern = '*',
    callback = function()
      local resize_ok, err = pcall(Core.resize)
      if not resize_ok then
        vim.notify('term: resize failed: ' .. tostring(err), vim.log.levels.ERROR)
      end
    end,
  })
end

return M
