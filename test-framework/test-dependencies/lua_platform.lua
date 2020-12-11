--[[

MIT License

Copyright (c) 2020 VerticalLongboard

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]
if (_VERSION == "Lua 5.4") then
    LOAD_LUA_STRING = function(str)
        return load(str)
    end
    TABLE_INSERT_TWO_ARGUMENTS = function(t, v)
        table.insert(t, #t + 1, v)
    end
elseif (_VERSION == "Lua 5.1") then
    LOAD_LUA_STRING = function(str)
        return loadstring(str)
    end
    TABLE_INSERT_TWO_ARGUMENTS = function(t, v)
        table.insert(t, v)
    end
else
    LOAD_LUA_STRING = function(str)
        return loadstring(str)
    end
    TABLE_INSERT_TWO_ARGUMENTS = function(t, v)
        table.insert(t, v)
    end
end

local M = {}

M._nowTime = 0
M.Time = {
    advanceNow = function(byHowManySeconds)
        M._nowTime = M._nowTime + byHowManySeconds
    end,
    now = function()
        return M._nowTime
    end
}

M.IO = {
    Constants = {
        Modes = {
            Overwrite = "w",
            Read = "r",
            Binary = "b"
        }
    }
}

-- TRACK_ISSUE(
--     "Boilerplate/Tech Debt",
--     "LuaPlatform.IO does not support object handles, only objects.",
--     "Ignore that for now."
-- )
-- local IoObject
-- do
--     IoObject = {}
--     function IoObject:new(newContent)
--         local newInstanceWithState = {
--             content = newContent
--         }
--         setmetatable(newInstanceWithState, self)
--         self.__index = self
--         return newInstanceWithState
--     end

--     function IoObject:readAll()
--         local contentCopy = (self.content .. "x"):sub(1, -2)
--         return contentCopy
--     end

--     function IoObject:write(additionalContent)
--         self.content = self.content .. additionalContent
--     end

--     function IoObject:close()
--     end

--     function IoObject:_overrideContent(newContent)
--         self.content = newContent
--     end

--     function IoObject:_getContent()
--         return self.content
--     end
-- end

-- TRACK_ISSUE("Boilerplate/Tech Debt", "LuaPlatform.IO is not yet implemented, but wasting space.", "But ...")
-- M.IO.overrideObjectContent = function(ioPath, newContent)
--     if (M.IO.ioObjects[ioPath] == nil) then
--         M.IO.ioObjects[ioPath]:_overrideContent(newContent)
--         return
--     end

--     M.IO.ioObjects[ioPath] = IoObject:new(newContent)
-- end

-- M.IO.getObjectContent = function(ioPath)
--     if (M.IO.ioObjects[ioPath] == nil) then
--         return nil
--     end
--     return M.IO.ioObjects[ioPath]:_getContent()
-- end

M.IO.open = function(ioPath, mode)
    assert(ioPath)
    -- if (mode == M.IO.Constants.Modes.Overwrite) then
    --     M.IO.overrideObjectContent(ioPath, nil)
    -- elseif (mode == M.IO.Constants.Modes.Read) then
    --     if (M.IO.ioObjects[ioPath] == nil) then
    --         return nil
    --     end
    -- end

    return io.open(ioPath, mode)
    -- return M.IO.ioObjects[ioPath]
end

M.IO.close = function(ioObject)
    assert(ioObject)
    io.close(ioObject)
    -- ioObject:close()
end

return M
