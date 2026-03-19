/* global global */

import St from 'gi://St';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const ENABLED_OPACITY = 255;
const DISABLED_OPACITY = 90;

class MouseToggleIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'MouseToggle');

        this._icon = new St.Icon({
            icon_name: 'input-mouse-symbolic',
            style_class: 'system-status-icon',
        });

        this.add_child(this._icon);
        this.setDisabled(false);
    }

    setDisabled(disabled) {
        this._icon.opacity = disabled ? DISABLED_OPACITY : ENABLED_OPACITY;
    }
}

export default class MouseToggleExtension extends Extension {
    constructor(metadata) {
        super(metadata);
        this._indicator = null;
        this._capturedEventId = 0;
        this._mouseDisabled = false;
    }

    enable() {
        this._indicator = new MouseToggleIndicator();

        this._indicator.connect('button-press-event', () => {
            this._toggleMouse();
            return Clutter.EVENT_STOP;
        });

        // Add icon to the left box of the top panel
        Main.panel.addToStatusArea('mouse-toggle', this._indicator, 0, 'left');

        this._capturedEventId = global.stage.connect('captured-event', (_actor, event) =>
            this._onCapturedEvent(event)
        );
    }

    disable() {
        if (this._capturedEventId) {
            global.stage.disconnect(this._capturedEventId);
            this._capturedEventId = 0;
        }

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }

        this._mouseDisabled = false;
    }

    _toggleMouse() {
        this._mouseDisabled = !this._mouseDisabled;

        if (this._indicator) {
            this._indicator.setDisabled(this._mouseDisabled);
        }
    }

    _onCapturedEvent(event) {
        if (!this._mouseDisabled) {
            return Clutter.EVENT_PROPAGATE;
        }

        const type = event.type();

        if (
            type !== Clutter.EventType.MOTION &&
            type !== Clutter.EventType.BUTTON_PRESS &&
            type !== Clutter.EventType.BUTTON_RELEASE &&
            type !== Clutter.EventType.SCROLL &&
            type !== Clutter.EventType.ENTER &&
            type !== Clutter.EventType.LEAVE
        ) {
            return Clutter.EVENT_PROPAGATE;
        }

        const [x, y] = event.get_coords();
        const target = global.stage.get_actor_at_pos(Clutter.PickMode.ALL, x, y);

        if (this._indicator && target && (target === this._indicator || this._indicator.contains(target))) {
            // Allow events on the toggle button itself so it can be re-enabled
            return Clutter.EVENT_PROPAGATE;
        }

        // Block pointer events everywhere else
        return Clutter.EVENT_STOP;
    }
}

