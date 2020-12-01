local imguiStub = require("imgui_stub")
local vhfHelperStub = require("vhf_helper")
local AtcStringInlineButtonBlob = require("vatsimbrief-helper.components.atc_inline_button_blob")

TestAtcButtonBlob = {}

function TestAtcButtonBlob:testAtcStringIsRenderedCorrectly()
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
