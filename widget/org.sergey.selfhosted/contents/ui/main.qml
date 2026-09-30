import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Live status of self-hosted services. Edit `services` to add/remove one.
// Any HTTP response (even 302/401) = up; connection refused or >5s = down.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    property var services: [
        { name: "Jellyfin",  port: 8096, url: "http://localhost:8096", open: "https://jellyfin.daoseeking.duckdns.org:8443", containers: ["jellyfin"] },
        { name: "BookOrbit", port: 3000, url: "http://localhost:3000", open: "https://books.daoseeking.duckdns.org:8443", containers: ["bookorbit-app","bookorbit-db"] },
        { name: "Ryot",      port: 8000, url: "http://localhost:8000", open: "https://ryot.daoseeking.duckdns.org:8443", containers: ["ryot","ryot-db"] },
        { name: "Vaultwarden", port: 8222, url: "http://127.0.0.1:8222/alive", open: "https://vault.daoseeking.duckdns.org:8443", containers: ["vaultwarden"] },
        { name: "Shoko",     port: 8111, url: "http://localhost:8111", open: "https://shoko.daoseeking.duckdns.org:8443/webui", containers: ["shoko"] },
        { name: "AdGuard",   port: 3080, url: "http://192.168.1.216:3080", open: "https://adguard.daoseeking.duckdns.org:8443", containers: ["adguard"] },
        { name: "Seerr",     port: 5055, url: "http://127.0.0.1:5055", open: "https://requests.daoseeking.duckdns.org:8443", containers: ["seerr"] },
        { name: "Sonarr",    port: 8989, url: "http://127.0.0.1:8989", open: "https://sonarr.daoseeking.duckdns.org:8443", containers: ["sonarr"] },
        { name: "Radarr",    port: 7878, url: "http://127.0.0.1:7878", open: "https://radarr.daoseeking.duckdns.org:8443", containers: ["radarr"] },
        { name: "Prowlarr",  port: 9696, url: "http://127.0.0.1:9696", open: "https://prowlarr.daoseeking.duckdns.org:8443", containers: ["prowlarr","flaresolverr"] },
        { name: "qBittorrent", port: 8090, url: "http://127.0.0.1:8090", open: "https://qbit.daoseeking.duckdns.org:8443", containers: ["qbittorrent"] },
        { name: "Bazarr",    port: 6767, url: "http://127.0.0.1:6767", open: "https://bazarr.daoseeking.duckdns.org:8443", containers: ["bazarr"] }
    ]
    property var status: ({})   // name -> { up: bool, ms: int }
    property var usage: ({})    // container -> { cpu: %, mem: MiB }, from ~/homelab/widget/stats.sh

    function usageFor(s) {
        let cpu = 0, mem = 0, seen = false
        for (const c of s.containers) {
            const u = usage[c]
            if (u) { cpu += u.cpu; mem += u.mem; seen = true }
        }
        return seen ? cpu.toFixed(1) + "% · " + (mem >= 1024 ? (mem / 1024).toFixed(1) + " GB" : Math.round(mem) + " MB") : ""
    }

    // Runs the stats script (docker stats + native Jellyfin) every 30 s.
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const u = {}
            for (const line of (data["stdout"] || "").split("\n")) {
                const f = line.trim().split(/\s+/)
                if (f.length === 3) u[f[0]] = { cpu: parseFloat(f[1]), mem: parseFloat(f[2]) }
            }
            root.usage = u
            disconnectSource(source)
        }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: exec.connectSource("/home/sergey/homelab/widget/stats.sh") }
    property var pending: ({})  // name -> start time of the in-flight check
    property int round: 0       // late replies from an older round are ignored

    function setStatus(name, up, ms) {
        const st = Object.assign({}, status)
        st[name] = { up: up, ms: ms }
        status = st
    }

    // No abort() and no dynamically created objects: both crashed plasmashell (SIGSEGV in libQt6Qml).
    function check(s, r) {
        const xhr = new XMLHttpRequest()
        const t0 = Date.now()
        pending[s.name] = t0
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || r !== round || pending[s.name] !== t0) return
            delete pending[s.name]
            setStatus(s.name, xhr.status > 0, Date.now() - t0)
        }
        xhr.open("GET", s.url)
        xhr.send()
    }

    function checkAll() {
        round++
        pending = ({})
        services.forEach(s => check(s, round))
    }

    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.checkAll() }
    // Anything still pending after 5s is shown as down.
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const now = Date.now()
            for (const name in root.pending)
                if (now - root.pending[name] > 5000) { delete root.pending[name]; root.setStatus(name, false, 0) }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 3
            text: "Self-hosted"
            Layout.leftMargin: Kirigami.Units.smallSpacing
        }

        GridLayout {
            columns: 2
            rows: Math.ceil(root.services.length / 2)
            flow: GridLayout.TopToBottom
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 0
            Layout.fillWidth: true
        Repeater {
            model: root.services
            delegate: MouseArea {
                required property var modelData
                readonly property var st: root.status[modelData.name]
                Layout.fillWidth: true
                implicitHeight: row.implicitHeight + Kirigami.Units.smallSpacing * 2
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Qt.openUrlExternally(modelData.open)

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: parent.containsMouse ? 0.15 : 0
                }

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.largeSpacing

                    Rectangle {
                        width: Kirigami.Units.gridUnit * 0.7; height: width; radius: width / 2
                        color: !st ? Kirigami.Theme.disabledTextColor
                             : st.up ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents.Label { text: modelData.name; font.bold: true }
                        PlasmaComponents.Label {
                            text: modelData.open.replace(/^https?:\/\//, "")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        PlasmaComponents.Label {
                            text: root.usageFor(modelData)
                            Layout.alignment: Qt.AlignRight
                            opacity: 0.85
                        }
                        PlasmaComponents.Label {
                            text: ":" + modelData.port + "  " + (!st ? "…" : st.up ? st.ms + " ms" : "down")
                            color: st && !st.up ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: st && st.up ? 0.6 : 1
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }
        }
        }

        Item { Layout.fillHeight: true }
    }
}
