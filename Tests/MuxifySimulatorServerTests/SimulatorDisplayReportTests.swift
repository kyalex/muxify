import XCTest
import XPC
@testable import MuxifySimulatorServer

final class SimulatorDisplayReportTests: XCTestCase {
    func testIOS265LegacyDisplayReportWithInactiveExternalDisplays() throws {
        let report = try DisplayReport.parse(makeReport(.legacy))
        XCTAssertEqual(report.displays.count, 2)
        XCTAssertEqual(report.activeIntegrated?.uniqueID, "display:1")
        XCTAssertEqual(report.activeIntegrated?.currentRotation, 90)
        XCTAssertEqual(report.activeIntegrated?.pixelSize, CGSize(width: 1206, height: 2622))
        XCTAssertEqual(report.activeIntegrated?.displayID, 1)
    }

    func testNewerDisplayReportStillUsesPanelIdentityAndActivity() throws {
        let report = try DisplayReport.parse(makeReport(.layoutActivity))
        XCTAssertEqual(report.activeIntegrated?.uniqueID, "main-screen")
        XCTAssertEqual(report.activeIntegrated?.currentRotation, 90)
    }

    func testIOS27PrimaryDisplayReportWithInactiveAuxiliaryDisplays() throws {
        // Captured on iPhone 18 Pro, iOS 27.0, Xcode 27A266a: uniqueId and
        // primary are present, but active and per-display backlightState are not.
        let report = try DisplayReport.parse(makeReport(.primary))
        XCTAssertEqual(report.displays.count, 4)
        XCTAssertEqual(report.displays.map(\.isActive), [true, false, false, false])
        XCTAssertEqual(report.activeIntegrated?.uniqueID, "main-screen")
        XCTAssertEqual(report.activeIntegrated?.displayID, 1)
        XCTAssertEqual(report.activeIntegrated?.currentRotation, 0)
        XCTAssertEqual(report.activeIntegrated?.pixelSize, CGSize(width: 1206, height: 2622))
    }

    func testPrimaryReportRequiresExplicitFlagsOnEveryDisplay() {
        let report = makeReport(.primary)
        xpc_dictionary_set_value(record(in: report, at: 1), "primary", nil)
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    func testPrimaryReportRequiresSizeForTheActiveDisplay() {
        let report = makeReport(.primary)
        xpc_dictionary_set_value(record(in: report, at: 0), "bounds", nil)
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    func testPrimaryReportDoesNotFallBackToLegacyIdentityForOneMissingID() {
        let report = makeReport(.primary)
        xpc_dictionary_set_value(record(in: report, at: 0), "uniqueId", nil)
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    func testLayoutActivityOverridesPrimaryAndBacklight() throws {
        let output = makeReport(.layoutActivity)
        xpc_dictionary_set_bool(record(in: output, at: 0), "active", false)
        let report = try DisplayReport.parse(output)
        XCTAssertFalse(report.displays[0].isActive)
        XCTAssertNil(report.activeIntegrated)
    }

    func testIncompleteLayoutActivityDoesNotFallBackToPrimary() {
        let report = makeReport(.layoutActivity)
        xpc_dictionary_set_value(record(in: report, at: 1), "active", nil)
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    func testPanelBacklightOverridesPrimaryAndTopLevelBacklight() throws {
        let output = makeReport(.panelBacklight)
        xpc_dictionary_set_string(record(in: output, at: 0), "backlightState", "off")
        let report = try DisplayReport.parse(output)
        XCTAssertFalse(report.displays[0].isActive)
        XCTAssertNil(report.activeIntegrated)
    }

    func testPanelBacklightCanIdentifyAnActiveDisplay() throws {
        let report = try DisplayReport.parse(makeReport(.panelBacklight))
        XCTAssertEqual(report.activeIntegrated?.uniqueID, "main-screen")
    }

    func testIncompletePanelBacklightDoesNotFallBackToPrimary() {
        let report = makeReport(.panelBacklight)
        xpc_dictionary_set_value(record(in: report, at: 1), "backlightState", nil)
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    func testUnknownPanelBacklightDoesNotFallBackToPrimary() {
        let report = makeReport(.panelBacklight)
        xpc_dictionary_set_string(record(in: report, at: 0), "backlightState", "unknown")
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    func testMultipleActiveIntegratedDisplaysDoNotProduceAnInputTarget() throws {
        let output = makeReport(.primary)
        let second = record(in: output, at: 1)
        xpc_dictionary_set_bool(second, "primary", true)
        xpc_dictionary_set_value(second, "type", xpc_dictionary_get_value(record(in: output, at: 0), "type"))
        xpc_dictionary_set_value(second, "bounds", xpc_dictionary_get_value(record(in: output, at: 0), "bounds"))
        let report = try DisplayReport.parse(output)
        XCTAssertNil(report.activeIntegrated)
    }

    func testDuplicateIdentityIsRejected() {
        let report = makeReport(.legacy)
        let records = xpc_dictionary_get_value(report, "displays")!
        let external = xpc_array_get_value(records, 1)
        xpc_dictionary_set_uint64(external, "displayId", 1)
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    func testMissingNewSchemaIdentityDoesNotFallBackToLegacyIdentity() {
        let report = makeReport(.layoutActivity)
        let records = xpc_dictionary_get_value(report, "displays")!
        xpc_dictionary_set_value(xpc_array_get_value(records, 0), "uniqueId", nil)
        XCTAssertThrowsError(try DisplayReport.parse(report))
    }

    private enum Format { case legacy, primary, layoutActivity, panelBacklight }

    private func record(in report: xpc_object_t, at index: Int) -> xpc_object_t {
        xpc_array_get_value(xpc_dictionary_get_value(report, "displays")!, index)
    }

    private func makeReport(_ format: Format) -> xpc_object_t {
        let output = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_bool(output, "current", true)
        xpc_dictionary_set_string(output, "backlightState", "activeOn")
        let records = xpc_array_create(nil, 0)
        let types = format == .primary ? ["integrated", "external", "wireless", "virtual"] : ["integrated", "external"]
        let identities = ["main-screen", "external-screen", "wireless-screen", "virtual-screen"]
        for index in types.indices {
            let record = xpc_dictionary_create(nil, nil, 0)
            xpc_dictionary_set_uint64(record, "displayId", UInt64(index + 1))
            xpc_dictionary_set_bool(record, "primary", index == 0)
            xpc_dictionary_set_string(record, "currentOrientation", format == .primary ? "rot0" : "rot90")
            if format != .legacy {
                xpc_dictionary_set_string(record, "uniqueId", identities[index])
            }
            if format == .layoutActivity {
                xpc_dictionary_set_bool(record, "active", index == 0)
            }
            if format == .layoutActivity || format == .panelBacklight {
                xpc_dictionary_set_string(record, "backlightState", index == 0 ? "activeOn" : "off")
            }
            let type = xpc_dictionary_create(nil, nil, 0)
            xpc_dictionary_set_value(type, types[index], xpc_dictionary_create(nil, nil, 0))
            xpc_dictionary_set_value(record, "type", type)
            let bounds = xpc_array_create(nil, 0)
            for corner in [CGPoint.zero, index == 0 ? CGPoint(x: 1206, y: 2622) : .zero] {
                let pair = xpc_array_create(nil, 0)
                xpc_array_append_value(pair, xpc_double_create(corner.x))
                xpc_array_append_value(pair, xpc_double_create(corner.y))
                xpc_array_append_value(bounds, pair)
            }
            xpc_dictionary_set_value(record, "bounds", bounds)
            xpc_array_append_value(records, record)
        }
        xpc_dictionary_set_value(output, "displays", records)
        return output
    }
}
