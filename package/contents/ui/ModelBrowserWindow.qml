import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Window {
    id: win

    title: "OpenRouter Models"
    width: 760
    height: 520
    minimumWidth: 560
    minimumHeight: 320
    color: PlasmaCore.Theme.backgroundColor
    visible: false

    // --- state ---
    property var allModels: []
    property var viewRows: []
    property bool loading: false
    property string errorText: ""

    // sortable dimensions (official API fields only)
    readonly property var dimKeys: ["name", "context", "prompt", "completion"]
    readonly property var dimLabels: ["Name", "Context", "Prompt $/M", "Completion $/M"]
    // tier 2 & 3 allow an explicit "none"
    readonly property var dimLabelsOpt: ["(none)", "Name", "Context", "Prompt $/M", "Completion $/M"]

    // column widths for numeric columns; Name fills the rest
    readonly property int wCtx: 110
    readonly property int wPrompt: 120
    readonly property int wComp: 140

    function open() {
        show()
        raise()
        requestActivate()
        if (allModels.length === 0 && !loading)
            fetchModels()
    }

    function fetchModels() {
        loading = true
        errorText = ""
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://openrouter.ai/api/v1/models")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText)
                        allModels = d.data || []
                    } catch (e) {
                        errorText = "Parse error: " + e.message
                        return
                    }
                    applyView()
                } else {
                    errorText = "HTTP " + xhr.status
                }
            }
        }
        xhr.onerror = function () {
            loading = false
            errorText = "Network error"
        }
        xhr.send()
    }

    function dimValue(m, dim) {
        if (dim === "name") return ((m.name || m.id || "")).toLowerCase()
        if (dim === "context") return m.context_length || 0
        if (dim === "prompt") return parseFloat((m.pricing && m.pricing.prompt) || 0)
        if (dim === "completion") return parseFloat((m.pricing && m.pricing.completion) || 0)
        return 0
    }

    function cmp(a, b, tiers) {
        for (var i = 0; i < tiers.length; i++) {
            var t = tiers[i]
            if (t.dim === "none") continue
            var va = dimValue(a, t.dim)
            var vb = dimValue(b, t.dim)
            var c
            if (typeof va === "string") c = va.localeCompare(vb)
            else c = (va < vb) ? -1 : (va > vb) ? 1 : 0
            if (c !== 0) return t.dir === "desc" ? -c : c
        }
        return 0
    }

    function applyView() {
        var q = searchField.text.trim().toLowerCase()
        var rows = allModels.filter(function (m) {
            if (!q) return true
            return ((m.name || "") + " " + (m.id || "")).toLowerCase().indexOf(q) !== -1
        })
        var tiers = [
            { dim: dimKeys[dim1.currentIndex], dir: dim1.desc ? "desc" : "asc" },
            { dim: dim2.currentIndex === 0 ? "none" : dimKeys[dim2.currentIndex - 1], dir: dim2.desc ? "desc" : "asc" },
            { dim: dim3.currentIndex === 0 ? "none" : dimKeys[dim3.currentIndex - 1], dir: dim3.desc ? "desc" : "asc" }
        ]
        rows.sort(function (a, b) { return cmp(a, b, tiers) })
        viewRows = rows
    }

    function fmtCtx(v) {
        if (!v) return "—"
        if (v >= 1000000) {
            var m = Math.round(v / 100000) / 10   // millions, 1 decimal
            return (m % 1 === 0 ? m.toFixed(0) : m.toFixed(1)) + "M"
        }
        if (v >= 1000) return (v / 1000).toFixed(0) + "K"
        return "" + v
    }

    function fmtPrice(s) {
        var p = parseFloat(s || 0)
        if (p < 0) return "—"          // -1 sentinel = variable/router pricing
        if (p === 0) return "Free"
        return "$" + (p * 1000000).toFixed(2)
    }

    // Qt5 has no direct QML clipboard API — copy via a hidden TextEdit.
    TextEdit { id: clipHelper; visible: false }

    function copyToClipboard(text) {
        if (!text) return
        clipHelper.text = text
        clipHelper.selectAll()
        clipHelper.copy()
        clipHelper.deselect()
        clipHelper.text = ""
    }

    function showToast(msg) {
        toast.message = msg
        toast.opacity = 1.0
        toastTimer.restart()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: PlasmaCore.Units.largeSpacing
        spacing: PlasmaCore.Units.smallSpacing

        // --- toolbar: search + refresh ---
        RowLayout {
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents.TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search models by name or id…"
                onTextChanged: applyView()
            }

            PlasmaComponents.Button {
                text: "Refresh"
                icon.name: "view-refresh"
                enabled: !win.loading
                onClicked: win.fetchModels()
            }
        }

        // --- sort controls: fixed 3 tiers ---
        RowLayout {
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents.Label { text: "Sort by:"; opacity: 0.8 }

            PlasmaComponents.ComboBox {
                id: dim1
                property bool desc: true
                model: win.dimLabels
                currentIndex: 1 // Context
                onCurrentIndexChanged: applyView()
            }
            PlasmaComponents.Button {
                text: dim1.desc ? "▼" : "▲"
                implicitWidth: PlasmaCore.Units.gridUnit * 1.6
                onClicked: { dim1.desc = !dim1.desc; applyView() }
            }

            PlasmaComponents.Label { text: "then"; opacity: 0.6 }

            PlasmaComponents.ComboBox {
                id: dim2
                property bool desc: true
                model: win.dimLabelsOpt
                currentIndex: 0 // none
                onCurrentIndexChanged: applyView()
            }
            PlasmaComponents.Button {
                text: dim2.desc ? "▼" : "▲"
                implicitWidth: PlasmaCore.Units.gridUnit * 1.6
                enabled: dim2.currentIndex !== 0
                onClicked: { dim2.desc = !dim2.desc; applyView() }
            }

            PlasmaComponents.Label { text: "then"; opacity: 0.6 }

            PlasmaComponents.ComboBox {
                id: dim3
                property bool desc: true
                model: win.dimLabelsOpt
                currentIndex: 0 // none
                onCurrentIndexChanged: applyView()
            }
            PlasmaComponents.Button {
                text: dim3.desc ? "▼" : "▲"
                implicitWidth: PlasmaCore.Units.gridUnit * 1.6
                enabled: dim3.currentIndex !== 0
                onClicked: { dim3.desc = !dim3.desc; applyView() }
            }

            Item { Layout.fillWidth: true }
        }

        // --- header row ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hdr.implicitHeight + PlasmaCore.Units.smallSpacing
            color: PlasmaCore.Theme.textColor
            opacity: 0.07
            radius: 3

            RowLayout {
                id: hdr
                anchors.fill: parent
                anchors.leftMargin: PlasmaCore.Units.smallSpacing
                anchors.rightMargin: PlasmaCore.Units.smallSpacing
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaComponents.Label { text: "Model"; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                PlasmaComponents.Label { text: "Context"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: win.wCtx }
                PlasmaComponents.Label { text: "Prompt $/M"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: win.wPrompt }
                PlasmaComponents.Label { text: "Completion $/M"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: win.wComp }
            }
        }

        // --- table body ---
        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: list
                model: win.viewRows
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: list.width
                    height: cells.implicitHeight + PlasmaCore.Units.smallSpacing
                    color: rowHover.hovered ? Qt.rgba(PlasmaCore.Theme.highlightColor.r,
                                                       PlasmaCore.Theme.highlightColor.g,
                                                       PlasmaCore.Theme.highlightColor.b, 0.18)
                                            : (index % 2 ? Qt.rgba(PlasmaCore.Theme.textColor.r,
                                                                   PlasmaCore.Theme.textColor.g,
                                                                   PlasmaCore.Theme.textColor.b, 0.04)
                                                         : "transparent")

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            win.copyToClipboard(modelData.id || "")
                            win.showToast("✓ Copied  " + (modelData.id || ""))
                        }
                    }

                    RowLayout {
                        id: cells
                        anchors.fill: parent
                        anchors.leftMargin: PlasmaCore.Units.smallSpacing
                        anchors.rightMargin: PlasmaCore.Units.smallSpacing
                        spacing: PlasmaCore.Units.smallSpacing

                        PlasmaComponents.Label {
                            text: modelData.name || modelData.id || ""
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            QQC2.ToolTip.text: modelData.id || ""
                            QQC2.ToolTip.visible: rowHover.hovered && (modelData.id || "") !== ""
                            QQC2.ToolTip.delay: 600
                        }
                        PlasmaComponents.Label {
                            text: win.fmtCtx(modelData.context_length)
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: win.wCtx
                            opacity: 0.9
                        }
                        PlasmaComponents.Label {
                            text: win.fmtPrice(modelData.pricing && modelData.pricing.prompt)
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: win.wPrompt
                            opacity: 0.9
                        }
                        PlasmaComponents.Label {
                            text: win.fmtPrice(modelData.pricing && modelData.pricing.completion)
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: win.wComp
                            opacity: 0.9
                        }
                    }
                }
            }
        }

        // --- status bar ---
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: {
                    if (win.loading) return "Loading models…"
                    if (win.errorText.length > 0) return "Error: " + win.errorText
                    return win.viewRows.length + " of " + win.allModels.length + " models"
                }
                color: win.errorText.length > 0 ? PlasmaCore.Theme.negativeTextColor : PlasmaCore.Theme.textColor
                opacity: 0.8
                font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 0.9
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: "Data: openrouter.ai/api/v1/models"
                opacity: 0.4
                font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 0.8
            }
        }
    }

    // --- transient "copied to clipboard" toast ---
    Rectangle {
        id: toast
        property string message: ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: PlasmaCore.Units.gridUnit * 2.5
        z: 100
        radius: height / 5
        color: Qt.rgba(0, 0, 0, 0.85)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        opacity: 0
        visible: opacity > 0
        width: toastLabel.implicitWidth + PlasmaCore.Units.largeSpacing * 2
        height: toastLabel.implicitHeight + PlasmaCore.Units.smallSpacing * 2

        Behavior on opacity { NumberAnimation { duration: 150 } }

        PlasmaComponents.Label {
            id: toastLabel
            anchors.centerIn: parent
            text: toast.message
            color: "white"
        }

        Timer { id: toastTimer; interval: 1600; onTriggered: toast.opacity = 0 }
    }
}
