#!/usr/bin/env python3
"""
Pure-Python device & simulator container state parser for QırımKey (Build 18, 2026-11-08).
Uses only standard library modules (plistlib, glob, json, datetime, pathlib) — zero xcrun/xcodebuild calls.

Parses:
1. Physical iPad Air 3 (ipad_air3_appGroupDataContainer + ipad_air3_appDataContainer + ipad_app + ipad_group)
2. Physical iPhone 15 Pro (iphone_app + iphone_group + iphone15pro_appDataContainer + iphone15pro_appGroupDataContainer)
3. Active iPad (A16) Simulator (63ECA47D-F20B-4916-96C2-995009C737C4 App Group group.crh.key.keyboardplus.plist,
   Diagnostics/keyboard_lifecycle.jsonl, Diagnostics/metrickit_diagnostics.jsonl, and crh.key.keyboard.plist)

Writes the complete, timestamped diagnostic summary to parsed_device_state_2026-11-08.txt.
"""

import glob
import json
import os
import plistlib
from datetime import datetime
from pathlib import Path

DEVICE_LOGS_DIR = Path(__file__).resolve().parent
OUTPUT_TXT = DEVICE_LOGS_DIR / "parsed_device_state_2026-11-08.txt"
SIM_UDID = "63ECA47D-F20B-4916-96C2-995009C737C4"
SIM_CONTAINERS_ROOT = (
    Path.home()
    / "Library/Developer/CoreSimulator/Devices"
    / SIM_UDID
    / "data/Containers"
)


def fmt_mtime(path: Path) -> str:
    try:
        ts = path.stat().st_mtime
        return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S EET")
    except OSError:
        return "N/A"


def format_plist_block(plist_path: Path, label: str = "") -> list[str]:
    lines: list[str] = []
    header_suffix = f" ({label}, mtime={fmt_mtime(plist_path)})" if label else f" (mtime={fmt_mtime(plist_path)})"
    lines.append(f"=== PLIST: {plist_path}{header_suffix}")
    if not plist_path.exists():
        lines.append("  [MISSING]")
        return lines
    try:
        with plist_path.open("rb") as fp:
            data = plistlib.load(fp)
        if not isinstance(data, dict):
            lines.append(f"  [NON-DICT PLIST]: {repr(data)}")
            return lines
        for key in sorted(data.keys()):
            lines.append(f"  {key}: {repr(data[key])}")
    except Exception as exc:
        lines.append(f"  [ERROR READING PLIST]: {exc}")
    return lines


def load_plist_dict(plist_path: Path) -> dict:
    if not plist_path.exists():
        return {}
    try:
        with plist_path.open("rb") as fp:
            data = plistlib.load(fp)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def format_jsonl_diagnostics(diag_dir: Path, device_label: str) -> list[str]:
    lines: list[str] = []
    lifecycle_path = diag_dir / "keyboard_lifecycle.jsonl"
    metrickit_jsonl_path = diag_dir / "metrickit_diagnostics.jsonl"
    metrickit_files = sorted(glob.glob(str(diag_dir / "metrickit_diag_*.json")))

    lines.append(f"=== DIAGNOSTICS: {diag_dir} ({device_label})")
    if lifecycle_path.exists():
        raw_lines = [
            ln.strip()
            for ln in lifecycle_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if ln.strip()
        ]
        lines.append(
            f"  keyboard_lifecycle.jsonl: {len(raw_lines)} events (mtime={fmt_mtime(lifecycle_path)}, size={lifecycle_path.stat().st_size} B)"
        )
        for idx, raw_ln in enumerate(raw_lines, start=1):
            try:
                ev = json.loads(raw_ln)
                core = f"ts={ev.get('ts')} bundle={ev.get('bundle')} event={ev.get('event')}"
                extra = " ".join(
                    f"{k}={ev[k]}"
                    for k in sorted(ev.keys())
                    if k not in ("ts", "bundle", "event")
                )
                lines.append(f"    [{idx}] {core}" + (f" {extra}" if extra else ""))
            except Exception:
                lines.append(f"    [{idx}] {raw_ln}")
    else:
        lines.append("  keyboard_lifecycle.jsonl: [NOT PRESENT — 0 extension lifecycle events recorded in this container]")

    if metrickit_jsonl_path.exists():
        mk_lines = [
            ln.strip()
            for ln in metrickit_jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if ln.strip()
        ]
        lines.append(
            f"  metrickit_diagnostics.jsonl: {len(mk_lines)} entries (mtime={fmt_mtime(metrickit_jsonl_path)})"
        )
        for idx, raw_ln in enumerate(mk_lines, start=1):
            lines.append(f"    [{idx}] {raw_ln}")
    else:
        lines.append("  metrickit_diagnostics.jsonl: 0 MXHangDiagnostic / MXCrashDiagnostic entries (0 hangs)")

    lines.append(f"  metrickit_diag_*.json payloads: {len(metrickit_files)} files")
    for mf in metrickit_files:
        lines.append(f"    - {mf}")
    return lines


def format_documents_summary(docs_dir: Path, label: str) -> list[str]:
    lines: list[str] = []
    if not docs_dir.exists():
        return lines
    pngs = sorted(Path(p) for p in glob.glob(str(docs_dir / "*.png")))
    lines.append(f"=== DOCUMENTS ({label}): {docs_dir} ({len(pngs)} PNG files, latest mtime={fmt_mtime(docs_dir)})")
    for p in pngs:
        lines.append(f"  {p.name} ({p.stat().st_size} B, mtime={fmt_mtime(p)})")
    return lines


def find_simulator_containers(sim_root: Path) -> tuple[list[Path], list[Path]]:
    app_plists = sorted(
        Path(p)
        for p in glob.glob(str(sim_root / "Data/Application/*/Library/Preferences/crh.key.keyboard.plist"))
    )
    group_plists = sorted(
        Path(p)
        for p in glob.glob(
            str(sim_root / "Shared/AppGroup/*/Library/Preferences/group.crh.key.keyboardplus.plist")
        )
    )
    return app_plists, group_plists


def main() -> None:
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S EET")
    out: list[str] = []
    out.append("# QırımKey Device & Simulator Diagnostic State Summary (2026-11-08)")
    out.append(f"# Generated: {now_str}")
    out.append(f"# Generator: {Path(__file__).resolve()}")
    out.append("")

    # -------------------------------------------------------------------------
    # 1. Physical iPad Air 3 (00008020-00025DC63AA3002E)
    # -------------------------------------------------------------------------
    out.append("================================================================================")
    out.append("1. PHYSICAL DEVICE: iPad Air 3 (00008020-00025DC63AA3002E)")
    out.append("================================================================================")

    ipad_air3_fresh_group_plist = (
        DEVICE_LOGS_DIR
        / "ipad_air3_appGroupDataContainer/Library/Preferences/group.crh.key.keyboardplus.plist"
    )
    ipad_air3_app_plist = (
        DEVICE_LOGS_DIR / "ipad_air3_appDataContainer/Library/Preferences/crh.key.keyboard.plist"
    )
    ipad_app_plist = DEVICE_LOGS_DIR / "ipad_app/Library/Preferences/crh.key.keyboard.plist"
    ipad_group_plist = (
        DEVICE_LOGS_DIR / "ipad_group/Library/Preferences/group.crh.key.keyboardplus.plist"
    )

    out.extend(
        format_plist_block(
            ipad_air3_fresh_group_plist,
            "iPad Air 3 Fresh App Group Container — pulled 17:08 EET",
        )
    )
    out.extend(
        format_jsonl_diagnostics(
            DEVICE_LOGS_DIR / "ipad_air3_appGroupDataContainer/Diagnostics",
            "iPad Air 3 Fresh App Group Container",
        )
    )
    out.extend(
        format_plist_block(
            ipad_air3_app_plist,
            "iPad Air 3 App Data Container",
        )
    )
    out.extend(format_plist_block(ipad_app_plist, "iPad Air 3 Snapshot ipad_app"))
    out.extend(format_plist_block(ipad_group_plist, "iPad Air 3 Snapshot ipad_group"))
    out.extend(
        format_jsonl_diagnostics(
            DEVICE_LOGS_DIR / "ipad_group/Diagnostics",
            "iPad Air 3 Snapshot ipad_group",
        )
    )
    out.extend(
        format_documents_summary(
            DEVICE_LOGS_DIR / "ipad_air3_appDataContainer/Documents",
            "iPad Air 3 ipad_air3_appDataContainer/Documents",
        )
    )
    ipad_air3_app_alt_plist = DEVICE_LOGS_DIR / "ipad_air3_app/Library_Preferences/crh.key.keyboard.plist"
    ipad_air3_group_alt_plist = DEVICE_LOGS_DIR / "ipad_air3_group/Library_Preferences/group.crh.key.keyboardplus.plist"
    if ipad_air3_app_alt_plist.exists():
        out.extend(format_plist_block(ipad_air3_app_alt_plist, "iPad Air 3 Snapshot ipad_air3_app"))
    if (DEVICE_LOGS_DIR / "ipad_air3_app/Documents").exists():
        out.extend(
            format_documents_summary(
                DEVICE_LOGS_DIR / "ipad_air3_app/Documents",
                "iPad Air 3 ipad_air3_app/Documents",
            )
        )
    if ipad_air3_group_alt_plist.exists():
        out.extend(format_plist_block(ipad_air3_group_alt_plist, "iPad Air 3 Snapshot ipad_air3_group — pulled 17:39 EET"))
    out.append("")

    # -------------------------------------------------------------------------
    # 2. Physical iPhone 15 Pro (00008130-000954812231001C)
    # -------------------------------------------------------------------------
    out.append("================================================================================")
    out.append("2. PHYSICAL DEVICE: iPhone 15 Pro (00008130-000954812231001C)")
    out.append("================================================================================")

    iphone_app_plist = DEVICE_LOGS_DIR / "iphone_app/Library/Preferences/crh.key.keyboard.plist"
    iphone_group_plist = (
        DEVICE_LOGS_DIR / "iphone_group/Library/Preferences/group.crh.key.keyboardplus.plist"
    )
    iphone15pro_app_plist = DEVICE_LOGS_DIR / "iphone15pro_app/Library_Preferences/crh.key.keyboard.plist"
    iphone15pro_group_plist = DEVICE_LOGS_DIR / "iphone15pro_group/Library_Preferences/group.crh.key.keyboardplus.plist"

    out.extend(format_plist_block(iphone_app_plist, "iPhone 15 Pro Snapshot iphone_app"))
    out.extend(format_plist_block(iphone_group_plist, "iPhone 15 Pro Snapshot iphone_group"))
    if iphone15pro_app_plist.exists():
        out.extend(format_plist_block(iphone15pro_app_plist, "iPhone 15 Pro Snapshot iphone15pro_app"))
    if (DEVICE_LOGS_DIR / "iphone15pro_app/Documents").exists():
        out.extend(
            format_documents_summary(
                DEVICE_LOGS_DIR / "iphone15pro_app/Documents",
                "iPhone 15 Pro iphone15pro_app/Documents",
            )
        )
    if iphone15pro_group_plist.exists():
        out.extend(format_plist_block(iphone15pro_group_plist, "iPhone 15 Pro Snapshot iphone15pro_group — pulled 17:39 EET"))
    out.extend(
        format_jsonl_diagnostics(
            DEVICE_LOGS_DIR / "iphone_group/Diagnostics",
            "iPhone 15 Pro Snapshot iphone_group",
        )
    )
    out.extend(
        format_documents_summary(
            DEVICE_LOGS_DIR / "iphone_app/Documents",
            "iPhone 15 Pro iphone_app/Documents",
        )
    )
    out.append("")

    # -------------------------------------------------------------------------
    # 3. Active iPad (A16) Simulator (63ECA47D-F20B-4916-96C2-995009C737C4)
    # -------------------------------------------------------------------------
    out.append("================================================================================")
    out.append(f"3. ACTIVE SIMULATOR: iPad (A16) Simulator ({SIM_UDID})")
    out.append("================================================================================")

    sim_app_plists, sim_group_plists = find_simulator_containers(SIM_CONTAINERS_ROOT)
    if not sim_app_plists:
        out.append(f"=== PLIST: {SIM_CONTAINERS_ROOT}/Data/Application/*/Library/Preferences/crh.key.keyboard.plist")
        out.append("  [NO SIMULATOR APP PLIST FOUND]")
    for sp in sim_app_plists:
        out.extend(format_plist_block(sp, "iPad (A16) Simulator App Container"))

    if not sim_group_plists:
        out.append(
            f"=== PLIST: {SIM_CONTAINERS_ROOT}/Shared/AppGroup/*/Library/Preferences/group.crh.key.keyboardplus.plist"
        )
        out.append("  [NO SIMULATOR APP GROUP PLIST FOUND]")
    for gp in sim_group_plists:
        out.extend(format_plist_block(gp, "iPad (A16) Simulator App Group Container"))
        sim_group_root = gp.parent.parent.parent
        out.extend(
            format_jsonl_diagnostics(
                sim_group_root / "Diagnostics",
                "iPad (A16) Simulator App Group Diagnostics",
            )
        )
    out.append("")

    # -------------------------------------------------------------------------
    # 4. Cross-Device Key State & Sync Audit Summary
    # -------------------------------------------------------------------------
    out.append("================================================================================")
    out.append("4. CROSS-DEVICE KEY STATE & SYNC AUDIT SUMMARY")
    out.append("================================================================================")

    ipad_1739_d = load_plist_dict(ipad_air3_group_alt_plist)
    ipad_fresh_d = load_plist_dict(ipad_air3_fresh_group_plist)
    ipad_snap_d = load_plist_dict(ipad_group_plist)
    iphone_1739_d = load_plist_dict(iphone15pro_group_plist)
    iphone_snap_d = load_plist_dict(iphone_group_plist)
    sim_group_d = load_plist_dict(sim_group_plists[-1]) if sim_group_plists else {}

    audit_keys = [
        "crh.key.interfaceLanguage",
        "crh.key.cyrillicEnabled",
        "crh.key.ukrainianCyrillicLayout",
        "crh.key.ipadAbvKeyDisabled",
        "crh.key.lastRenderedPrimaryAdded",
        "crh.key.lastRenderedCyrillicAdded",
        "crh.key.lastRenderedUkrainianAdded",
        "crh.key.primaryExtensionSeen",
        "crh.key.cyrillicExtensionSeen",
        "crh.key.ukrainianExtensionSeen",
        "crh.key.cachedSysPref.GesturesEnabled",
        "crh.key.extensionConfirmedFullAccess",
        "crh.key.statsEnabled",
        "crh.key.suggestionsEnabled",
        "crh.key.wordLearningEnabled",
        "crh.key.stats.bundledLexiconSignature.v3",
        "crh.key.debug.layout",
    ]
    for k in audit_keys:
        out.append(
            f"  {k}: "
            f"iPadAir3_1739={repr(ipad_1739_d.get(k))} | "
            f"iPadAir3_1708={repr(ipad_fresh_d.get(k))} | "
            f"iPadAir3_1150={repr(ipad_snap_d.get(k))} | "
            f"iPhone15Pro_1739={repr(iphone_1739_d.get(k))} | "
            f"iPhone15Pro_1151={repr(iphone_snap_d.get(k))} | "
            f"iPadSim_A16={repr(sim_group_d.get(k))}"
        )
    out.append("")

    # -------------------------------------------------------------------------
    # 5. 5-Part Settings -> Keyboards <-> HomeView Live Synchronization Architecture
    # -------------------------------------------------------------------------
    out.append("================================================================================")
    out.append("5. 5-PART SETTINGS -> KEYBOARDS <-> HOMEVIEW LIVE SYNCHRONIZATION ARCHITECTURE")
    out.append("================================================================================")
    out.extend([
        "  [1] TIPreferencesController.preferencesChangedCallback: + Background CFPreferencesAppSynchronize(kCFPreferencesAnyApplication):",
        "      - SystemKeyboardSettings.queryTIPreferencesEnabledKeyboards(forceUpdate: true) (AppConfiguration.swift#L2106-L2150)",
        "        calls CFPreferencesAppSynchronize(kCFPreferencesAnyApplication) / CFPreferencesAppSynchronize('com.apple.Preferences') (#L2107-L2112)",
        "        and invokes preferencesChangedCallback: and synchronizePreferences on TIPreferencesController & UIKeyboardPreferencesController",
        "        singletons (#L2134-L2140) to invalidate stale in-memory TextInput caches immediately after Settings.app changes.",
        "      - SystemKeyboardSettings.enabledSystemKeyboardIdentifiers(forceRefresh:) (AppConfiguration.swift#L2315-L2498)",
        "        executes CFPreferencesAppSynchronize(kCFPreferencesAnyApplication) and CFPreferencesAppSynchronize('com.apple.Preferences')",
        "        on background queue sysPrefsRefreshQueue (#L2354-L2378) before reading Keyboards / AppleKeyboards.",
        "  [2] Authoritative AppleKeyboards Even When All 3 crh.key.* Keyboards Are OFF:",
        "      - recordAuthoritativeSource(_:alwaysAuthoritativeWhenNonEmpty: true) (AppConfiguration.swift#L2341-L2396) and",
        "        SystemKeyboardSettings.hasAuthoritativeSystemKeyboardsList() (AppConfiguration.swift#L2500-L2508) treat any non-empty",
        "        system keyboard list (e.g. ['en_US@sw=QWERTY', 'emoji']) from TIPreferencesController, com.apple.Preferences, or",
        "        .globalDomain as authoritative for both presence and absence of crh.key.* extensions.",
        "  [3] Priority 5 on Physical iOS/iPadOS Devices & Zero Union of Stale *ExtensionSeen:",
        "      - Priority 5 in SystemKeyboardSettings.enabledSystemKeyboardIdentifiers(forceRefresh:) (AppConfiguration.swift#L2408-L2420)",
        "        treats UITextInputMode.activeInputModes via activeInputModeLanguages(forceRefresh:) (#L2188-L2268) in isContainingApp",
        "        as an authoritative source (recordAuthoritativeSource(liveInputModes, alwaysAuthoritativeWhenNonEmpty: true)) when",
        "        !didReadAuthoritativeThirdPartyList on physical iOS/iPadOS devices.",
        "      - When didReadAuthoritativeThirdPartyList == true (AppConfiguration.swift#L2433-L2462, #L2270-L2310),",
        "        collected strips any crh.key.* identifier not present in authoritativeThirdPartySet and overwrites",
        "        primaryExtensionSeen / cyrillicExtensionSeen / ukrainianExtensionSeen in App Group UserDefaults to match",
        "        hasAuthLatin / hasAuthCyr / hasAuthUkr (including false on removal).",
        "  [4] Asynchronous 0.6s Polling on SystemKeyboardSettings.refreshQueue When scenePhase != .background + Darwin Observers:",
        "      - HomeView.homeLifecycleObserversView (HomeView.swift#L2363-L2383) runs Timer.publish(every: 0.6, on: .main, in: .common)",
        "        whenever scenePhase != .background (covering iPad Split View / Slide Over / Stage Manager alongside Settings.app),",
        "        refreshes activeInputModeLanguages(forceRefresh: true) on main thread, and dispatches",
        "        enabledSystemKeyboardIdentifiers(forceRefresh: true) asynchronously on SystemKeyboardSettings.refreshQueue before",
        "        updating refreshCyrillicStatus(force: true) on DispatchQueue.main, backed by Darwin observers in",
        "        HomeView.registerStatsSyncObserverIfNeeded() (HomeView.swift#L2677-L2695).",
        "  [5] Direct Settings -> Keyboards Launch on HomeView Switch Tap (Zero OnboardingView Modal):",
        "      - Tapping any of the 3 layout switches or row titles in HomeView (bentoStandardLayoutTile at HomeView.swift#L667,",
        "        abBentoLayoutsSection at #L1406 & #L1437, standardLayoutRowContent at #L4509 & #L4537, cyrillicLayoutsSection at #L4609 & #L4640)",
        "        directly invokes Self.openAppSettings() (HomeView.swift#L2912-L2922, UIApplication.openSettingsURLString) without",
        "        presenting OnboardingView.",
    ])

    OUTPUT_TXT.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Wrote {len(out)} lines ({OUTPUT_TXT.stat().st_size} bytes) to {OUTPUT_TXT}")


if __name__ == "__main__":
    main()

