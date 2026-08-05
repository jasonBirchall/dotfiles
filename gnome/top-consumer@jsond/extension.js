// Top Consumer — panel indicator for the process using the most CPU or memory.
//
// The panel shows one process; clicking opens the top five by CPU and by
// memory, and lets you switch which metric the panel tracks. That choice is
// persisted to $XDG_STATE_HOME/top-consumer/track, because the extension has
// no GSettings schema — a schema would mean shipping a compiled
// gschemas.compiled in the dotfiles repo or adding a glib-compile-schemas
// build step, and one word in a state file does the same job.
//
// CPU is sampled the way top does it: the delta in a process's jiffies over
// the refresh interval, divided by the delta in total CPU jiffies, scaled by
// the core count. So a single-threaded runaway pegging one core reads ~100%
// rather than ~6% of a 16-core machine, which is the number worth noticing.
// A lifetime average (what `ps aux` reports) would not show that at all.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const REFRESH_SECONDS = 3;
const MENU_ROWS = 5;
// Both Fedora and Ubuntu ship 4K-page kernels on x86_64 and arm64. If that
// ever changes the memory figures scale by a constant and nothing crashes.
const PAGE_SIZE = 4096;
const NAME_MAX = 14;

const decoder = new TextDecoder();

function readFile(path) {
    try {
        const [ok, bytes] = GLib.file_get_contents(path);
        return ok ? decoder.decode(bytes) : null;
    } catch {
        // Process exited between the readdir and the read — routine, not an error.
        return null;
    }
}

function formatBytes(bytes) {
    if (bytes >= 1024 ** 3)
        return `${(bytes / 1024 ** 3).toFixed(1)}G`;
    if (bytes >= 1024 ** 2)
        return `${Math.round(bytes / 1024 ** 2)}M`;
    return `${Math.round(bytes / 1024)}K`;
}

function truncate(name) {
    return name.length > NAME_MAX ? `${name.slice(0, NAME_MAX - 1)}…` : name;
}

// Samples /proc and reports per-process CPU share and resident memory.
class Sampler {
    constructor() {
        this._prevTicks = new Map();
        this._prevTotal = 0;
        this._cores = this._countCores();
    }

    _countCores() {
        const stat = readFile('/proc/stat');
        if (!stat)
            return 1;
        // Aggregate "cpu " plus one "cpuN " line per core.
        const cores = stat.split('\n').filter(l => /^cpu\d+ /.test(l)).length;
        return cores || 1;
    }

    // Sum of every field on /proc/stat's aggregate line: total jiffies across
    // all cores, idle included. The denominator for each process's share.
    _totalTicks() {
        const stat = readFile('/proc/stat');
        if (!stat)
            return 0;
        const line = stat.split('\n', 1)[0];
        return line.split(/\s+/).slice(1)
            .reduce((sum, field) => sum + (Number(field) || 0), 0);
    }

    _pids() {
        const pids = [];
        let iter;
        try {
            iter = Gio.File.new_for_path('/proc').enumerate_children(
                'standard::name', Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
        } catch {
            return pids;
        }
        try {
            let info;
            while ((info = iter.next_file(null)) !== null) {
                const name = info.get_name();
                if (/^\d+$/.test(name))
                    pids.push(name);
            }
        } finally {
            iter.close(null);
        }
        return pids;
    }

    // /proc/<pid>/stat, one line: "pid (comm) state ppid ...". comm is
    // arbitrary bytes and may contain spaces and parentheses, so the fields
    // after it are found from the LAST ')' rather than by splitting the line.
    _parseStat(text) {
        const close = text.lastIndexOf(')');
        const open = text.indexOf('(');
        if (open < 0 || close < 0 || close < open)
            return null;

        const comm = text.slice(open + 1, close);
        // Field 3 (state) onwards, so field N is at index N - 3.
        const fields = text.slice(close + 2).trim().split(/\s+/);
        const utime = Number(fields[11]);   // field 14
        const stime = Number(fields[12]);   // field 15
        const rss = Number(fields[21]);     // field 24, in pages
        if (!Number.isFinite(utime) || !Number.isFinite(stime) || !Number.isFinite(rss))
            return null;

        return {comm, ticks: utime + stime, rss};
    }

    // Returns {cpu, mem}, each an array of {name, pid, value, text} sorted
    // descending. cpu is empty on the very first call: a rate needs two
    // samples, and reporting a lifetime average in the meantime would be a
    // different measurement wearing the same label.
    sample() {
        const total = this._totalTicks();
        const totalDelta = total - this._prevTotal;
        const ticks = new Map();
        const cpu = [];
        const mem = [];

        for (const pid of this._pids()) {
            const text = readFile(`/proc/${pid}/stat`);
            if (!text)
                continue;
            const proc = this._parseStat(text);
            if (!proc)
                continue;

            ticks.set(pid, proc.ticks);

            if (proc.rss > 0) {
                const bytes = proc.rss * PAGE_SIZE;
                mem.push({name: proc.comm, pid, value: bytes, text: formatBytes(bytes)});
            }

            const prev = this._prevTicks.get(pid);
            // A pid absent last round is new; a negative delta means the pid
            // was recycled onto a different process. Neither has a rate yet.
            if (prev === undefined || totalDelta <= 0)
                continue;
            const delta = proc.ticks - prev;
            if (delta <= 0)
                continue;

            const percent = (delta / totalDelta) * 100 * this._cores;
            cpu.push({
                name: proc.comm,
                pid,
                value: percent,
                text: `${percent < 10 ? percent.toFixed(1) : Math.round(percent)}%`,
            });
        }

        // Rebuilt rather than updated, so dead pids do not accumulate.
        this._prevTicks = ticks;
        this._prevTotal = total;

        const byValue = (a, b) => b.value - a.value;
        return {cpu: cpu.sort(byValue), mem: mem.sort(byValue)};
    }
}

const Indicator = GObject.registerClass(
class TopConsumerIndicator extends PanelMenu.Button {
    _init(track, onTrackChanged) {
        super._init(0.0, 'Top Consumer');

        this._track = track;
        this._onTrackChanged = onTrackChanged;

        const box = new St.BoxLayout({style_class: 'panel-status-menu-box'});
        this._icon = new St.Icon({
            icon_name: 'utilities-system-monitor-symbolic',
            style_class: 'system-status-icon',
        });
        this._label = new St.Label({
            text: '…',
            y_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        box.add_child(this._icon);
        box.add_child(this._label);
        this.add_child(box);

        this._cpuSection = new PopupMenu.PopupMenuSection();
        this._memSection = new PopupMenu.PopupMenuSection();

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem('CPU'));
        this.menu.addMenuItem(this._cpuSection);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem('Memory'));
        this.menu.addMenuItem(this._memSection);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this._trackItems = new Map();
        for (const [metric, label] of [['cpu', 'Track CPU'], ['mem', 'Track memory']]) {
            const item = new PopupMenu.PopupMenuItem(label);
            item.connect('activate', () => this.setTrack(metric));
            this.menu.addMenuItem(item);
            this._trackItems.set(metric, item);
        }
        this._updateOrnaments();
    }

    setTrack(metric) {
        if (metric === this._track)
            return;
        this._track = metric;
        this._updateOrnaments();
        this._onTrackChanged(metric);
        if (this._last)
            this.update(this._last);
    }

    _updateOrnaments() {
        for (const [metric, item] of this._trackItems) {
            item.setOrnament(metric === this._track
                ? PopupMenu.Ornament.DOT
                : PopupMenu.Ornament.NONE);
        }
    }

    _fill(section, rows) {
        section.removeAll();
        if (!rows.length) {
            const empty = new PopupMenu.PopupMenuItem('No data yet', {reactive: false});
            section.addMenuItem(empty);
            return;
        }
        for (const row of rows.slice(0, MENU_ROWS)) {
            // comm is not unique — a browser or an editor shows up once per
            // child process — so the menu carries the pid even though the
            // panel does not have room for it.
            const label = `${truncate(row.name)} (${row.pid})`;
            const item = new PopupMenu.PopupMenuItem(label, {reactive: false});
            item.label.x_expand = true;
            item.add_child(new St.Label({
                text: row.text,
                y_expand: true,
                y_align: Clutter.ActorAlign.CENTER,
            }));
            section.addMenuItem(item);
        }
    }

    update(data) {
        this._last = data;
        const rows = this._track === 'cpu' ? data.cpu : data.mem;
        const top = rows[0];
        this._label.text = top ? `${truncate(top.name)} ${top.text}` : '…';
        this._fill(this._cpuSection, data.cpu);
        this._fill(this._memSection, data.mem);
    }
});

export default class TopConsumerExtension extends Extension {
    enable() {
        this._sampler = new Sampler();
        this._indicator = new Indicator(
            this._readTrack(), metric => this._writeTrack(metric));
        Main.panel.addToStatusArea(this.uuid, this._indicator, 0, 'right');

        // Prime the tick counters so the first visible reading, one interval
        // from now, is a real rate.
        this._sampler.sample();
        this._timeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, REFRESH_SECONDS, () => {
            this._indicator.update(this._sampler.sample());
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        if (this._timeout) {
            GLib.Source.remove(this._timeout);
            this._timeout = null;
        }
        this._indicator?.destroy();
        this._indicator = null;
        this._sampler = null;
    }

    _statePath() {
        return GLib.build_filenamev([GLib.get_user_state_dir(), 'top-consumer', 'track']);
    }

    _readTrack() {
        const value = readFile(this._statePath())?.trim();
        return value === 'mem' ? 'mem' : 'cpu';
    }

    _writeTrack(metric) {
        const path = this._statePath();
        try {
            GLib.mkdir_with_parents(GLib.path_get_dirname(path), 0o755);
            GLib.file_set_contents(path, metric);
        } catch (e) {
            console.error(`top-consumer: could not save track preference: ${e}`);
        }
    }
}
