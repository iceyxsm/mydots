import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Simple fullscreen SDDM theme
Rectangle {
    id: root
    anchors.fill: parent
    color: "black"

    // Background image - STRETCH to fill entire screen
    Image {
        id: background
        source: config.background || "background.jpg"
        anchors.fill: parent
        fillMode: Image.Stretch  // This fills the entire screen!
        smooth: true
    }

    // Login form container on the left
    Rectangle {
        id: loginForm
        width: 400
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "transparent"

        // Semi-transparent dark overlay for readability
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.4
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 20

            // Clock
            Text {
                id: clockText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(new Date(), "HH:mm")
                color: "white"
                font.pixelSize: 64
                font.bold: true

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
                }
            }

            // Date
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(new Date(), "dddd d MMMM")
                color: "white"
                font.pixelSize: 20
            }

            // Spacer
            Item { Layout.preferredHeight: 40 }

            // Username field
            TextField {
                id: usernameField
                Layout.fillWidth: true
                placeholderText: "Username"
                text: userModel.lastUser || ""
                font.pixelSize: 16

                background: Rectangle {
                    color: "#333333"
                    radius: 5
                    border.color: usernameField.focus ? "#5e81ac" : "transparent"
                    border.width: 2
                }
                color: "white"

                onAccepted: passwordField.focus = true
            }

            // Password field
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                font.pixelSize: 16

                background: Rectangle {
                    color: "#333333"
                    radius: 5
                    border.color: passwordField.focus ? "#5e81ac" : "transparent"
                    border.width: 2
                }
                color: "white"

                onAccepted: sddm.login(usernameField.text, passwordField.text, sessionModel.lastIndex)
            }

            // Login button
            Button {
                Layout.fillWidth: true
                text: "Login"

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }

                background: Rectangle {
                    color: parent.pressed ? "#4c566a" : "#5e81ac"
                    radius: 5
                }

                onClicked: sddm.login(usernameField.text, passwordField.text, sessionModel.lastIndex)
            }

            // Session selector
            ComboBox {
                id: sessionSelector
                Layout.fillWidth: true
                model: sessionModel
                currentIndex: sessionModel.lastIndex
                textRole: "name"

                background: Rectangle {
                    color: "#333333"
                    radius: 5
                }
                contentItem: Text {
                    text: sessionSelector.displayText
                    color: "white"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Power buttons
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Button {
                    text: "Shutdown"
                    onClicked: sddm.powerOff()
                    background: Rectangle { color: "#bf616a"; radius: 5 }
                    contentItem: Text { text: parent.text; color: "white" }
                }

                Button {
                    text: "Reboot"
                    onClicked: sddm.reboot()
                    background: Rectangle { color: "#d08770"; radius: 5 }
                    contentItem: Text { text: parent.text; color: "white" }
                }
            }
        }
    }
}
