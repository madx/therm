/*    Copyright (c) 2014 François Vaux
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Heavily based on taterm by Thomas Weißschuh
 * https://github.com/t-8ch/taterm
 */

using GLib;
using Gtk;
using Vte;
using Pango;

static const string APPLICATION_ID = "org.yapok.Therm2";

public static int main(string[] args)
{
  return new Therm().run();
}

class Therm : Gtk.Application {

  string cwd = GLib.Environment.get_home_dir();

  protected Pango.FontDescription font;
  protected Gdk.RGBA[]  palette;
  protected Gdk.RGBA    foreground_color;
  protected Gdk.RGBA    background_color;
  protected GLib.Regex  uri_regex;
  protected int         margin_size;
  protected string      word_chars;

  public Therm() {
    Object(application_id: APPLICATION_ID);

    reconfigure();

    activate.connect(() => {
      var instance = new Instance(this, cwd);
      add_window(instance);

      instance.cwd_changed.connect(() => {
        this.cwd = instance.cwd;
      });
    });
  }

  protected void reconfigure() {
    // TODO: watch for configuration changes and make them instantly effective.
    var settings = new GLib.Settings("org.yapok.Therm");

    // Set the font
    var font_string = settings.get_string("font");
    font = Pango.FontDescription.from_string(font_string);

    // Set fore- and background
    foreground_color.parse(settings.get_string("foreground-color"));
    background_color.parse(settings.get_string("background-color"));

    // Set the color palette
    var hex_palette = settings.get_strv("palette");
    for (int i = 0; i < 16; i++) {
      Gdk.RGBA color = Gdk.RGBA();
      color.parse(hex_palette[i]);
      palette += color;
    }

    // Set URI Regex
    var regex_string = settings.get_string("uri-regex");
    try {
      var regex_flags = RegexCompileFlags.CASELESS | RegexCompileFlags.OPTIMIZE;
      uri_regex = new GLib.Regex(regex_string, regex_flags);
    } catch (RegexError err) {
      GLib.assert_not_reached();
    }

    // Set inner margin
    margin_size = settings.get_int("margin-size");

    // Set word chars
    word_chars = settings.get_string("word-chars");
  }

  class Instance : Gtk.Window
  {
    public  string       cwd;
    private Vte.Terminal term;
    private GLib.Pid     shell;
    private string[]     targs;

    public signal void cwd_changed(string cwd);

    public Instance(Therm app, string cwd)
    {
      this.cwd = cwd;

      term = new Terminal(app);

      set_border_width(app.margin_size);
      override_background_color(StateFlags.NORMAL, app.background_color);

      has_resize_grip = false;
      targs = { Vte.get_user_shell() };

      try {
        term.fork_command_full(0, cwd, targs, null, 0, null, out shell);
      } catch (Error err) {
        stderr.printf(err.message);
      }

      focus_in_event.connect(() => {
        cwd_changed(this.cwd);
        urgency_hint = false;
        return false;
      });

      term.child_exited.connect(() => {
        destroy();
      });

      term.beep.connect(() => {
        urgency_hint = true;
      });

      term.window_title_changed.connect(() => {
        var newwd = Utils.cwd_of_pid(shell);

        if (newwd != this.cwd) {
          this.cwd = newwd;
          cwd_changed(newwd);
        }
      });

      add(term);
      show_all();
    }
  }

  class Terminal : Vte.Terminal
  {
    private Therm app;
    private string match_uri = null;

    public Terminal(Therm app)
    {
      this.app = app;
      set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
      set_scrollback_lines(-1);
      pointer_autohide = true;
      set_font(app.font);
      set_colors_rgba(app.foreground_color, app.background_color, app.palette);
      set_word_chars(app.word_chars);

      button_press_event.connect(handle_button);
      match_add_gregex(app.uri_regex, 0);
    }

    private bool handle_button(Gdk.EventButton event)
    {
      if (event.button == Gdk.BUTTON_PRIMARY) {
        check_regex(
            (long) event.x/get_char_width(),
            (long) event.y/get_char_height()
        );
      }
      /* continue calling signalhandlers, why should we stop? */
      /* TODO change to GDK_EVENT_PROPAGATE, when .vapi provides it */
      return false;
    }

    private void check_regex(long x_pos, long y_pos)
    {
      int tag;
      match_uri = match_check(x_pos, y_pos, out tag);

      if (match_uri != null) {
        try {
          Gtk.show_uri(null, match_uri, Gdk.CURRENT_TIME);
        } catch (Error err) {
          stderr.printf(err.message);
        } finally {
          match_uri = null;
        }
      }
    }
  }

  class Utils
  {
    public static string cwd_of_pid(GLib.Pid pid)
    {
      var cwdlink = @"/proc/$((int)pid)/cwd";
      try {
        return GLib.FileUtils.read_link(cwdlink);
      } catch (FileError err) {
        stderr.printf(err.message);
      }
      return GLib.Environment.get_home_dir();
    }
  }
}
