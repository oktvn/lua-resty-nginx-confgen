return function(Input, Output)
  local bool_spec = { { input = Input.boolean, output = Output.bool_onoff } }
  local scalar_spec = { { input = Input.scalar, output = Output.raw } }
  local string_spec = { { input = Input.string, output = Output.raw } }

  return {
    -- ngx_core directives
    { name = "events", sort_order = 8000, type = "block", contexts = { "main" } },
    { name = "accept_mutex", type = "directive", spec = bool_spec, contexts = { "events" } },
    { name = "accept_mutex_delay", type = "directive", spec = scalar_spec, contexts = { "events" } },
    { name = "daemon", type = "directive", spec = bool_spec, contexts = { "main" } },
    { name = "debug_connection", type = "directive", spec = { { input = Input.fields({ address = Input.required(Input.string) }), output = Output.field("address") }, { input = Input.fields({ cidr = Input.required(Input.string) }), output = Output.field("cidr") }, { input = Input.fields({ unix = Input.required(Input.string) }), output = Output.concat(":", { Output.literal("unix"), Output.field("unix") }) } }, cardinality = "multiple", contexts = { "events" } },
    { name = "debug_points", type = "directive", spec = { { input = Input.enum({ "abort", "stop" }), output = Output.raw } }, contexts = { "main" } },
    { name = "env", type = "directive", spec = { { input = Input.fields({ name = Input.required(Input.string), value = Input.required(Input.string) }), output = Output.concat("=", { Output.field("name"), Output.field("value") }) }, { input = Input.fields({ name = Input.required(Input.string) }), output = Output.field("name") } }, cardinality = "multiple", contexts = { "main" } },
    { name = "error_log", type = "directive", spec = { { input = Input.exact(false), output = Output.bool_onoff }, { input = Input.fields({ file = Input.required(Input.string), level = Input.optional(Input.enum({ "debug", "info", "notice", "warn", "error", "crit", "alert", "emerg" })) }), output = Output.concat(" ", { Output.field("file"), Output.field("level") }) } }, contexts = { "main", "http", "mail", "stream", "server", "location" }, cardinality = "multiple" },
    { name = "include", type = "directive", spec = string_spec, contexts = { "" }, cardinality = "multiple" },
    { name = "load_module", type = "directive", spec = string_spec, contexts = { "main" }, cardinality = "multiple" },
    { name = "lock_file", type = "directive", spec = string_spec, contexts = { "main" } },
    { name = "master_process", type = "directive", spec = bool_spec, contexts = { "main" } },
    { name = "multi_accept", type = "directive", spec = bool_spec, contexts = { "events" } },
    { name = "pcre_jit", type = "directive", spec = bool_spec, contexts = { "main" } },
    { name = "pid", type = "directive", spec = string_spec, contexts = { "main" } },
    { name = "ssl_engine", type = "directive", spec = string_spec, contexts = { "main" } },
    { name = "ssl_object_cache_inheritable", type = "directive", spec = bool_spec, contexts = { "main" } },
    { name = "stall_threshold", type = "directive", spec = scalar_spec, contexts = { "events" } },
    { name = "thread_pool", type = "directive", spec = { { input = Input.fields({ name = Input.required(Input.string), threads = Input.optional(Input.number), max_queue = Input.optional(Input.number) }), output = Output.concat(" ", { Output.field("name"), Output.keyval_pairs({ { key = "threads", formatter = Output.field("threads") }, { key = "max_queue", formatter = Output.field("max_queue") } }) }) } }, cardinality = "multiple", contexts = { "main" } },
    { name = "timer_resolution", type = "directive", spec = scalar_spec, contexts = { "main" } },
    { name = "use", type = "directive", spec = string_spec, contexts = { "events" } },
    { name = "user", type = "directive", spec = { { input = Input.string, output = Output.raw }, { input = Input.fields({ user = Input.required(Input.string), group = Input.optional(Input.string) }), output = Output.concat(" ", { Output.field("user"), Output.field("group") }) } }, contexts = { "main" } },
    { name = "worker_aio_requests", type = "directive", spec = { { input = Input.number, output = Output.raw } }, contexts = { "events" } },
    { name = "worker_connections", type = "directive", spec = { { input = Input.number, output = Output.raw } }, contexts = { "events" } },
    { name = "worker_cpu_affinity", type = "directive", spec = { { input = Input.string, output = Output.raw }, { input = Input.array(Input.string), output = Output.space }, { input = Input.fields({ auto = Input.exact(true), cpumask = Input.optional(Input.string) }), output = Output.concat(" ", { Output.chain(Output.field("auto"), Output.flag("auto")), Output.field("cpumask") }) } }, contexts = { "main" } },
    { name = "worker_priority", type = "directive", spec = { { input = Input.number, output = Output.raw } }, contexts = { "main" } },
    { name = "worker_processes", type = "directive", spec = { { input = Input.enum({ "auto" }), output = Output.raw }, { input = Input.number, output = Output.raw } }, contexts = { "main" } },
    { name = "worker_rlimit_core", type = "directive", spec = scalar_spec, contexts = { "main" } },
    { name = "worker_rlimit_nofile", type = "directive", spec = { { input = Input.number, output = Output.raw } }, contexts = { "main" } },
    { name = "worker_shutdown_timeout", type = "directive", spec = scalar_spec, contexts = { "main" } },
    { name = "working_directory", type = "directive", spec = string_spec, contexts = { "main" } },

    -- ngx_http_core_directives
    { name = "http", type = "block", sort_order = 9999, contexts = { "main" } },
    { name = "server", type = "block", sort_order = 9999, cardinality = "multiple", contexts = { "http" } },
    { name = "types", type = "block", contexts = { "http", "server", "location" } },
    { name = "limit_except", type = "block", arg_fields = { "methods" }, args = { { input = Input.fields({ methods = Input.required(Input.array(Input.string)) }), output = Output.chain(Output.field("methods"), Output.space) } }, contexts = { "location" } },
    {
      name = "location",
      type = "block",
      sort_order = 9999,
      arg_fields = { "modifier", "path" },
      args = {
        {
          input = Input.fields({
            modifier = Input.optional(Input.enum({ "=", "~", "~*", "^~", "@" })),
            path = Input.required(Input.string),
          }),
          output = Output.concat(" ", {
            Output.field("modifier"),
            Output.field("path"),
          }),
        },
      },
      cardinality = "multiple",
      contexts = { "server", "location" },
    },
    { name = "absolute_redirect", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "aio", type = "directive", spec = { { input = Input.boolean, output = Output.bool_onoff }, { input = Input.fields({ threads = Input.exact(true), pool = Input.optional(Input.string) }), output = Output.concat("=", { Output.literal("threads"), Output.field("pool") }) } }, contexts = { "http", "server", "location" } },
    { name = "aio_write", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "alias", type = "directive", spec = string_spec, contexts = { "location" } },
    { name = "auth_delay", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "chunked_transfer_encoding", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "client_body_buffer_size", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "client_body_in_file_only", type = "directive", spec = { { input = Input.boolean, output = Output.bool_onoff }, { input = Input.enum({ "clean" }), output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "client_body_in_single_buffer", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "client_body_temp_path", type = "directive", spec = { { input = Input.string, output = Output.raw }, { input = Input.fields({ path = Input.required(Input.string), level1 = Input.optional(Input.number), level2 = Input.optional(Input.number), level3 = Input.optional(Input.number) }), output = Output.concat(" ", { Output.field("path"), Output.field("level1"), Output.field("level2"), Output.field("level3") }) } }, contexts = { "http", "server", "location" } },
    { name = "client_body_timeout", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "client_header_buffer_size", type = "directive", spec = scalar_spec, contexts = { "http", "server" } },
    { name = "client_header_timeout", type = "directive", spec = scalar_spec, contexts = { "http", "server" } },
    { name = "client_max_body_size", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "connection_pool_size", type = "directive", spec = scalar_spec, contexts = { "http", "server" } },
    { name = "default_type", type = "directive", spec = string_spec, contexts = { "http", "server", "location" } },
    { name = "directio", type = "directive", spec = { { input = Input.exact(false), output = Output.bool_onoff }, { input = Input.scalar, output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "directio_alignment", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "disable_symlinks", type = "directive", spec = { { input = Input.boolean, output = Output.bool_onoff }, { input = Input.enum({ "if_not_owner" }), output = Output.raw }, { input = Input.fields({ mode = Input.required(Input.enum({ "on", "if_not_owner" })), from = Input.optional(Input.string) }), output = Output.concat(" ", { Output.field("mode"), Output.chain(Output.field("from"), Output.keyval("from")) }) } }, contexts = { "http", "server", "location" } },
    { name = "error_page", type = "directive", spec = { { input = Input.fields({ codes = Input.required(Input.array(Input.number)), uri = Input.required(Input.string) }), output = Output.concat(" ", { Output.chain(Output.field("codes"), Output.space), Output.field("uri") }) } }, cardinality = "multiple", contexts = { "http", "server", "location", "if in location" } },
    { name = "etag", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "if_modified_since", type = "directive", spec = { { input = Input.exact(false), output = Output.bool_onoff }, { input = Input.enum({ "exact", "before" }), output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "ignore_invalid_headers", type = "directive", spec = bool_spec, contexts = { "http", "server" } },
    { name = "internal", type = "flag", contexts = { "location" } },
    { name = "keepalive_disable", type = "directive", spec = { { input = Input.enum({ "none" }), output = Output.raw }, { input = Input.array(Input.string), output = Output.space } }, contexts = { "http", "server", "location" } },
    { name = "keepalive_min_timeout", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "keepalive_requests", type = "directive", spec = { { input = Input.number, output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "keepalive_time", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "keepalive_timeout", type = "directive", spec = { { input = Input.fields({ timeout = Input.required(Input.scalar), header_timeout = Input.optional(Input.scalar) }), output = Output.concat(" ", { Output.field("timeout"), Output.field("header_timeout") }) } }, contexts = { "http", "server", "location" } },
    { name = "large_client_header_buffers", type = "directive", spec = { { input = Input.fields({ number = Input.required(Input.number), size = Input.required(Input.scalar) }), output = Output.concat(" ", { Output.field("number"), Output.field("size") }) } }, contexts = { "http", "server" } },
    { name = "limit_rate", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location", "if in location" } },
    { name = "limit_rate_after", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location", "if in location" } },
    { name = "lingering_close", type = "directive", spec = { { input = Input.boolean, output = Output.bool_onoff }, { input = Input.enum({ "always" }), output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "lingering_time", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "lingering_timeout", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    {
      name = "listen",
      type = "directive",
      cardinality = "multiple",
      spec = {
        -- Full structured format
        {
          input = Input.fields({
            address = Input.optional(Input.string),
            port = Input.optional(Input.number),
            unix = Input.optional(Input.string),
            default_server = Input.optional(Input.boolean),
            ssl = Input.optional(Input.boolean),
            http2 = Input.optional(Input.boolean),
            quic = Input.optional(Input.boolean),
            proxy_protocol = Input.optional(Input.boolean),
            setfib = Input.optional(Input.number),
            fastopen = Input.optional(Input.number),
            backlog = Input.optional(Input.number),
            rcvbuf = Input.optional(Input.scalar),
            sndbuf = Input.optional(Input.scalar),
            accept_filter = Input.optional(Input.string),
            deferred = Input.optional(Input.boolean),
            bind = Input.optional(Input.boolean),
            ipv6only = Input.optional(Input.boolean),
            reuseport = Input.optional(Input.boolean),
            so_keepalive = Input.optional(Input.union({
              Input.boolean,
              Input.fields({
                keepidle = Input.optional(Input.scalar),
                keepintvl = Input.optional(Input.scalar),
                keepcnt = Input.optional(Input.number),
              }),
            })),
          }),
          output = Output.concat(" ", {
            -- Address/port/unix handling
            Output.when(Output.has_fields("unix"), Output.concat("", { Output.literal("unix:"), Output.field("unix") }), Output.when(Output.has_fields("address", "port"), Output.concat(":", { Output.field("address"), Output.field("port") }), Output.when(Output.has_fields("address"), Output.field("address"), Output.field("port")))),
            -- Boolean flags
            Output.chain(Output.field("default_server"), Output.flag("default_server")),
            Output.chain(Output.field("ssl"), Output.flag("ssl")),
            Output.chain(Output.field("http2"), Output.flag("http2")),
            Output.chain(Output.field("quic"), Output.flag("quic")),
            Output.chain(Output.field("proxy_protocol"), Output.flag("proxy_protocol")),
            Output.chain(Output.field("deferred"), Output.flag("deferred")),
            Output.chain(Output.field("bind"), Output.flag("bind")),
            Output.chain(Output.field("reuseport"), Output.flag("reuseport")),
            -- Key=value parameters
            Output.chain(Output.field("setfib"), Output.keyval("setfib")),
            Output.chain(Output.field("fastopen"), Output.keyval("fastopen")),
            Output.chain(Output.field("backlog"), Output.keyval("backlog")),
            Output.chain(Output.field("rcvbuf"), Output.keyval("rcvbuf")),
            Output.chain(Output.field("sndbuf"), Output.keyval("sndbuf")),
            Output.chain(Output.field("accept_filter"), Output.keyval("accept_filter")),
            Output.chain(Output.field("ipv6only"), Output.bool_onoff_keyval("ipv6only")),
            -- so_keepalive special handling
            Output.chain(
              Output.field("so_keepalive"),
              Output.when(
                Output.typeof("boolean"),
                Output.bool_onoff_keyval("so_keepalive"),
                Output.when(
                  Output.typeof("string"),
                  Output.keyval("so_keepalive"),
                  Output.concat("", {
                    Output.literal("so_keepalive="),
                    Output.concat(":", {
                      Output.field("keepidle"),
                      Output.field("keepintvl"),
                      Output.field("keepcnt"),
                    }),
                  })
                )
              )
            ),
          }),
        },
      },
      contexts = { "server" },
    },
    { name = "log_not_found", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "log_subrequest", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "max_ranges", type = "directive", spec = { { input = Input.number, output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "merge_slashes", type = "directive", spec = bool_spec, contexts = { "http", "server" } },
    { name = "msie_padding", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "msie_refresh", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "open_file_cache", type = "directive", spec = { { input = Input.exact(false), output = Output.bool_onoff }, { input = Input.fields({ max = Input.required(Input.number), inactive = Input.optional(Input.scalar) }), output = Output.concat(" ", { Output.chain(Output.field("max"), Output.keyval("max")), Output.chain(Output.field("inactive"), Output.keyval("inactive")) }) } }, contexts = { "http", "server", "location" } },
    { name = "open_file_cache_errors", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "open_file_cache_min_uses", type = "directive", spec = { { input = Input.number, output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "open_file_cache_valid", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "output_buffers", type = "directive", spec = { { input = Input.fields({ number = Input.required(Input.number), size = Input.required(Input.scalar) }), output = Output.concat(" ", { Output.field("number"), Output.field("size") }) } }, contexts = { "http", "server", "location" } },
    { name = "port_in_redirect", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "postpone_output", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "read_ahead", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "recursive_error_pages", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "request_pool_size", type = "directive", spec = scalar_spec, contexts = { "http", "server" } },
    { name = "reset_timedout_connection", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    {
      name = "resolver",
      type = "directive",
      spec = {
        {
          input = Input.fields({
            addresses = Input.required(Input.array(Input.string)),
            valid = Input.optional(Input.scalar),
            ipv4 = Input.optional(Input.boolean),
            ipv6 = Input.optional(Input.boolean),
            status_zone = Input.optional(Input.string),
          }),
          output = Output.concat(" ", {
            Output.chain(Output.field("addresses"), Output.space),
            Output.chain(Output.field("valid"), Output.keyval("valid")),
            Output.chain(Output.field("ipv4"), Output.bool_onoff_keyval("ipv4")),
            Output.chain(Output.field("ipv6"), Output.bool_onoff_keyval("ipv6")),
            Output.chain(Output.field("status_zone"), Output.keyval("status_zone")),
          }),
        },
      },
      contexts = { "http", "server", "location" },
    },
    { name = "resolver_timeout", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "root", type = "directive", spec = string_spec, contexts = { "http", "server", "location", "if in location" } },
    { name = "satisfy", type = "directive", spec = { { input = Input.enum({ "all", "any" }), output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "send_lowat", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "send_timeout", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "sendfile", type = "directive", spec = bool_spec, contexts = { "http", "server", "location", "if in location" } },
    { name = "sendfile_max_chunk", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "server_name", type = "directive", spec = { { input = Input.string, output = Output.raw }, { input = Input.array(Input.string), output = Output.space } }, contexts = { "server" } },
    { name = "server_name_in_redirect", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "server_names_hash_bucket_size", type = "directive", spec = scalar_spec, contexts = { "http" } },
    { name = "server_names_hash_max_size", type = "directive", spec = scalar_spec, contexts = { "http" } },
    { name = "server_tokens", type = "directive", spec = { { input = Input.boolean, output = Output.bool_onoff }, { input = Input.enum({ "build" }), output = Output.raw }, { input = Input.string, output = Output.raw } }, contexts = { "http", "server", "location" } },
    { name = "subrequest_output_buffer_size", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "tcp_nodelay", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    { name = "tcp_nopush", type = "directive", spec = bool_spec, contexts = { "http", "server", "location" } },
    {
      name = "try_files",
      type = "directive",
      spec = {
        {
          input = Input.fields({
            files = Input.required(Input.array(Input.string)),
            uri = Input.optional(Input.string),
            code = Input.optional(Input.number),
          }),
          output = Output.concat(" ", {
            Output.chain(Output.field("files"), Output.space),
            Output.when(
              Output.has_fields("uri"),
              Output.field("uri"),
              Output.concat("", {
                Output.literal("="),
                Output.field("code"),
              })
            ),
          }),
        },
      },
      contexts = { "server", "location" },
    },
    { name = "types_hash_bucket_size", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "types_hash_max_size", type = "directive", spec = scalar_spec, contexts = { "http", "server", "location" } },
    { name = "underscores_in_headers", type = "directive", spec = bool_spec, contexts = { "http", "server" } },
    { name = "variables_hash_bucket_size", type = "directive", spec = scalar_spec, contexts = { "http" } },
    { name = "variables_hash_max_size", type = "directive", spec = scalar_spec, contexts = { "http" } },

    -- ngx_http_log_module
    {
      name = "access_log",
      type = "directive",
      spec = {
        { input = Input.exact(false), output = Output.bool_onoff },
        { input = Input.string, output = Output.raw },
        {
          input = Input.fields({
            path = Input.required(Input.string),
            format = Input.optional(Input.string),
            buffer = Input.optional(Input.scalar),
            gzip = Input.optional(Input.union({ Input.boolean, Input.scalar })),
            flush = Input.optional(Input.scalar),
            condition = Input.optional(Input.string),
          }),
          output = Output.concat(" ", {
            Output.field("path"),
            Output.field("format"),
            Output.chain(Output.field("buffer"), Output.keyval("buffer")),
            Output.chain(Output.field("gzip"), Output.when(Output.typeof("boolean"), Output.flag("gzip"), Output.keyval("gzip"))),
            Output.chain(Output.field("flush"), Output.keyval("flush")),
            Output.chain(Output.field("condition"), Output.keyval("if")),
          }),
        },
      },
      cardinality = "multiple",
      contexts = { "http", "server", "location", "if in location", "limit_except" },
    },
    {
      name = "log_format",
      type = "directive",
      spec = {
        {
          input = Input.fields({
            name = Input.required(Input.string),
            escape = Input.optional(Input.enum({ "default", "json", "none" })),
            format = Input.required(Input.string),
          }),
          output = Output.concat(" ", {
            Output.field("name"),
            Output.field("escape"),
            Output.field("format"),
          }),
        },
      },
      cardinality = "multiple",
      contexts = { "http" },
    },
    {
      name = "open_log_file_cache",
      type = "directive",
      spec = {
        { input = Input.exact(false), output = Output.bool_onoff },
        {
          input = Input.fields({
            max = Input.required(Input.number),
            inactive = Input.optional(Input.scalar),
            min_uses = Input.optional(Input.number),
            valid = Input.optional(Input.scalar),
          }),
          output = Output.concat(" ", {
            Output.chain(Output.field("max"), Output.keyval("max")),
            Output.chain(Output.field("inactive"), Output.keyval("inactive")),
            Output.chain(Output.field("min_uses"), Output.keyval("min_uses")),
            Output.chain(Output.field("valid"), Output.keyval("valid")),
          }),
        },
      },
      contexts = { "http", "server", "location" },
    },

    -- ngx_http_access_module
    {
      name = "deny",
      type = "directive",
      spec = {
        { input = Input.fields({ address = Input.required(Input.string) }), output = Output.field("address") },
        { input = Input.fields({ cidr = Input.required(Input.string) }), output = Output.field("cidr") },
        { input = Input.fields({ unix = Input.required(Input.string) }), output = Output.concat(":", { Output.literal("unix"), Output.field("unix") }) },
        { input = Input.exact(true), output = Output.literal("all") },
      },
      cardinality = "multiple",
      contexts = { "http", "server", "location", "limit_except" },
    },
    {
      name = "allow",
      type = "directive",
      spec = {
        { input = Input.fields({ address = Input.required(Input.string) }), output = Output.field("address") },
        { input = Input.fields({ cidr = Input.required(Input.string) }), output = Output.field("cidr") },
        { input = Input.fields({ unix = Input.required(Input.string) }), output = Output.concat(":", { Output.literal("unix"), Output.field("unix") }) },
        { input = Input.exact(true), output = Output.literal("all") },
      },
      cardinality = "multiple",
      contexts = { "http", "server", "location", "limit_except" },
    },
    -- ngx_rewrite
    { name = "break", type = "flag", contexts = { "server", "location", "if" } },
    { name = "if", type = "block", arg_fields = { "condition" }, args = { { input = Input.fields({ condition = Input.required(Input.string) }), output = Output.concat("", { Output.literal("("), Output.field("condition"), Output.literal(")") }) } }, cardinality = "multiple", contexts = { "server", "location" } },
    { name = "return", type = "directive", spec = { { input = Input.number, output = Output.raw }, { input = Input.string, output = Output.raw }, { input = Input.fields({ code = Input.required(Input.number), text = Input.required(Input.string) }), output = Output.concat(" ", { Output.field("code"), Output.field("text") }) }, { input = Input.fields({ code = Input.required(Input.number), url = Input.required(Input.string) }), output = Output.concat(" ", { Output.field("code"), Output.field("url") }) } }, cardinality = "multiple", contexts = { "server", "location", "if" } },
    { name = "rewrite", type = "directive", spec = { { input = Input.fields({ regex = Input.required(Input.string), replacement = Input.required(Input.string), flag = Input.optional(Input.enum({ "last", "break", "redirect", "permanent" })) }), output = Output.concat(" ", { Output.field("regex"), Output.field("replacement"), Output.field("flag") }) } }, cardinality = "multiple", contexts = { "server", "location", "if" } },
    { name = "rewrite_log", type = "directive", spec = bool_spec, contexts = { "http", "server", "location", "if" } },
    { name = "set", type = "directive", spec = { { input = Input.fields({ variable = Input.required(Input.string), value = Input.required(Input.scalar) }), output = Output.concat(" ", { Output.field("variable"), Output.field("value") }) } }, cardinality = "multiple", contexts = { "server", "location", "if" } },
    { name = "uninitialized_variable_warn", type = "directive", spec = bool_spec, contexts = { "http", "server", "location", "if" } }
  }
end
