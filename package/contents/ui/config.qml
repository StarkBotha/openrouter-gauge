import QtQuick 2.15
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

ColumnLayout {
    id: configPage

    property alias cfg_apiKey: apiKeyField.text

    PlasmaComponents.Label {
        text: "API Key"
        font.bold: true
    }

    PlasmaComponents.TextField {
        id: apiKeyField
        placeholderText: "sk-or-v1-..."
        echoMode: TextInput.Password
        Layout.fillWidth: true
    }

    PlasmaComponents.Label {
        text: "Get your key from openrouter.ai/settings/keys"
        opacity: 0.6
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
