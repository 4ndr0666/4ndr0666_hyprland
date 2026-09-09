import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0 as SDDM

Rectangle {
    id: background

    // #15FFF is not a valid Qt/QML hex colour; #15FFFF is the nearest
    // six-digit interpretation and remains a deterministic, valid colour.
    property color electricCyan: "#15FFFF"
    property color electricCyanSoft: "#7AFFFF"
    property color matrixBase: "#0A131A"
    property color glassPanel: "#B80A131A"
    property color glassField: "#990A131A"
    property color destructive: "#FF0055"
    property color absoluteLight: "#FFFFFF"

    color: "#050A0F"

    function authenticateUser() {
        sddm.login(usernameField.text, passwordField.text, sessionSelector.currentIndex);
    }

    function showLoginError() {
        loginError.visible = true;
        errorTimer.restart();
        passwordField.forceActiveFocus();
        passwordField.selectAll();
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            showLoginError();
        }

        function onLoginSucceeded() {
            loginError.visible = false;
        }
    }

    Timer {
        id: errorTimer
        interval: 2200
        repeat: false
        onTriggered: loginError.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: "#0A131A"
        opacity: 0.48
    }

    // Subtle electric grid. It gives the glass surface structure without
    // relying on compositor-specific blur effects.
    Canvas {
        anchors.fill: parent
        opacity: 0.11

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = background.electricCyan;
            ctx.lineWidth = 1;

            var step = 48;
            for (var x = 0; x <= width; x += step) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }
            for (var y = 0; y <= height; y += step) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
        }
    }

    Rectangle {
        id: loginContainer
        width: Math.min(parent.width * 0.78, 760)
        height: 470
        anchors.centerIn: parent
        color: background.glassPanel
        border.color: background.electricCyan
        border.width: 1
        radius: 4

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            color: "transparent"
            border.color: background.electricCyan
            border.width: 1
            radius: 2
            opacity: 0.22
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 2
            color: background.electricCyan
            opacity: 0.92
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 42
            spacing: 0

            Label {
                text: "TERMINAL // AUTHENTICATION"
                color: background.electricCyanSoft
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                text: "4NDR0666OS"
                color: background.electricCyan
                font.family: "Orbitron"
                font.pixelSize: 30
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                height: 1
                color: background.electricCyan
                opacity: 0.34
            }

            Label {
                text: "SECURE SESSION INITIALIZATION"
                color: "#8FBFC5"
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 520
                Layout.fillWidth: true
                Layout.topMargin: 32
                spacing: 14

                Label {
                    text: "USERNAME"
                    color: background.electricCyanSoft
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    font.bold: true
                }

                TextField {
                    id: usernameField
                    Layout.fillWidth: true
                    implicitHeight: 48
                    color: background.electricCyanSoft
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    placeholderText: "enter username"
                    placeholderTextColor: "#53757A"
                    selectByMouse: true
                    focus: false

                    background: Rectangle {
                        color: background.glassField
                        border.color: usernameField.activeFocus ? background.electricCyan : "#45646A"
                        border.width: 1
                        radius: 0
                    }
                }

                Label {
                    text: "PASSWORD"
                    color: background.electricCyanSoft
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.topMargin: 2
                }

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    implicitHeight: 48
                    color: background.electricCyanSoft
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    placeholderText: "enter password"
                    placeholderTextColor: "#53757A"
                    echoMode: TextInput.Password
                    selectByMouse: true
                    focus: true

                    background: Rectangle {
                        color: background.glassField
                        border.color: passwordField.activeFocus ? background.electricCyan : "#45646A"
                        border.width: 1
                        radius: 0
                    }

                    Keys.onReturnPressed: authenticateUser()
                    Keys.onEnterPressed: authenticateUser()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Layout.topMargin: 4

                    Label {
                        text: "SESSION"
                        color: background.electricCyanSoft
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    ComboBox {
                        id: sessionSelector
                        Layout.fillWidth: true
                        implicitHeight: 42
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12

                        function readSessionNames() {
                            var file = new XMLHttpRequest();
                            file.open("GET", "sessions.txt", false);
                            file.send(null);
                            var contents = file.responseText.trim();
                            return contents.length > 0 ? contents.split(" ") : [];
                        }

                        model: readSessionNames()
                        currentIndex: count > 0 ? 0 : -1

                        background: Rectangle {
                            color: background.glassField
                            border.color: sessionSelector.activeFocus ? background.electricCyan : "#45646A"
                            border.width: 1
                            radius: 0
                        }

                        contentItem: Text {
                            text: sessionSelector.displayText
                            color: background.electricCyanSoft
                            font: sessionSelector.font
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 12
                            rightPadding: 32
                            elide: Text.ElideRight
                        }

                        delegate: ItemDelegate {
                            width: sessionSelector.width
                            height: 38
                            highlighted: sessionSelector.highlightedIndex === index

                            contentItem: Text {
                                text: modelData
                                color: highlighted ? background.absoluteLight : background.electricCyanSoft
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                            }

                            background: Rectangle {
                                color: highlighted ? "#3315FFFF" : "#D90A131A"
                            }
                        }
                    }
                }
            }

            Button {
                id: loginButton
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 26
                implicitWidth: 190
                implicitHeight: 46
                text: "[ AUTHENTICATE ]"
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                font.bold: true

                onClicked: authenticateUser()

                contentItem: Text {
                    text: loginButton.text
                    color: loginButton.pressed ? background.absoluteLight :
                           (loginButton.hovered || loginButton.activeFocus ? background.electricCyanSoft : background.electricCyan)
                    font: loginButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: loginButton.pressed ? "#4D15FFFF" :
                           (loginButton.hovered || loginButton.activeFocus ? "#3315FFFF" : background.glassField)
                    border.color: loginButton.hovered || loginButton.activeFocus ? background.electricCyan : "#6699A6"
                    border.width: 1
                    radius: 0
                }
            }

            Label {
                id: loginError
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                visible: false
                text: "AUTHENTICATION FAILED // RETRY"
                color: background.absoluteLight
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.bold: true
                padding: 8

                background: Rectangle {
                    color: "#B3FF0055"
                    border.color: background.destructive
                    border.width: 1
                    radius: 0
                }
            }
        }

        Label {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 18
            anchors.bottomMargin: 14
            text: "GUP // SDDM"
            color: background.electricCyan
            opacity: 0.48
            font.family: "JetBrains Mono"
            font.pixelSize: 9
        }

        Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 18
            anchors.bottomMargin: 14
            text: "SECURE BOOT SURFACE"
            color: background.electricCyan
            opacity: 0.48
            font.family: "JetBrains Mono"
            font.pixelSize: 9
        }
    }
}
