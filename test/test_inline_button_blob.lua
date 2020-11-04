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

    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, someText)
    luaUnit.assertIsTrue(sameLineTooEarlyIndex > i)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, someOtherText)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, buttonTitle)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, seriousText)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, buttonTitle2)
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

    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "EEEE: ATIS=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, "122.800")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, " H=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "23 TWR=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, "119.400")
    sameLineTooEarlyIndex = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "      APP=")
    luaUnit.assertIsTrue(sameLineTooEarlyIndex > i)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, "134.670")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, " OBS=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "199.998")
    sameLineTooEarlyIndex = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    luaUnit.assertIsNil(sameLineTooEarlyIndex)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "AAAA: -")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "BBBB: ATIS=")
end
