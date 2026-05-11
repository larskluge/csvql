import Foundation
#if canImport(AppKit)
import AppKit
#endif

private class BundleAnchor {}

struct CSVRenderer {

    #if canImport(AppKit)
    static let previewSize = NSSize(width: 1180, height: 780)
    #endif

    static func render(data: CSVData, interactive: Bool) -> String {
        let css = loadCSS()
        let js = interactive ? interactiveJS() : ""
        let titlebar = renderTitlebar(data: data, interactive: interactive)
        let subtoolbar = renderSubToolbar(data: data, interactive: interactive)
        let table = renderTable(data: data, interactive: interactive)
        let footer = renderFooter(data: data)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>
        <div class="ql-window">
        \(titlebar)
        \(subtoolbar)
        <div class="table-container">
        \(table)
        </div>
        \(footer)
        </div>
        \(js)
        </body>
        </html>
        """
    }

    // MARK: - CSS

    private static func loadCSS() -> String {
        let bundle = Bundle(for: BundleAnchor.self)
        if let url = bundle.url(forResource: "preview", withExtension: "css"),
           let css = try? String(contentsOf: url, encoding: .utf8) {
            return css
        }
        let execDir = Bundle.main.executableURL?.deletingLastPathComponent().path ?? "."
        if let css = try? String(contentsOfFile: execDir + "/preview.css", encoding: .utf8) {
            return css
        }
        return ""
    }

    // MARK: - Titlebar

    private static func renderTitlebar(data: CSVData, interactive: Bool) -> String {
        return ""
    }

    // MARK: - Sub-toolbar

    private static func renderSubToolbar(data: CSVData, interactive: Bool) -> String {
        if !interactive { return "" }

        return """
        <div class="sub-toolbar">
        <div></div>
        <div class="toolbar-pills">
        <div class="search-box">
        <svg viewBox="0 0 11 11"><circle cx="4.5" cy="4.5" r="3.5" fill="none" stroke-width="1.2"/><line x1="7" y1="7" x2="10" y2="10" stroke-width="1.2"/></svg>
        <input type="text" placeholder="Filter rows..." oninput="filterRows(this.value)">
        <span class="match-count" id="match-count"></span>
        </div>
        </div>
        </div>
        """
    }

    // MARK: - Table

    private static func renderTable(data: CSVData, interactive: Bool) -> String {
        var html = "<table><thead><tr>"
        html += "<th class=\"row-num\">#</th>"

        for (i, header) in data.headers.enumerated() {
            let sortClass = interactive ? " sortable" : ""
            let sortAttr = interactive ? " onclick=\"sortColumn(\(i))\"" : ""
            let typeClass = i < data.types.count ? columnWidthClass(data.types[i]) : ""
            html += "<th class=\"\(typeClass)\(sortClass)\"\(sortAttr)>\(escapeHTML(header))</th>"
        }
        html += "</tr></thead><tbody>"

        for (rowIndex, row) in data.rows.enumerated() {
            let rowAttr = interactive ? " onclick=\"selectRow(this)\"" : ""
            html += "<tr\(rowAttr)>"
            html += "<td class=\"row-num\">\(rowIndex + 1)</td>"

            for (colIndex, value) in row.enumerated() {
                let type = colIndex < data.types.count ? data.types[colIndex] : .text
                html += renderCell(value: value, type: type)
            }

            if row.count < data.headers.count {
                for _ in row.count..<data.headers.count {
                    html += renderCell(value: "", type: .text)
                }
            }

            html += "</tr>"
        }

        html += "</tbody></table>"
        return html
    }

    private static func columnWidthClass(_ type: ColumnType) -> String {
        switch type {
        case .number: return "col-number"
        case .link: return "col-link"
        default: return ""
        }
    }

    // MARK: - Cell Rendering

    private static func renderCell(value: String, type: ColumnType) -> String {
        if value.isEmpty {
            return "<td class=\"type-empty\">\u{2014}</td>"
        }

        switch type {
        case .number:
            return "<td class=\"type-number\">\(formatNumber(value))</td>"

        case .date:
            return renderDateCell(value)

        case .bool:
            let lower = value.lowercased()
            let pillClass = lower == "true" ? "pill-true" : "pill-false"
            return "<td><span class=\"status-pill \(pillClass)\"><span class=\"dot\"></span>\(escapeHTML(value))</span></td>"

        case .link:
            let display = stripScheme(value)
            return "<td class=\"type-link\"><a href=\"\(escapeAttribute(value))\">\(escapeHTML(display))</a></td>"

        case .email:
            return "<td class=\"type-email\">\(escapeHTML(value))</td>"

        case .sha:
            return "<td class=\"type-sha\"><span class=\"sha-chip\">\(escapeHTML(value))</span></td>"

        case .text:
            if TypeInferrer.isStatusKeyword(value) {
                let pillClass = "pill-\(value.lowercased())"
                return "<td><span class=\"status-pill \(pillClass)\"><span class=\"dot\"></span>\(escapeHTML(value))</span></td>"
            }
            return "<td>\(escapeHTML(value))</td>"
        }
    }

    private static func renderDateCell(_ value: String) -> String {
        if let tIndex = value.firstIndex(of: "T") {
            let datePart = String(value[value.startIndex..<tIndex])
            let timePart = String(value[value.index(after: tIndex)...]).replacingOccurrences(of: "Z", with: "")
            return "<td class=\"type-date\">\(escapeHTML(datePart))<span class=\"time-part\">\(escapeHTML(timePart))</span></td>"
        }
        return "<td class=\"type-date\">\(escapeHTML(value))</td>"
    }

    private static func formatNumber(_ value: String) -> String {
        guard let num = Double(value) else { return escapeHTML(value) }
        let hasDecimal = value.contains(".")
        if hasDecimal {
            let decimalPlaces = value.split(separator: ".").last.map { $0.count } ?? 0
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "en_US")
            formatter.minimumFractionDigits = decimalPlaces
            formatter.maximumFractionDigits = decimalPlaces
            return formatter.string(from: NSNumber(value: num)) ?? escapeHTML(value)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "en_US")
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: num)) ?? escapeHTML(value)
        }
    }

    private static func stripScheme(_ url: String) -> String {
        var result = url
        if result.hasPrefix("https://") { result = String(result.dropFirst(8)) }
        else if result.hasPrefix("http://") { result = String(result.dropFirst(7)) }
        if result.hasSuffix("/") { result = String(result.dropLast()) }
        return result
    }

    // MARK: - Footer

    private static func renderFooter(data: CSVData) -> String {
        let delimiterName = DelimiterDetector.name(for: data.delimiter)

        return """
        <div class="footer">
        <div class="footer-left">
        <span><span class="label">rows </span><span class="value" id="row-count">\(data.rows.count)</span></span>
        <span><span class="label">cols </span><span class="value">\(data.headers.count)</span></span>
        <span><span class="label">size </span><span class="value">\(data.formattedSize)</span></span>
        <span><span class="label">modified </span><span class="value">\(data.timeAgo)</span></span>
        </div>
        <div class="footer-right">
        <div class="pill"><span class="label">\(data.lineEnding) </span></div>
        <div class="pill"><span class="label">delimiter </span><span class="value">\(delimiterName)</span></div>
        <div class="pill"><span class="label">encoding </span><span class="value">\(data.encoding)</span></div>
        <span class="csvql-badge"><span class="csvql-dot"></span><span class="value">csvql</span></span>
        </div>
        </div>
        """
    }

    // MARK: - Interactive JS

    private static func interactiveJS() -> String {
        return """
        <script>
        let sortCol = null;
        let sortDir = null;
        const tbody = document.querySelector('tbody');
        const rows = Array.from(tbody.querySelectorAll('tr'));
        const originalRows = rows.slice();

        function sortColumn(colIndex) {
            const headers = document.querySelectorAll('thead th');
            if (sortCol === colIndex) {
                if (sortDir === 'asc') { sortDir = 'desc'; }
                else if (sortDir === 'desc') { sortCol = null; sortDir = null; }
            } else {
                sortCol = colIndex;
                sortDir = 'asc';
            }

            headers.forEach(h => { h.classList.remove('sort-active'); h.querySelector('.sort-indicator')?.remove(); });

            if (sortCol !== null) {
                const th = headers[colIndex + 1];
                th.classList.add('sort-active');
                const indicator = document.createElement('span');
                indicator.className = 'sort-indicator';
                indicator.innerHTML = sortDir === 'asc'
                    ? '<svg viewBox="0 0 8 8"><polygon points="4,1 7,6 1,6"/></svg>'
                    : '<svg viewBox="0 0 8 8"><polygon points="4,7 1,2 7,2"/></svg>';
                th.appendChild(indicator);
            }

            const sorted = sortCol !== null ? rows.slice().sort((a, b) => {
                const cellA = a.children[colIndex + 1]?.textContent?.trim() || '';
                const cellB = b.children[colIndex + 1]?.textContent?.trim() || '';
                const numA = parseFloat(cellA.replace(/,/g, ''));
                const numB = parseFloat(cellB.replace(/,/g, ''));
                let cmp;
                if (!isNaN(numA) && !isNaN(numB)) { cmp = numA - numB; }
                else { cmp = cellA.localeCompare(cellB); }
                return sortDir === 'desc' ? -cmp : cmp;
            }) : originalRows;

            sorted.forEach(r => tbody.appendChild(r));
            renumberRows();
        }

        function filterRows(query) {
            const q = query.toLowerCase();
            let visible = 0;
            rows.forEach(row => {
                const cells = Array.from(row.children).slice(1);
                const match = !q || cells.some(c => c.textContent.toLowerCase().includes(q));
                row.style.display = match ? '' : 'none';
                if (match) visible++;
            });
            const countEl = document.getElementById('match-count');
            if (countEl) countEl.textContent = q ? visible + '/' + rows.length : '';
            const rowCountEl = document.getElementById('row-count');
            if (rowCountEl) rowCountEl.textContent = q ? visible + '/' + rows.length : String(rows.length);
        }

        function selectRow(tr) {
            document.querySelectorAll('tbody tr.selected').forEach(r => r.classList.remove('selected'));
            tr.classList.add('selected');
        }

        function renumberRows() {
            const visible = rows.filter(r => r.style.display !== 'none');
            visible.forEach((r, i) => { r.children[0].textContent = i + 1; });
        }

        function setDensity(density) {
            const win = document.querySelector('.ql-window');
            win.classList.remove('density-compact', 'density-comfortable');
            if (density === 'compact') win.classList.add('density-compact');
            else if (density === 'comfortable') win.classList.add('density-comfortable');
        }
        </script>
        """
    }

    // MARK: - HTML Escaping

    static func escapeHTML(_ string: String) -> String {
        string.replacingOccurrences(of: "&", with: "&amp;")
              .replacingOccurrences(of: "<", with: "&lt;")
              .replacingOccurrences(of: ">", with: "&gt;")
              .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeAttribute(_ string: String) -> String {
        escapeHTML(string)
    }
}
