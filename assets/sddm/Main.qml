import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0 as SDDM

Rectangle {
    id: background
    color: "#181724"
    function authenticateUser(username, password, sessionIndex) {
	 sddm.login(username,password,sessionIndex);
    }
    
Connections {
    target: sddm

     function loginFailed() {
	    error.color = "white";
	    error.background.color = "red";
	    sleep(2000);
	    error.color = "#181724";
	    error.background.color = "#181724";
	    passwordfield.focus = true;
    }

    function loginSucceeded() {
    }
}

    Rectangle {
        id: logincontainer
        color: "#181724"
        width: 800
        height: 400
        border.color: "#ffffff"
        border.width: 2
        radius: 10

        anchors.centerIn: parent
        ColumnLayout {
	    id: inputFields
            anchors.centerIn: parent 
            spacing: 10


            TextField {
                id: usernamefield
                text: "achref"
                color: "#181724"
                background: Rectangle {
                    color: "#eeeeee"
                    radius: 5
                }
		implicitWidth: 400
            }


            TextField {
                id: passwordfield
                placeholderText: "enter your password"
                color: "#181724"
                background: Rectangle {
                    color: "#eeeeee"
                    radius: 5
                }
		implicitWidth: 400
                echoMode: TextInput.Password
		focus: true
            }

        }
        ColumnLayout {
	    id: labels
            anchors.right: inputFields.left 
            anchors.top: inputFields.top 
	    anchors.rightMargin: 8
            spacing: 16

            Label {
                text: "Username:"
                font.bold: true
                color: "#ffffff"
		font.pixelSize: 18
            }
            Label {
                text: "Password:"
                font.bold: true
                color: "#ffffff"
		font.pixelSize: 18
            }
    }


            RowLayout {
	    	id: buttons
	    	anchors.top: inputFields.bottom 
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.topMargin: 20


		Button {
		    id: loginButton
		    text: "Login"
		    implicitWidth: 100
		    hoverEnabled: true
		    focus: true
		    onClicked: authenticateUser(usernamefield.text, passwordfield.text,dropDownMenu.currentIndex);
		     Keys.onPressed: {
			if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
				authenticateUser(usernamefield.text, passwordfield.text,dropDownMenu.currentIndex);
			}
		    }
		    background: Rectangle {
			color: loginButton.activeFocus || loginButton.hovered ? "#FFFF00" : "#DDDDDD"
			
			radius: 5
		    }

		}

	    }
	ColumnLayout {
		id: comboBox
		anchors.top: parent.top
		anchors.left: parent.left
		anchors.topMargin: 10
		anchors.leftMargin: 10
		ComboBox {
    id: dropDownMenu
    function readSessionNames() {
            var file = new XMLHttpRequest();
            file.open("GET", "sessions.txt", false);
            file.send(null);
            var sessionNames = file.responseText.trim().split(" ");
            return sessionNames;
        }

        model: readSessionNames()
    //model: ListModel {
     //   ListElement { text: "qtile wayland" }
      //  ListElement { text: "qtile x11" }
    //}


    //  Set the default selected item
    currentIndex: 1

    //  Handle the selected item change
    onCurrentIndexChanged: {
        var selectedItem = model.get(currentIndex).index;
    }

}

	}
	ColumnLayout {
	     id: error
	     anchors.top: buttons.bottom
	     anchors.topMargin: 20
	     anchors.horizontalCenter: parent.horizontalCenter
	     Label {
	    text: "wrong credentials"
	    font.bold: true
	    color: "#181724"
	    padding: 10
	    background: Rectangle {
		color: "#181724"
		radius: 20 
	    }
	}

	}
    }
}

