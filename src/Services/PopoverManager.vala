/*
 * Copyright (c) 2011-2015 Ikey Doherty <ikey@solus-project.com>
 *               2026 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 */

public class Wingpanel.Services.PopoverManager : Object {
    public bool indicator_open { get; private set; default = false; }

    private Gtk.Popover popover;

    private Wingpanel.Widgets.IndicatorEntry? _current_indicator = null;
    public Wingpanel.Widgets.IndicatorEntry? current_indicator {
        get {
            return _current_indicator;
        }

        set {
            if (value == null && _current_indicator == null) {
                return;
            }

            if (_current_indicator == null && value != null) { // First open
                _current_indicator = value;
                indicator_open = true;
            } else if (value == null && _current_indicator != null) { // Close requested
                release_focus ();
                _current_indicator.unset_state_flags (CHECKED);
                _current_indicator.display_widget.has_tooltip = true;
                _current_indicator.base_indicator.closed ();
                _current_indicator = null;
                popover.popdown ();
                indicator_open = false;
            } else { // Switch
                release_focus ();
                _current_indicator.unset_state_flags (CHECKED);
                _current_indicator.display_widget.has_tooltip = true;
                _current_indicator.base_indicator.closed ();
                _current_indicator = value;
                popover.unparent ();
            }

            if (_current_indicator != null) {
                popover.child = _current_indicator.indicator_widget;
                popover.set_parent (_current_indicator);
                popover.popup ();

                _current_indicator.set_state_flags (CHECKED, false);
                _current_indicator.display_widget.has_tooltip = false;
                _current_indicator.base_indicator.opened ();
            }
        }
    }

    construct {
        popover = new Gtk.Popover () {
            has_arrow = false,
            position = BOTTOM,
            autohide = false
        };
        popover.add_css_class ("indicator");

        popover.closed.connect (() => {
            current_indicator = null;
            popover.unparent ();
        });
    }

    /*
     * Drop keyboard focus from the popover while it is still parented to the indicator.
     * Otherwise GTK only defers a focus move to after the next paint: the panel's ancestors
     * of the popover keep their :focus-within/:focus-visible state (or focus jumps to the
     * first indicator), and the stylesheet's flowboxchild:focus-visible background sticks.
     */
    private void release_focus () {
        unowned var root = popover.get_root ();
        if (root == null) {
            return;
        }

        unowned var focus = root.get_focus ();
        if (focus != null && (focus == popover || focus.is_ancestor (popover))) {
            root.set_focus (null);
        }
    }
}
