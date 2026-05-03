local function create_input_validators()
  return {
    string = function(v)
      if type(v) ~= "string" then
        error("Expected string, got " .. type(v))
      end
      return v
    end,

    number = function(v)
      if type(v) ~= "number" then
        error("Expected number, got " .. type(v))
      end
      return v
    end,

    exact = function(expected_val)
      return function(v)
        if v ~= expected_val then
          error(string.format("Expected %s, got %s", tostring(expected_val), tostring(v)))
        end
        return v
      end
    end,

    boolean = function(v)
      if type(v) ~= "boolean" then
        error("Expected boolean, got " .. type(v))
      end
      return v
    end,

    scalar = function(v)
      if type(v) ~= "string" and type(v) ~= "number" then
        error("Expected scalar (string or number), got " .. type(v))
      end
      return v
    end,

    array = function(element_validator)
      return function(v)
        if type(v) ~= "table" then
          error("Expected array, got " .. type(v))
        end
        local result = {}
        for i, item in ipairs(v) do
          result[i] = element_validator(item)
        end
        return result
      end
    end,

    fields = function(schema)
      return function(v)
        if type(v) ~= "table" then
          error("Expected table with fields, got " .. type(v))
        end
        local result = {}
        for key, validator in pairs(schema) do
          local validated_value = validator(v[key])
          if validated_value ~= nil then
            result[key] = validated_value
          end
        end
        return result
      end
    end,

    required = function(validator)
      return function(v)
        if v == nil then
          error("Required field is missing")
        end
        return validator(v)
      end
    end,

    optional = function(validator)
      return function(v)
        if v == nil then
          return nil
        end
        return validator(v)
      end
    end,

    union = function(validators)
      return function(v)
        for _, validator in ipairs(validators) do
          local success, result = pcall(validator, v)
          if success then
            return result
          end
        end
        error("Value did not match any of the union types")
      end
    end,

    enum = function(values)
      local valid_set = {}
      local valid_list = table.concat(values, ", ")
      for _, val in ipairs(values) do
        valid_set[val] = true
      end

      return function(v)
        if not valid_set[v] then
          error(string.format("Invalid enum value: '%s'. Expected one of: %s", tostring(v), valid_list))
        end
        return v
      end
    end,
  }
end

local function create_output_formatters()
  return {
    raw = function(v)
      return tostring(v)
    end,
    bool_onoff = function(v)
      return v and "on" or "off"
    end,
    flag = function(flag_name)
      return function(v)
        return v and flag_name or nil
      end
    end,
    keyval = function(key)
      return function(v)
        return key .. "=" .. tostring(v)
      end
    end,
    bool_onoff_keyval = function(key)
      return function(v)
        return key .. "=" .. (v and "on" or "off")
      end
    end,
    field = function(field_name)
      return function(v)
        return v[field_name]
      end
    end,

    concat = function(separator, formatters)
      return function(v)
        local parts = {}
        for _, formatter in ipairs(formatters) do
          local result = formatter(v)
          if result ~= nil and result ~= "" then
            table.insert(parts, tostring(result))
          end
        end
        return table.concat(parts, separator)
      end
    end,

    space = function(v)
      if type(v) ~= "table" then
        error("Expected array for space formatter")
      end
      return table.concat(v, " ")
    end,

    chain = function(extractor, formatter)
      return function(v)
        local extracted = extractor(v)
        if extracted == nil then
          return nil
        end
        return formatter(extracted)
      end
    end,

    literal = function(str)
      return function(v)
        return str
      end
    end,
    typeof = function(type_name)
      return function(v)
        return type(v) == type_name
      end
    end,

    when = function(predicate, then_formatter, else_formatter)
      return function(v)
        if predicate(v) then
          return then_formatter(v)
        elseif else_formatter then
          return else_formatter(v)
        end
        return nil
      end
    end,

    has_fields = function(...)
      local field_names = { ... }
      return function(v)
        for _, field_name in ipairs(field_names) do
          if v[field_name] == nil then
            return false
          end
        end
        return true
      end
    end,

    keyval_pairs = function(pairs_config)
      return function(v)
        local parts = {}
        for _, pair in ipairs(pairs_config) do
          local result = pair.formatter(v)
          if result ~= nil and result ~= "" then
            table.insert(parts, pair.key .. "=" .. tostring(result))
          end
        end
        return table.concat(parts, " ")
      end
    end,
  }
end

local function build_directive_index(directives)
  local index = {}
  for _, directive in ipairs(directives) do
    if index[directive.name] then
      error("Duplicate directive definition: " .. directive.name)
    end
    index[directive.name] = directive
  end
  return index
end

-- Module-level initialization (Executed once to drastically improve perf)
local Input = create_input_validators()
local Output = create_output_formatters()
local core_defs = require("resty.nginx.confgen.definitions.common")(Input, Output)

local extra_modules = {
  "resty.nginx.confgen.definitions.lua_nginx",
}

for _, mod_path in ipairs(extra_modules) do
  local defs = require(mod_path)(Input, Output)
  for _, d in ipairs(defs) do 
    table.insert(core_defs, d) 
  end
end

local directive_index_cache = build_directive_index(core_defs)

local function is_array(t)
  if type(t) ~= "table" then
    return false
  end
  if next(t) == nil then
    return true
  end -- Empty tables behave as arrays here
  return t[1] ~= nil -- Explicit 1-indexed tables are arrays
end

local function validate_context(directive_name, directive_def, context)
  for _, valid_context in ipairs(directive_def.contexts) do
    if valid_context == context or valid_context == "" then
      return
    end
  end
  error(string.format("%s '%s' cannot be used in context '%s'. Valid contexts: %s", directive_def.type, directive_name, context, table.concat(directive_def.contexts, ", ")))
end

local function try_specs(directive_name, specs, value)
  local last_error = nil
  for _, spec in ipairs(specs) do
    local success, result = pcall(function()
      local validated = spec.input(value)
      return spec.output(validated)
    end)
    if success and result ~= nil then
      return result
    else
      last_error = result or "Output formatter returned nil"
    end
  end
  error(string.format("Directive '%s': none of the specs matched the input. Last error: %s", directive_name, tostring(last_error)))
end

local function extract_args_and_children(value, directive_def)
  if not directive_def.args or #directive_def.args == 0 then
    return "", value
  end

  local args_str
  local children = {}

  if directive_def.arg_fields then
    local args_data = {}
    local arg_field_set = {}

    -- Extract known argument fields metadata
    for _, f in ipairs(directive_def.arg_fields) do
      arg_field_set[f] = true
      args_data[f] = value[f]
    end

    -- Everything else becomes children configuration
    for k, v in pairs(value) do
      if not arg_field_set[k] then
        children[k] = v
      end
    end
    args_str = try_specs(directive_def.name .. " args", directive_def.args, args_data)
  else
    args_str = try_specs(directive_def.name .. " args", directive_def.args, value)
    children = value
  end

  return args_str, children
end

local function process_directive(directive_name, directive_def, value)
  if directive_def.type == "flag" then
    if type(value) ~= "boolean" then
      error(string.format("Directive '%s' expects a boolean value", directive_name))
    end
    return { type = "flag", name = directive_name, value = value }
  end

  if directive_def.type == "directive" then
    if not directive_def.spec then
      error(string.format("Directive '%s' has no spec defined", directive_name))
    end
    local formatted = try_specs(directive_name, directive_def.spec, value)
    return { type = "directive", name = directive_name, value = formatted, no_semi = directive_def.no_semi }
  end

  error(string.format("Unknown directive type '%s' for '%s'", tostring(directive_def.type), directive_name))
end

local function process_block(config, context, directive_index)
  local items = {}

  for key, value in pairs(config) do
    local directive_def = directive_index[key]
    if not directive_def then
      error(string.format("Unknown directive: '%s' in context '%s'", key, context))
    end

    validate_context(key, directive_def, context)
    local val_is_array = is_array(value)

    if directive_def.cardinality ~= "multiple" and val_is_array and type(value[1]) == "table" then
      error(string.format("Directive '%s' does not accept multiple values (array syntax). Use single value syntax instead.", key))
    end

    -- Normalize processing logic by treating items iteratively where allowed
    local values_to_process = (directive_def.cardinality == "multiple" and val_is_array) and value or { value }

    for _, item_value in ipairs(values_to_process) do
      if directive_def.type == "block" then
        local args_str, children_config = extract_args_and_children(item_value, directive_def)
        local children = {}
        local text_content = nil

        -- Extended block handling: text blocks (like *by_lua_block)
        if type(children_config) == "string" then
          text_content = children_config
        elseif directive_def.text_field then
          text_content = children_config[directive_def.text_field]
          if type(text_content) ~= "string" then
            error(string.format("Directive '%s' expects a string in field '%s'", key, directive_def.text_field))
          end
        else
          children = process_block(children_config, key, directive_index)
        end

        table.insert(items, { type = "block", name = key, args = args_str, children = children, text_content = text_content })
      else
        table.insert(items, process_directive(key, directive_def, item_value))
      end
    end
  end

  local default_sort_order = 500
  table.sort(items, function(a, b)
    local a_sort = directive_index[a.name].sort_order or default_sort_order
    local b_sort = directive_index[b.name].sort_order or default_sort_order
    if a_sort ~= b_sort then
      return a_sort < b_sort
    end
    return a.name < b.name
  end)

  return items
end

local function render_items(items, indent_level)
  local indent = string.rep("  ", indent_level)
  local lines = {}

  for _, item in ipairs(items) do
    if item.type == "flag" and item.value == true then
      table.insert(lines, indent .. item.name .. ";")
    elseif item.type == "directive" then
      local end_char = item.no_semi and "" or ";"

      -- Handle multiline directive values gracefully
      local value_lines = {}
      for s in string.gmatch(item.value, "([^\n]*)\n?") do
        if s ~= "" or not item.value:match("\n$") then
          table.insert(value_lines, s)
        end
      end

      -- Clean up trailing empty string caused by terminal newlines
      if value_lines[#value_lines] == "" and #value_lines > 1 then
        table.remove(value_lines)
      end

      if #value_lines <= 1 then
        table.insert(lines, indent .. item.name .. " " .. item.value .. end_char)
      else
        -- Indent the first line, then apply base indentation correctly to remaining inner lines
        table.insert(lines, indent .. item.name .. " " .. value_lines[1])
        for i = 2, #value_lines do
          if value_lines[i]:match("%S") then
            table.insert(lines, indent .. value_lines[i])
          else
            table.insert(lines, "")
          end
        end
        -- Append the semicolon (or nothing) only to the final line
        lines[#lines] = lines[#lines] .. end_char
      end
    elseif item.type == "block" then
      local block_line = indent .. item.name .. (item.args ~= "" and (" " .. item.args) or "") .. " {"
      table.insert(lines, block_line)
      
      -- Render textual block bodies (e.g. injected Lua code)
      if item.text_content then
        local text_lines = {}
        for s in string.gmatch(item.text_content, "([^\n]*)\n?") do
          table.insert(text_lines, s)
        end
        if text_lines[#text_lines] == "" and #text_lines > 1 then
          table.remove(text_lines)
        end

        -- Calculate existing indent to cleanly reformat
        local min_indent = nil
        for _, line in ipairs(text_lines) do
          if line:match("%S") then
            local current_indent = line:match("^%s*")
            if not min_indent or #current_indent < #min_indent then
              min_indent = current_indent
            end
          end
        end

        for _, line in ipairs(text_lines) do
          if line:match("%S") then
            -- Use an additional 4-space formatting indent for purely textual blocks
            table.insert(lines, indent .. "    " .. line:sub(#(min_indent or "") + 1))
          else
            table.insert(lines, "")
          end
        end
      else
        -- Standard block recursive rendering
        for _, child_line in ipairs(render_items(item.children, indent_level + 1)) do
          table.insert(lines, child_line)
        end
      end
      table.insert(lines, indent .. "}")
    end
  end

  return lines
end

local function deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deep_copy(orig_key)] = deep_copy(orig_value)
    end
    setmetatable(copy, deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

local function deep_merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) == "table" then
        -- If both are arrays, concatenate them
        if is_array(v) and is_array(dst[k]) then
          for _, item in ipairs(v) do
            table.insert(dst[k], deep_copy(item))
          end
        else
          deep_merge(dst[k], v)
        end
      else
        dst[k] = deep_copy(v)
      end
    else
      dst[k] = v
    end
  end
  return dst
end

--------------------------------------------------------------------------------
-- Config Proxy for dynamic metamethod chaining
--------------------------------------------------------------------------------

local function matches(item, query)
  if type(item) ~= type(query) then return item == query end
  if type(item) ~= "table" then return item == query end
  for k, v in pairs(query) do
    if type(v) == "table" then
      if not matches(item[k], v) then return false end
    else
      if item[k] ~= v then return false end
    end
  end
  return true
end

local ConfigProxy = {}

function ConfigProxy:new(generator, path)
  local proxy = {
    _generator = generator,
    _path = path
  }
  setmetatable(proxy, ConfigProxy)
  return proxy
end

ConfigProxy.__index = function(self, key)
  if ConfigProxy[key] then
    return ConfigProxy[key]
  end
  local new_path = {}
  for i, v in ipairs(self._path) do new_path[i] = v end
  table.insert(new_path, key)
  return ConfigProxy:new(self._generator, new_path)
end

local function get_or_create_target(config, path)
  local current = config
  for i = 1, #path - 1 do
    local key = path[i]
    if type(current[key]) ~= "table" then
      current[key] = {}
    end
    current = current[key]
  end
  return current, path[#path]
end

local function get_target(config, path)
  local current = config
  for i = 1, #path - 1 do
    local key = path[i]
    if type(current[key]) ~= "table" then
      return nil, nil
    end
    current = current[key]
  end
  return current, path[#path]
end

function ConfigProxy:set(value)
  local current, last_key = get_or_create_target(self._generator.config, self._path)
  current[last_key] = value
  return self._generator -- allow chaining methods back-to-back if desired
end

function ConfigProxy:add(value)
  local current, last_key = get_or_create_target(self._generator.config, self._path)
  local target = current[last_key]

  if target == nil then
    current[last_key] = { value }
  elseif type(target) == "table" and is_array(target) then
    table.insert(target, value)
  else
    -- Standardize existing value into an array alongside the newly added value
    current[last_key] = { target, value }
  end
  return self._generator
end

function ConfigProxy:remove(value)
  local current, last_key = get_target(self._generator.config, self._path)
  if not current or current[last_key] == nil then return self._generator end

  local target = current[last_key]
  if type(target) == "table" and is_array(target) then
    local i = 1
    while i <= #target do
      if matches(target[i], value) then
        table.remove(target, i)
      else
        i = i + 1
      end
    end
    -- Clean up if we emptied out the array entirely
    if #target == 0 then
      current[last_key] = nil
    end
  else
    if matches(target, value) then
      current[last_key] = nil
    end
  end
  return self._generator
end

--------------------------------------------------------------------------------
-- NginxGenerator Class
--------------------------------------------------------------------------------

local NginxGenerator = {}

-- Redirect property access into the ConfigProxy to initiate chained manipulation
NginxGenerator.__index = function(instance, key)
  if NginxGenerator[key] then return NginxGenerator[key] end
  return ConfigProxy:new(instance, {key})
end

--- Constructor for the NginxGenerator Class
function NginxGenerator.new(initial_config)
  local instance = setmetatable({}, NginxGenerator)
  instance.config = {}

  if initial_config then
    instance:add_config(initial_config)
  end

  return instance
end

--- Deep merges new configuration onto the existing configuration tree
function NginxGenerator:add_config(new_config)
  if type(new_config) ~= "table" then
    error("add_config expects a table")
  end

  self.config = deep_merge(self.config, new_config)
  return self -- Return self to allow method chaining
end

--- Processes the internal configuration and returns the generated Nginx string
function NginxGenerator:render()
  local items = process_block(self.config, "main", directive_index_cache)
  local lines = render_items(items, 0)
  return table.concat(lines, "\n") .. "\n"
end

return NginxGenerator