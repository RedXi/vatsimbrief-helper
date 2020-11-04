TestInlineButtonBlob = {}
imguiStub = require("imgui_stub")
vhfHelperStub = require("vhf_helper")

function TestInlineButtonBlob:testRendersAllWidgetsInOrderWithProperNewlines()
    local someText = "Here it is"
    local someOtherText = "And here too"
    local buttonTitle = "Press this"
    local buttonTitle2 = "Press!"
    local seriousText = "Saw Log Without Paws"

    local blob = InlineButtonImguiBlob:new()
    blob:addTextWithoutNewline(someText)
    blob:addNewline()
    blob:addNewline()
    blob:addTextWithoutNewline(someOtherText)
    blob:addNewline()
    blob:addDefaultButton(buttonTitle)
    blob:addTextWithoutNewline(seriousText)
    blob:addDefaultButton(buttonTitle2)

    imguiStub:startFrame()
    blob:renderToCanvas()
    imguiStub:endFrame()

    local i = 0

    local sameLineTooEarlyIndex = 0

    sameLineTooEarlyIndex = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, someText)

    luaUnit.assertIsTrue(sameLineTooEarlyIndex > i)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, someOtherText)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SmallButton)
    luaUnit.assertEquals(imguiStub:matchButtonTitle(imguiStub:getCommandFromList(i).title), buttonTitle)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, seriousText)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SmallButton)
    luaUnit.assertEquals(imguiStub:matchButtonTitle(imguiStub:getCommandFromList(i).title), buttonTitle2)
end

function TestInlineButtonBlob:testAtcStringIsRenderedCorrectly()
    local fullAtcString =
        "EEEE: ATIS=122.800 H=23 TWR=119.400\n" .. "      APP=134.670 OBS=199.998\n" .. "AAAA: -\n" .. "BBBB: ATIS="

    vhfHelperStub.frequencies.tunedIn = "119.400"
    vhfHelperStub.frequencies.entered = "134.670"

    local atcBlob = AtcStringInlineButtonBlob:new()
    atcBlob:build(fullAtcString)

    imguiStub:startFrame()
    atcBlob:renderToCanvas()
    imguiStub:endFrame()

    local i = 0
    local sameLineTooEarlyIndex = 0

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, "EEEE: ATIS=")

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SmallButton)
    luaUnit.assertEquals(imguiStub:matchButtonTitle(imguiStub:getCommandFromList(i).title), "122.800")

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, " H=")

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, "23 TWR=")

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SmallButton)
    luaUnit.assertEquals(imguiStub:matchButtonTitle(imguiStub:getCommandFromList(i).title), "119.400")

    sameLineTooEarlyIndex = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, "      APP=")

    luaUnit.assertIsTrue(sameLineTooEarlyIndex > i)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SmallButton)
    luaUnit.assertEquals(imguiStub:matchButtonTitle(imguiStub:getCommandFromList(i).title), "134.670")

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, " OBS=")

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    sameLineTooEarlyIndex = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, "199.998")

    luaUnit.assertIsNil(sameLineTooEarlyIndex)

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, "AAAA: -")

    i = imguiStub:findCommandInList(i + 1, imguiStub.Constants.TextUnformatted)
    luaUnit.assertEquals(imguiStub:getCommandFromList(i).textString, "BBBB: ATIS=")
end
