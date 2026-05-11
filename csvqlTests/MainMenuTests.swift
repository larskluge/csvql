import XCTest
@testable import csvql

final class MainMenuTests: XCTestCase {

    func testMenuHasAppEditAndViewItems() {
        let menu = MainMenu.make()
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].title, "csvql")
        XCTAssertEqual(menu.items[1].title, "Edit")
        XCTAssertEqual(menu.items[2].title, "View")
    }

    func testAppMenuHasQuit() {
        let menu = MainMenu.make()
        let appSubmenu = menu.items[0].submenu!
        let quit = appSubmenu.items.first { $0.title == "Quit" }
        XCTAssertNotNil(quit)
        XCTAssertEqual(quit?.keyEquivalent, "q")
        XCTAssertEqual(quit?.action, #selector(NSApplication.terminate(_:)))
    }

    func testEditMenuHasCopyAndSelectAll() {
        let menu = MainMenu.make()
        let editSubmenu = menu.items[1].submenu!

        let copy = editSubmenu.items.first { $0.title == "Copy" }
        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.keyEquivalent, "c")

        let selectAll = editSubmenu.items.first { $0.title == "Select All" }
        XCTAssertNotNil(selectAll)
        XCTAssertEqual(selectAll?.keyEquivalent, "a")
    }

    func testViewMenuHasDensityOptions() {
        let menu = MainMenu.make()
        let viewSubmenu = menu.items[2].submenu!
        XCTAssertEqual(viewSubmenu.items.count, 3)

        let compact = viewSubmenu.items.first { $0.title == "Compact" }
        XCTAssertNotNil(compact)
        XCTAssertEqual(compact?.keyEquivalent, "1")

        let regular = viewSubmenu.items.first { $0.title == "Regular" }
        XCTAssertNotNil(regular)
        XCTAssertEqual(regular?.keyEquivalent, "2")

        let comfortable = viewSubmenu.items.first { $0.title == "Comfortable" }
        XCTAssertNotNil(comfortable)
        XCTAssertEqual(comfortable?.keyEquivalent, "3")
    }
}
