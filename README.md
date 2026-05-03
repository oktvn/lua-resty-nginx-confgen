# lua-resty-nginx-confgen

A library for generating Nginx configuration files from plain Lua tables.

Build Nginx configs as Lua tables, get validation and context-checking for free,
and render clean output. 

## Why?

Hand-writing Nginx configs is error-prone - directives have strict context
rules, argument formats vary wildly between modules, and templated configs
(`envsubst`, Jinja, etc.) don't catch mistakes until Nginx itself rejects them.

This library lets you express config as data, validates it at generation time,
and produces output that's easy to diff and review.

## Installation

```sh
luarocks install --dev lua-resty-nginx-confgen
```

## Quick start

```lua
local NginxGenerator = require("resty.nginx.confgen")

local nginx = NginxGenerator:new({
  worker_processes = "auto",
  events = {
    worker_connections = 1024,
  },
  http = {
    sendfile = true,
    keepalive_timeout = { timeout = "65s" },
    server = {
      listen = { port = 80, default_server = true },
      server_name = "example.com",
      location = {
        { path = "/", root = "/var/www/html" },
      },
    },
  },
})

print(nginx:render())
```

Produces:

```nginx
worker_processes auto;
events {
  worker_connections 1024;
}
http {
  sendfile on;
  keepalive_timeout 65s;
  server {
    listen 80 default_server;
    server_name example.com;
    location / {
      root /var/www/html;
    }
  }
}
```

## Examples:

```
local NginxGenerator = require("resty.nginx.confgen")

local config = {
  worker_processes = "auto",
  
  events = {
    worker_connections = 1024,
    multi_accept = true
  },

  http = {
    server_tokens = false,
    sendfile = true,
    tcp_nopush = true,
    tcp_nodelay = true,
    keepalive_timeout = { timeout = 65 },

    server = {
      {
        listen = {
          { port = 80, default_server = true }
        },
        server_name = { "example.com", "www.example.com" },
        root = "/var/www/html",

        location = {
          {
            path = "/",
            -- Tests the complex `try_files` definition
            try_files = {
              files = { "$uri", "$uri/" },
              code = 404
            }
          },
          {
            modifier = "=",
            path = "/healthz",
            access_log = false,
            ["return"] = { code = 200, text = '"OK"' }
          }
        }
      }
    }
  }
}

local gen = NginxGenerator.new(config)
print(gen:render())
```

### Openresty

```
local NginxGenerator = require("resty.nginx.confgen")

local config = {
  http = {
    lua_package_path = "/opt/app/?.lua;;",
    lua_package_cpath = "/opt/app/?.so;;",
    
    lua_shared_dict = {
      { name = "my_cache", size = "10m" },
      { name = "rate_limits", size = "5m" }
    },

    init_by_lua_block = [[
      require "resty.core"
      local my_app = require "my_app"
      my_app.setup()
    ]],

    server = {
      {
        listen = { { port = 8080 } },
        server_name = { "localhost" },

        location = {
          {
            path = "/api",
            access_by_lua_block = [[
              local auth = require "my_auth"
              if not auth.check(ngx.var.http_authorization) then
                ngx.exit(ngx.HTTP_UNAUTHORIZED)
              end
            ]],
            content_by_lua_block = [[
              ngx.header.content_type = "application/json"
              ngx.say('{"status": "ok", "message": "Authenticated!"}')
            ]]
          },
          {
            path = "/upload",
            modifier = "=",
            lua_need_request_body = true,
            client_max_body_size = "10m",
            content_by_lua_file = "/opt/app/handlers/upload.lua"
          }
        }
      }
    }
  }
}

local gen = NginxGenerator.new(config)
print(gen:render())
```

## Composition

Configs can be built up in stages with `add_config`. Arrays merge by
concatenation, tables merge deeply:

```lua
local nginx = NginxGenerator:new(base_config)
  :add_config(ssl_config)
  :add_config(rate_limit_config)

print(nginx:render())
```

## Validation

Invalid input fails fast at render time with a clear error:

```lua
NginxGenerator:new({
  http = {
    listen = { port = 80 },  -- error: `listen` is only valid in `server` context
  },
}):render()
```

```
nginx directive 'listen' cannot be used in context 'http'.
Valid contexts: server
```

## Supported directives

Currently covered:

- `ngx_core` - worker, events, logging
- `ngx_http_core` - http, server, location, listen, try_files, etc.
- `ngx_http_log` - access_log, log_format
- `ngx_http_access` - allow, deny
- `ngx_http_rewrite` - if, return, rewrite, set
- `lua-nginx-module` - content_by_lua_block, init_by_lua_block, etc.

## License

MIT - see [LICENSE](LICENSE).