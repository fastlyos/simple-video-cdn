local redis = require "resty.redis"

local load_balancer = {}
local index_reference = 1

-- -- get the decision algoritmn from environment variable
-- local function get_algoritm()
--     return os.getenv("LB_ALGORITM")
-- end

-- -- get caches ports range from environment varible
-- local function get_ports_range_from_env()
--     return
-- end

-- get first and last port from the string range
local function get_first_and_last_ports()
    local ports_range = os.getenv("CACHE_PORTS_RANGE")
    local first = string.sub(ports_range,1,4)
    local last = string.sub(ports_range,6,9)

    return first, last
end

-- list all health servers from redis
function get_health_servers()
    local red = redis:new()
    red:set_timeout(1000)
    red:connect("172.22.0.100", 6379)

    local first, last = get_first_and_last_ports()
    local a = {}

    for i=0, (last-first) do
        local port = first+i
        local conns = red:get(port)

        if conns then
            a[i+1] = math.floor(port)
        end
    end

    red:set_keepalive(10000, 100)
    return a
end

-- table with all health servers from redis with their active connections number
function get_health_servers_with_connections()
    local red = redis:new()
    red:set_timeout(1000)
    red:connect("172.22.0.100", 6379)

    local first, last = get_first_and_last_ports()
    local a = {}

    for i=0, (last-first) do
        local port = first+i
        local conns = red:get(port)

        if conns then
            a[i+1] = math.floor(port)
        end
    end

    red:set_keepalive(10000, 100)
    return a
end

-- call the method for the decision algoritmn chossed
load_balancer.cache = function()
    local cache = load_balancer[os.getenv("LB_ALGORITM")]()

    return ngx.redirect(cache .. ngx.var.uri);
end

-- all functions are desions make algoritms till the end of file
load_balancer.random = function()
    local ports = get_health_servers()
    local port = ports[math.random(1,#ports)]

    return "http://0.0.0.0:" .. port
end

load_balancer.round_robin = function()
    local ports = get_health_servers()
    local port_index = math.fmod(index_reference,#ports) + 1
    local port = ports[port_index]
    index_reference = index_reference + 1

    return "http://0.0.0.0:" .. port
end

load_balancer.least_conn = function()
    local red = redis:new()
    red:set_timeout(1000)
    red:connect("172.22.0.100", 6379)

    local first, last = get_first_and_last_ports()

    local port = first
    local conns = tonumber(red:get(port))

    local least_conn_port = port
    local least_conn_conns = conns

    for i=1, (last-first) do
        port = first+i
        conns = tonumber(red:get(port))

        if conns < least_conn_conns then
            least_conn_port = port
            least_conn_conns = conns
        end
    end

    red:set_keepalive(10000, 100)

    return "http://0.0.0.0:" .. least_conn_port
end

-- TODO --
load_balancer.choose_host_hash = function()
end

-- TODO --
load_balancer.choose_host_consistent_hash = function()
end

-- TODO --
load_balancer.choose_host_consistent_hash_bound_load = function()
end

-- return the load_balancer object
return load_balancer
