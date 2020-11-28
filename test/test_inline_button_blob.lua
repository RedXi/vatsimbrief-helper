imguiStub = require("imgui_stub")
vhfHelperStub = require("vhf_helper")

TestInlineButtonBlob = {}

TRACK_ISSUE(
    "Tech Debt",
    "This is a separate component already in VR Radio Helper. Move it to script_modules and remove it from main script. Makes updating and testing easier."
)

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

function TestInlineButtonBlob:testDefaultCallbackIsCalled()
    local blob = InlineButtonImguiBlob:new()

    local called = false
    blob:setDefaultButtonCallbackFunction(
        function(buttonTitle)
            called = true
        end
    )
    local buttonTitle = "bla"
    blob:addDefaultButton(buttonTitle)

    imguiStub:pressButtonProgrammaticallyOnce(buttonTitle)
    imguiStub:startFrame()
    blob:renderToCanvas()
    imguiStub:endFrame()
    luaUnit.assertIsTrue(called)
end

function TestInlineButtonBlob:testAtcStringIsRenderedCorrectly()
    local fullAtcData = {
        {"EEEE", {{"ATIS", "122.800"}, {"TWR", "119.400"}, {"APP", "134.670"}, {"OBS", "199.998"}}},
        {"AAAA", {}}
    }

    vhfHelperStub.frequencies.tunedInCom1 = "119.400"
    vhfHelperStub.frequencies.tunedInCom2 = nil
    vhfHelperStub.frequencies.entered = "134.670"

    local atcBlob = AtcStringInlineButtonBlob:new()
    atcBlob:build(fullAtcData, true, 30)

    imguiStub:startFrame()
    atcBlob:renderToCanvas()
    imguiStub:endFrame()

    local i = 0
    local sameLineTooEarlyIndex = 0

    TRACK_ISSUE(
        "Tech Debt",
        MULTILINE_TEXT(
            "Improve testing the blob with an iterator",
            'assertTrue(imguiStub.nextElement(imguiStub.Constants.TextUnformatted, "199.998"))',
            "assertTrue(imguiStub.nextElement(imguiStub.Constants.SameLine))"
        )
    )
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "EEEE: ")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "ATIS=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, "122.800")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, " ")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "TWR=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.PushStyleColor)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, "119.400")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.PopStyleColor)
    sameLineTooEarlyIndex = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "      ")
    luaUnit.assertIsTrue(sameLineTooEarlyIndex > i)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "APP=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.PushStyleColor)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, "134.670")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.PopStyleColor)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, " ")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "OBS=")
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "199.998")
    sameLineTooEarlyIndex = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "AAAA: ")
    luaUnit.assertIsTrue(sameLineTooEarlyIndex > i)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, "-")
end
