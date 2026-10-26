import QtQuick
import Kplus
import QtQuick.Dialogs

// The platform's own file and folder dialogs, shown when the backend asks for one (it is waiting for the answer).
Item {
    id: root
    property int reqId: 0

    function toPath(url) { return decodeURIComponent(String(url).replace(/^file:\/\//, "")) }
    function answer(path) { Backend.reply({ dialogResult: { id: root.reqId, path: path } }) }
    function filters(list) {
        return (list || []).map(function (f) { return f.name + " (" + f.extensions.map(function (e) { return "*." + e }).join(" ") + ")" })
    }

    function show(d) {
        root.reqId = d.id
        var r = d.request
        if (r.kind === "folder") { folder.title = r.title; folder.open() }
        else {
            file.title = r.title
            file.fileMode = r.kind === "save" ? FileDialog.SaveFile : FileDialog.OpenFile
            file.nameFilters = filters(r.filters)
            file.selectedFile = r.defaultName ? "file://" + r.defaultName : ""
            file.open()
        }
    }

    FolderDialog {
        id: folder
        onAccepted: root.answer(root.toPath(selectedFolder))
        onRejected: root.answer(null)
    }
    FileDialog {
        id: file
        onAccepted: root.answer(root.toPath(selectedFile))
        onRejected: root.answer(null)
    }
}
