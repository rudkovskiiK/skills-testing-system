// testPage.mjs - this file is part of skills-testing-system
// Copyright (C) 2026  Kirill Rudkovskii
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import {EditorView, basicSetup} from "codemirror"
import {EditorState} from "@codemirror/state"
import {StreamLanguage} from "@codemirror/language"
import {python} from "@codemirror/legacy-modes/mode/python"
import {shell} from "@codemirror/legacy-modes/mode/shell"

var runCodeButton = document.getElementById("runCodeButton");
var goNextTaskButton = document.getElementById("goNextTaskButton");
var codeArea = document.getElementById("codeArea");
var outputArea = document.getElementById("outputArea");
var taskStatusSpan = document.getElementById("taskStatus");
var totalResultSpan = document.getElementById("totalResult");

let languages = new Map();
languages.set("py", python);
languages.set("sh", shell);
let languageName = document.getElementById("taskLanguage").innerHTML;

let code = codeArea.innerHTML;
while(codeArea.firstChild) {
    codeArea.removeChild(codeArea.firstChild);
}

let startState = EditorState.create({
    doc: code,
    extensions: [basicSetup, StreamLanguage.define(languages.get(languageName) || python)],
});

let editor = new EditorView({
    state: startState,
    parent: codeArea,
});

function getBasicHeaders() {
    let headers = {
            "Content-Type": "application/json;charset=UTF-8",
    }
    let csrfHeaderName = document.querySelector("meta[name='csrf-header']").content;
    let csrfToken = document.querySelector("meta[name='csrf-token']").content;
    headers[csrfHeaderName] = csrfToken;
    return headers;
}

var execBlock = false
runCodeButton.addEventListener("click", async () => {
    if(execBlock) {
        return;
    }
    execBlock = true

    try {
        let response = await fetch("/exec_code", {
            method: "POST",
            headers: getBasicHeaders(),
            body: JSON.stringify({code: editor.state.doc.toString()}),
        });
        if(!response.ok) {
            alert("Failed request!");
            execBlock = false
            return;
        }
        let resultExecCode = await response.json();
        while(outputArea.firstChild) {
            outputArea.removeChild(outputArea.firstChild);
        }
        outputArea.appendChild(document.createTextNode(resultExecCode.answer));
        response = await fetch("/image_names");
        if(!response.ok) {
            alert("Failed request!");
            execBlock = false
            return;
        }
        let imageNames = await response.json();
        for(const imageName of imageNames) {
            let figure = document.createElement("figure");
            let img = document.createElement("img");
            img.src = "/image/" + imageName;
            let figcaption = document.createElement("figcaption");
            figcaption.appendChild(document.createTextNode(imageName.substring(14)));
            figure.appendChild(img);
            figure.appendChild(figcaption);
            outputArea.appendChild(figure);
            outputArea.appendChild(document.createElement("br"));
        }
        response = await fetch("/result_info");
        if(!response.ok) {
            alert("Failed request!");
            execBlock = false
            return;
        }
        let studentResultInfo = await response.json();
        taskStatusSpan.innerHTML = studentResultInfo.taskStatusForHuman;
        totalResultSpan.innerHTML = studentResultInfo.totalResult;
        if(studentResultInfo.taskStatus) {
            editor.dispatch({
                changes: {
                    from: 0,
                    to: editor.state.doc.toString().length,
                    insert: "",
                }
            });
        }
    } catch(error) {
        alert(error);
        execBlock = false
    }
    execBlock = false
});

goNextTaskButton.addEventListener("click", () => {
    if(execBlock) {
        return;
    }

    fetch("/next_task", {
        method: "POST",
        headers: getBasicHeaders(),
        body: JSON.stringify({code: editor.state.doc.toString()}),
    }).then(response => {
        if(response.ok) {
            window.location.reload()
        } else {
            throw new Error("Failed request!");
        }
    }).catch(error => {
        alert(error);
    });
});
