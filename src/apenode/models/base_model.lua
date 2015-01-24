-- Copyright (C) Mashape, Inc.

local Object = require "classic"
local Validator = require "apenode.models.validator"

local BaseModel = Object:extend()

function BaseModel:validate(update)
  return Validator.validate(self._t, self._schema, update)
end

---------------
-- BaseModel --
---------------

function BaseModel:new(collection, schema, values, dao_factory)
  if not values then values = {} end

  self._schema = schema
  self._dao = dao_factory[collection]

  -- Populate the new object with the same fields
  for k,v in pairs(values) do
    self[k] = v
  end

  self._t = values
end

-- Save a model's values in database
-- @return {table} Values returned by the DAO's insert result
function BaseModel:save()
  local _, err = self:validate()
  if err then
    return nil, err
  end

  -- Check for unique properties
  for k, schema_field in pairs(self._schema) do
    if schema_field.unique and self._t[k] then
      local data, err = self._dao:find_one { [k] = self._t[k] }
      if data ~= nil then
        return nil, k.." with value ".."\""..self._t[k].."\"".." already exists"
      elseif err then
        return nil, err
      end
    end
  end

  return self._dao:insert(self._t)
end

-- Update a model's values in database
-- @return {number} Number of rows affected by the update
function BaseModel:update()
  -- Check if there are updated fields
  for k,_ in pairs(self._t) do
    if self[k] then
      self._t[k] = self[k]
    end
  end

  local _, err = self:validate(true)
  if err then
    return 0, err
  end

  -- Check for unique properties
  for k, schema_field in pairs(self._schema) do
    if schema_field.unique and self._t[k] then
      local data, err = self._dao:find_one { [k] = self._t[k] }
      if data ~= nil and data.id ~= self._t.id then
        return 0, k.." with value ".."\""..self._t[k].."\"".." already exists"
      elseif err then
        return 0, err
      end
    end
  end

  return self._dao:update_by_id(self._t)
end

-- Deletes a model from database
-- @return {boolean} Success of the deletion
function BaseModel:delete()
  return self._dao:delete_by_id(self._t.id)
end

function BaseModel._find_one(args, dao)
  local data, err = dao:find_one(args)
  return data, err
end

function BaseModel._find(args, page, size, dao)
  local data, total, err = dao:find(args, page, size)
  return data, total, err
end

return BaseModel
