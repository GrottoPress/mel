local gmatch = string.gfind or string.gmatch
local unpack = unpack or table.unpack

local function with_score(ids, score)
  local results = {}

  for _, id in ipairs(ids) do
    table.insert(results, score)
    table.insert(results, id)
  end

  return results
end

local function split_string(input, delimiter)
  local results = {}

  for part in gmatch(input, '([^' .. delimiter .. ']+)') do
    table.insert(results, part)
  end

  return results
end

local function update_score(ids, score)
  if #ids ~= 0 then
    redis.call('ZADD', KEYS[1], 'XX', unpack(with_score(ids, score)))
  end
end

local running_ids = split_string(ARGV[5], ',')
update_score(running_ids, ARGV[3])

local due_ids = redis.call(
  'ZRANGEBYSCORE',
  KEYS[1],
  ARGV[4],
  ARGV[1],
  'LIMIT',
  0,
  ARGV[2]
)

update_score(due_ids, ARGV[3])

return due_ids
