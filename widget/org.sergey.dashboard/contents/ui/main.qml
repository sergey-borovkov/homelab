import QtQuick
import QtWebEngine
import org.kde.plasma.plasmoid

// Shows the Homepage dashboard (https://dash.daoseeking.uk) with no address bar.
// Links open in the default browser instead of inside the widget.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    readonly property url home: "https://dash.daoseeking.uk/"

    fullRepresentation: WebEngineView {
        id: view
        url: root.home
        zoomFactor: 1.0
        backgroundColor: "transparent"
        onNewWindowRequested: request => Qt.openUrlExternally(request.requestedUrl)
        onNavigationRequested: request => {
            if (request.url.toString().startsWith(root.home)) return
            request.action = WebEngineNavigationRequest.IgnoreRequest
            Qt.openUrlExternally(request.url)
        }
        // Reload if the dashboard was down (e.g. Homepage restarted) instead of showing an error forever.
        onLoadingChanged: loadRequest => {
            if (loadRequest.status === WebEngineView.LoadFailedStatus) retry.start()
        }
        Timer { id: retry; interval: 30000; onTriggered: view.reload() }
    }
}
