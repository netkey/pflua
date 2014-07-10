module(...,package.seeall)

local bit = require('bit')

verbose = os.getenv("PF_VERBOSE");

local expand_arith, expand_relop, expand_bool

local function set(...)
   local ret = {}
   for k, v in pairs({...}) do ret[v] = true end
   return ret
end
local function concat(a, b)
   local ret = {}
   for _, v in ipairs(a) do table.insert(ret, v) end
   for _, v in ipairs(b) do table.insert(ret, v) end
   return ret
end

local ether_protos = set(
   'ip', 'ip6', 'arp', 'rarp', 'atalk', 'aarp', 'decnet', 'sca', 'lat',
   'mopdl', 'moprc', 'iso', 'stp', 'ipx', 'netbeui'
)

local ip_protos = set(
   'icmp', 'icmp6', 'igmp', 'igrp', 'pim', 'ah', 'esp', 'vrrp', 'udp', 'tcp'
)

local llc_types = set(
   'i', 's', 'u', 'rr', 'rnr', 'rej', 'ui', 'ua',
   'disc', 'sabme', 'test', 'xis', 'frmr'
)

local pf_reasons = set(
   'match', 'bad-offset', 'fragment', 'short', 'normalize', 'memory'
)

local pf_actions = set(
   'pass', 'block', 'nat', 'rdr', 'binat', 'scrub'
)

local wlan_frame_types = set('mgt', 'ctl', 'data')
local wlan_frame_mgt_subtypes = set(
   'assoc-req', 'assoc-resp', 'reassoc-req', 'reassoc-resp',
   'probe-req', 'probe-resp', 'beacon', 'atim', 'disassoc', 'auth', 'deauth'
)
local wlan_frame_ctl_subtypes = set(
   'ps-poll', 'rts', 'cts', 'ack', 'cf-end', 'cf-end-ack'
)
local wlan_frame_data_subtypes = set(
   'data', 'data-cf-ack', 'data-cf-poll', 'data-cf-ack-poll', 'null',
   'cf-ack', 'cf-poll', 'cf-ack-poll', 'qos-data', 'qos-data-cf-ack',
   'qos-data-cf-poll', 'qos-data-cf-ack-poll', 'qos', 'qos-cf-poll',
   'quos-cf-ack-poll'
)

local wlan_directions = set('nods', 'tods', 'fromds', 'dstods')

local iso_proto_types = set('clnp', 'esis', 'isis')

local function unimplemented(expr, dlt)
   error("not implemented: "..expr[1])
end

local function has_ether_protocol(proto)
   return { '=', { '[ether]', 12, 2 }, proto }
end
local function has_ipv4_protocol(proto)
   return { '=', { '[ip]', 9, 1 }, proto }
end
local function is_first_ipv4_fragment()
   return { '=', { '&', { '[ip]', 6, 2 }, 0x1fff }, 0 }
end
local function has_ipv6_protocol(proto)
   return { 'or',
            { '=', { '[ip6]', 6, 1 }, 6 },
            { 'and',
              { '=', { '[ip6]', 6, 1 }, 44 },
              { '=', { '[ip6]', 40, 1 }, 6 } } }
end
local function has_ip_protocol(proto)
   return { 'if', { 'ip' },
            has_ipv4_protocol(proto),
            { 'and', { 'ip6' }, has_ipv6_protocol(proto) } }
end

local primitive_expanders = {
   dst_host = unimplemented,
   dst_net = unimplemented,
   dst_port = unimplemented,
   dst_portrange = unimplemented,
   src_host = unimplemented,
   src_net = unimplemented,
   src_port = unimplemented,
   src_portrange = unimplemented,
   host = unimplemented,
   ether_src = unimplemented,
   ether_dst = unimplemented,
   ether_host = unimplemented,
   ether_broadcast = unimplemented,
   ether_multicast = unimplemented,
   ether_proto = unimplemented,
   gateway = unimplemented,
   net = unimplemented,
   port = unimplemented,
   portrange = unimplemented,
   less = unimplemented,
   greater = unimplemented,
   ip = function(expr) return has_ether_protocol(2048) end,
   ip_proto = unimplemented,
   ip_protochain = unimplemented,
   ip_broadcast = unimplemented,
   ip_multicast = unimplemented,
   ip6 = function(expr) return has_ether_protocol(34525) end,
   ip6_proto = unimplemented,
   ip6_protochain = unimplemented,
   ip6_multicast = unimplemented,
   proto = unimplemented,
   tcp = function(expr) return has_ip_protocol(6) end,
   udp = function(expr) return has_ip_protocol(17) end,
   icmp = function(expr) return has_ip_protocol(1) end,
   protochain = unimplemented,
   arp = function(expr) return has_ether_protocol(2054) end,
   rarp = function(expr) return has_ether_protocol(32821) end,
   atalk = unimplemented,
   aarp = unimplemented,
   decnet_src = unimplemented,
   decnet_dst = unimplemented,
   decnet_host = unimplemented,
   iso = unimplemented,
   stp = unimplemented,
   ipx = unimplemented,
   netbeui = unimplemented,
   lat = unimplemented,
   moprc = unimplemented,
   mopdl = unimplemented,
   llc = unimplemented,
   ifname = unimplemented,
   on = unimplemented,
   rnr = unimplemented,
   rulenum = unimplemented,
   reason = unimplemented,
   rset = unimplemented,
   ruleset = unimplemented,
   srnr = unimplemented,
   subrulenum = unimplemented,
   action = unimplemented,
   wlan_ra = unimplemented,
   wlan_ta = unimplemented,
   wlan_addr1 = unimplemented,
   wlan_addr2 = unimplemented,
   wlan_addr3 = unimplemented,
   wlan_addr4 = unimplemented,
   type = unimplemented,
   type_subtype = unimplemented,
   subtype = unimplemented,
   dir = unimplemented,
   vlan = unimplemented,
   mpls = unimplemented,
   pppoed = unimplemented,
   pppoes = unimplemented,
   iso_proto = unimplemented,
   clnp = unimplemented,
   esis = unimplemented,
   isis = unimplemented,
   l1 = unimplemented,
   l2 = unimplemented,
   iih = unimplemented,
   lsp = unimplemented,
   snp = unimplemented,
   csnp = unimplemented,
   psnp = unimplemented,
   vpi = unimplemented,
   vci = unimplemented,
   lane = unimplemented,
   oamf4s = unimplemented,
   oamf4e = unimplemented,
   oamf4 = unimplemented,
   oam = unimplemented,
   metac = unimplemented,
   bcc = unimplemented,
   sc = unimplemented,
   ilmic = unimplemented,
   connectmsg = unimplemented,
   metaconnect = unimplemented
}

local relops = set('<', '<=', '=', '!=', '>=', '>')

local addressables = set(
   'arp', 'rarp', 'wlan', 'ether', 'fddi', 'tr', 'ppp',
   'slip', 'link', 'radio', 'ip', 'ip6', 'tcp', 'udp', 'icmp'
)

local binops = set(
   '+', '-', '*', '/', '%', '&', '|', '^', '&&', '||', '<<', '>>'
)
local associative_binops = set(
   '+', '*', '&', '|'
)

local function expand_offset(level, dlt)
   assert(dlt == "EN10MB", "Encapsulation other than EN10MB unimplemented")
   local function assert_expr(expr)
      local test, asserts = expand_relop(expr, dlt)
      return concat(asserts, { test })
   end
   local function assert_ether_protocol(proto)
      return assert_expr(has_ether_protocol(proto))
   end
   function assert_ipv4_protocol(proto)
      return assert_expr(has_ipv4_protocol(proto))
   end
   function assert_first_ipv4_fragment()
      return assert_expr(is_first_ipv4_fragment())
   end
   function ipv4_payload_offset(proto)
      local ip_offset, ip_asserts = expand_offset('ip', dlt)
      local asserts = concat(concat(ip_asserts, assert_ipv4_protocol(proto)),
                             assert_first_ipv4_fragment())
      local res = { '+',
                    { '<<', { '&', { '[]', ip_offset, 1 }, 0xf }, 2 },
                    ip_offset }
      return res, asserts
   end

   -- Note that unlike their corresponding predicates which detect
   -- either IPv4 or IPv6 traffic, [icmp], [udp], and [tcp] only work
   -- for IPv4.
   if level == 'ether' then
      return 0, {}
   elseif level == 'arp' then
      return 14, assert_ether_protocol(2054)
   elseif level == 'rarp' then
      return 14, assert_ether_protocol(32821)
   elseif level == 'ip' then
      return 14, assert_ether_protocol(2048)
   elseif level == 'ip6' then
      return 14, assert_ether_protocol(34525)
   elseif level == 'icmp' then
      return ipv4_payload_offset(1)
   elseif level == 'udp' then
      return ipv4_payload_offset(17)
   elseif level == 'tcp' then
      return ipv4_payload_offset(6)
   end
   error('invalid level '..level)
end

function expand_arith(expr, dlt)
   if type(expr) == 'number' or expr == 'len' then return expr, {} end

   local op = expr[1]
   if binops[op] then
      local lhs, lhs_assertions = expand_arith(expr[2], dlt)
      local rhs, rhs_assertions = expand_arith(expr[3], dlt)
      return { op, lhs, rhs}, concat(lhs_assertions, rhs_assertions)
   end

   assert(op ~= '[]', "expr has already been expanded?")
   local addressable = assert(op:match("^%[(%w+)%]$"), "bad op "..op)
   local offset, offset_asserts = expand_offset(addressable, dlt)
   local lhs, lhs_asserts = expand_arith(expr[2], dlt)
   local rhs = expr[3]
   local len_assert = { '<=', { '+', { '+', offset, lhs }, rhs }, 'len' }
   local asserts = concat(concat(offset_asserts, lhs_asserts), { len_assert })
   return { '[]', { '+', offset, lhs }, rhs }, asserts
end

function expand_relop(expr, dlt)
   local lhs, lhs_assertions = expand_arith(expr[2], dlt)
   local rhs, rhs_assertions = expand_arith(expr[3], dlt)
   return { expr[1], lhs, rhs }, concat(lhs_assertions, rhs_assertions)
end

function expand_bool(expr, dlt)
   assert(type(expr) == 'table', 'logical expression must be a table')
   if expr[1] == 'not' or expr[1] == '!' then
      return { 'not', expand_bool(expr[2], dlt) }
   elseif expr[1] == 'and' or expr[1] == '&&' then
      return { 'and', expand_bool(expr[2], dlt), expand_bool(expr[3], dlt) }
   elseif expr[1] == 'or' or expr[1] == '||' then
      return { 'or', expand_bool(expr[2], dlt), expand_bool(expr[3], dlt) }
   elseif relops[expr[1]] then
      -- An arithmetic relop.
      local res, assertions = expand_relop(expr, dlt)
      while #assertions ~= 0 do
         res = { 'assert', table.remove(assertions), res }
      end
      return res
   elseif expr[1] == 'if' then
      return { 'if',
               expand_bool(expr[2], dlt),
               expand_bool(expr[3], dlt),
               expand_bool(expr[4], dlt) }
   else
      -- A logical primitive.
      local expander = primitive_expanders[expr[1]]
      assert(expander, "unimplemented primitive: "..expr[1])
      local expanded = expander(expr, dlt)
      return expand_bool(expander(expr, dlt), dlt)
   end
end

local folders = {
   ['+'] = function(a, b) return a + b end,
   ['-'] = function(a, b) return a - b end,
   ['*'] = function(a, b) return a * b end,
   ['/'] = function(a, b) return math.floor(a / b) end,
   ['%'] = function(a, b) return a % b end,
   ['&'] = function(a, b) return bit.band(a, b) end,
   ['^'] = function(a, b) return bit.bxor(a, b) end,
   ['|'] = function(a, b) return bit.bor(a, b) end,
   ['<<'] = function(a, b) return bit.lshift(a, b) end,
   ['>>'] = function(a, b) return bit.rshift(a, b) end
}

function simplify(expr)
   if type(expr) ~= 'table' then return expr end
   local op = expr[1]
   if binops[op] then
      local lhs = simplify(expr[2])
      local rhs = simplify(expr[3])
      if type(lhs) == 'number' and type(rhs) == 'number' then
         return assert(folders[op])(lhs, rhs)
      elseif associative_binops[op] then
         if type(rhs) == 'table' and rhs[1] == op and type(lhs) == 'number' then
            lhs, rhs = rhs, lhs
         end
         if type(lhs) == 'table' and lhs[1] == op and type(rhs) == 'number' then
            if type(lhs[2]) == 'number' then
               return { op, assert(folders[op])(lhs[2], rhs), lhs[3] }
            elseif type(lhs[3]) == 'number' then
               return { op, lhs[2], assert(folders[op])(lhs[3], rhs) }
            end
         end
      end
      return { op, lhs, rhs }
   else
      local res = { op }
      for i=2,#expr do table.insert(res, simplify(expr[i])) end
      return res
   end
end

function expand(expr, dlt)
   dlt = dlt or 'RAW'
   return simplify(expand_bool(expr, dlt))
end

function pp(expr, indent, suffix)
   indent = indent or ''
   suffix = suffix or ''
   if type(expr) ~= 'table' then
      print(indent..expr..suffix)
   elseif #expr == 1 then
      print(indent..'{ '..expr[1]..' }'..suffix)
   else
      print(indent..'{ '..expr[1]..',')
      indent = indent..'  '
      for i=2,#expr-1 do pp(expr[i], indent, ',') end
      pp(expr[#expr], indent, ' }'..suffix)
   end
end

function selftest ()
   print("selftest: pf.expand")
   local parse = require('pf.parse').parse
   local function equals(expected, actual)
      if type(expected) ~= type(actual) then return false end
      if type(expected) == 'table' then
         for k, v in pairs(expected) do
            if not equals(v, actual[k]) then return false end
         end
         return true
      else
         return expected == actual
      end
   end
   local function check(expected, actual)
      if not equals(expected, actual) then
         pp(expected)
         pp(actual)
         error('not equal')
      end
   end
   check({ '=', 1, 2 },
      expand(parse("1 = 2"), 'EN10MB'))
   check({ 'assert', { '<=', 1, 'len'}, { '=', { '[]', 0, 1 }, 2 } },
      expand(parse("ether[0] = 2"), 'EN10MB'))
   print("OK")
end