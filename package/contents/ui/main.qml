import QtQuick 2.15
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: root

    // Configuration
    property string apiKey: Plasmoid.configuration.apiKey || ""

    // Data
    property real totalCredits: 0.0
    property real totalUsage: 0.0
    property real remainingBalance: 0.0
    property bool isLoading: false
    property string lastError: ""
    property string lastUpdated: ""

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation

    // Separate resizable model-browser window (opened from the popup)
    ModelBrowserWindow { id: modelBrowser }

    // Poll timer
    Timer {
        id: pollTimer
        interval: 300000 // 5 minutes
        repeat: true
        running: apiKey.length > 0
        onTriggered: fetchBalance()
        Component.onCompleted: {
            if (apiKey.length > 0) {
                fetchBalance()
            }
        }
    }

    // Watch for API key changes
    onApiKeyChanged: {
        if (apiKey.length > 0) {
            fetchBalance()
            pollTimer.restart()
        } else {
            pollTimer.stop()
            totalCredits = 0.0
            totalUsage = 0.0
            remainingBalance = 0.0
            lastError = ""
        }
    }

    function fetchBalance() {
        if (apiKey.length === 0) return

        isLoading = true
        lastError = ""

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://openrouter.ai/api/v1/credits")
        xhr.setRequestHeader("Authorization", "Bearer " + apiKey)
        xhr.setRequestHeader("Content-Type", "application/json")

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isLoading = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        var data = response.data || {}
                        totalCredits = data.total_credits || 0.0
                        totalUsage = data.total_usage || 0.0
                        remainingBalance = totalCredits - totalUsage
                        lastUpdated = new Date().toLocaleTimeString()
                        lastError = ""
                    } catch (e) {
                        lastError = "Parse error: " + e.message
                    }
                } else {
                    lastError = "HTTP " + xhr.status
                }
            }
        }

        xhr.onerror = function () {
            isLoading = false
            lastError = "Network error"
        }

        xhr.send()
    }

    function formatBalance(value) {
        return "$" + value.toFixed(2)
    }

    function balanceColor() {
        if (lastError.length > 0) return PlasmaCore.Theme.disabledTextColor
        if (remainingBalance > 10.0) return PlasmaCore.Theme.positiveTextColor
        if (remainingBalance > 2.0) return PlasmaCore.Theme.neutralTextColor
        return PlasmaCore.Theme.negativeTextColor
    }

    // Compact representation (panel bar)
    Plasmoid.compactRepresentation: Item {
        Layout.minimumWidth: row.implicitWidth
        Layout.minimumHeight: row.implicitHeight

        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: PlasmaCore.Units.smallSpacing

            Item {
                width: PlasmaCore.Units.iconSizes.small
                height: PlasmaCore.Units.iconSizes.small
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: orLogo
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../images/openrouter.svg")
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: false
                }

                ColorOverlay {
                    anchors.fill: orLogo
                    source: orLogo
                    color: balanceColor()
                }
            }

            Text {
                text: {
                    if (apiKey.length === 0) return "---"
                    if (isLoading) return "..."
                    if (lastError.length > 0) return "ERR"
                    return formatBalance(remainingBalance)
                }
                color: balanceColor()
                font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Full representation (popup)
    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 280
        Layout.minimumHeight: 200
        Layout.preferredWidth: 320
        Layout.preferredHeight: 240

        PlasmaComponents.Label {
            text: "OpenRouter Credits"
            font.bold: true
            font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 1.2
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: PlasmaCore.Units.smallSpacing
        }

        Item { Layout.preferredHeight: PlasmaCore.Units.smallSpacing }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            PlasmaComponents.Label {
                text: "Remaining Balance"
                font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 0.9
                opacity: 0.7
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents.Label {
                text: {
                    if (apiKey.length === 0) return "---"
                    if (isLoading) return "Loading..."
                    if (lastError.length > 0) return "Error"
                    return formatBalance(remainingBalance)
                }
                color: balanceColor()
                font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 2.0
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: PlasmaCore.Units.largeSpacing
            Layout.rightMargin: PlasmaCore.Units.largeSpacing
            Layout.topMargin: PlasmaCore.Units.smallSpacing
            Layout.bottomMargin: PlasmaCore.Units.smallSpacing
            color: PlasmaCore.Theme.textColor
            opacity: 0.2
        }

        GridLayout {
            columns: 2
            columnSpacing: PlasmaCore.Units.largeSpacing
            rowSpacing: PlasmaCore.Units.smallSpacing
            Layout.alignment: Qt.AlignHCenter

            PlasmaComponents.Label {
                text: "Lifetime Credits:"
                opacity: 0.7
            }
            PlasmaComponents.Label {
                text: apiKey.length > 0 ? formatBalance(totalCredits) : "---"
                font.weight: Font.DemiBold
            }

            PlasmaComponents.Label {
                text: "Lifetime Usage:"
                opacity: 0.7
            }
            PlasmaComponents.Label {
                text: apiKey.length > 0 ? formatBalance(totalUsage) : "---"
                font.weight: Font.DemiBold
            }

            PlasmaComponents.Label {
                text: "Last Updated:"
                opacity: 0.7
            }
            PlasmaComponents.Label {
                text: lastUpdated.length > 0 ? lastUpdated : "Never"
                font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 0.85
            }
        }

        PlasmaComponents.Label {
            visible: lastError.length > 0
            text: lastError
            color: PlasmaCore.Theme.negativeTextColor
            font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 0.8
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.leftMargin: PlasmaCore.Units.largeSpacing
            Layout.rightMargin: PlasmaCore.Units.largeSpacing
        }

        PlasmaComponents.Label {
            visible: apiKey.length === 0
            text: "Right-click widget > Configure to set your API key"
            color: PlasmaCore.Theme.disabledTextColor
            font.italic: true
            font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 0.85
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            Layout.leftMargin: PlasmaCore.Units.largeSpacing
            Layout.rightMargin: PlasmaCore.Units.largeSpacing
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: PlasmaCore.Units.smallSpacing

            PlasmaComponents.Button {
                text: "Refresh"
                icon.name: "view-refresh"
                enabled: apiKey.length > 0 && !isLoading
                onClicked: fetchBalance()
            }

            PlasmaComponents.Button {
                text: "Browse Models…"
                icon.name: "view-list-details"
                onClicked: modelBrowser.open()
            }
        }

        Item { Layout.fillHeight: true }
    }
}
