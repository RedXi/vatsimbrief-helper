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
luaUnit = require("luaUnit")

imgui = {
    constant = {
        StyleVar = {
            ItemSpacing
        },
        Col = {
            Text,
            Button
        }
    },
    SetWindowFontScale = function(value)
    end,
    PushStyleVar_2 = function(value, value2, value3)
        luaUnit.assertNotNil(value2)
        luaUnit.assertNotNil(value3)
        imgui.styleVarStackSize = imgui.styleVarStackSize + 1
    end,
    PopStyleVar = function()
        imgui.styleVarStackSize = imgui.styleVarStackSize - 1
    end,
    TextUnformatted = function(value)
        imgui:checkStringForWatchStrings(value)
    end,
    PushStyleColor = function(const, value)
        luaUnit.assertNotNil(value)
        imgui.styleColorStackSize = imgui.styleColorStackSize + 1
    end,
    SameLine = function()
    end,
    PopStyleColor = function()
        imgui.styleColorStackSize = imgui.styleColorStackSize - 1
    end,
    Dummy = function(value1, value2)
    end,
    Button = function(value)
        imgui:checkStringForWatchStrings(value)
        if (value == imgui.pressButtonWithThisTitleProgrammatically) then
            imgui.buttonPressed = true
            return true
        end

        return false
    end
}

function imgui:checkStringForWatchStrings(value)
    if (imgui.watchString ~= nil and value:find(imgui.watchString)) then
        imgui.watchStringFound = true
    end

    if (value == imgui.exactMatchString) then
        imgui.exactMatchFound = true
    end
end

function imgui:startFrame()
    self.watchStringFound = false
    self.exactMatchFound = false
    self.buttonPressed = false
    self.styleVarStackSize = 0
    self.styleColorStackSize = 0
end

function imgui:pressButtonProgrammaticallyOnce(buttonTitle)
    self.pressButtonWithThisTitleProgrammatically = buttonTitle
end

function imgui:keepALookOutForString(someString)
    self.watchString = someString
end

function imgui:keepALookOutForExactMatch(someString)
    self.exactMatchString = someString
end

function imgui:endFrame()
    self.pressButtonWithThisTitleProgrammatically = nil

    luaUnit.assertEquals(self.styleVarStackSize, 0)
    luaUnit.assertEquals(self.styleColorStackSize, 0)
end

function imgui:wasWatchStringFound()
    return self.watchStringFound
end

function imgui:wasExactMatchFound()
    return self.exactMatchFound
end

function imgui:wasButtonPressed()
    return self.buttonPressed
end

return imgui
