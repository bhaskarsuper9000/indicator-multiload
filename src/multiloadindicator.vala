/******************************************************************************
 * Copyright (C) 2011  Michael Hofmann <mh21@piware.de>                       *
 *                                                                            *
 * This program is free software; you can redistribute it and/or modify       *
 * it under the terms of the GNU General Public License as published by       *
 * the Free Software Foundation; either version 3 of the License, or          *
 * (at your option) any later version.                                        *
 *                                                                            *
 * This program is distributed in the hope that it will be useful,            *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 * GNU General Public License for more details.                               *
 *                                                                            *
 * You should have received a copy of the GNU General Public License along    *
 * with this program; if not, write to the Free Software Foundation, Inc.,    *
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.                *
 ******************************************************************************/

public class MultiLoadIndicator : Object {
    private uint currenticonindex;
    private uint lasticonwidth;
    private TimeoutSource timeout;
    private AppIndicator.Indicator indicator;
    private Providers providers;
    private Gtk.MenuItem[] menuitems;
    private bool menuset;

    public string icondirectory {get; construct; }
    public int indicator_index { get; set; }
    public uint height { get; set; }
    public uint width { get; set; }
    public uint speed { get; set; }
    public MenuModel menumodel { get; private set; }
    public MenuModel labelmodel { get; private set; }
    public Gtk.Menu menu { get; set; }
    public GraphModels graphmodels { get; set; }

    public MultiLoadIndicator(string icondirectory, Providers providers) {
        Object(icondirectory: icondirectory);
        this.providers = providers;
        this.menumodel = new MenuModel(providers);
        this.labelmodel = new MenuModel(providers);
    }

    // Needs to be called before destruction to break the reference cycle from the timeout source
    public void destroy() {
        if (this.timeout == null)
            return;
        this.timeout.destroy();
        this.timeout = null;
    }

    construct {
        DirUtils.create(this.icondirectory, 0777);

        this.iconwritedummy();
        this.indicator = new AppIndicator.Indicator.with_path("multiload", "image-missing",
                AppIndicator.IndicatorCategory.SYSTEM_SERVICES, this.icondirectory);

        this.indicator.scroll_event.connect((delta, direction) => {
                var index = this.indicator_index;
                if (direction == Gdk.ScrollDirection.DOWN)
                    index += delta;
                else if (direction == Gdk.ScrollDirection.UP)
                    index -= delta;
                if (index >= this.labelmodel.expressions.length)
                    index = this.labelmodel.expressions.length - 1;
                if (index < -1)
                    index = -1;
                this.indicator_index = index;
            });

        this.notify["indicator-index"].connect(() => {
                // update directly so scrolling works as expected
                if (this.indicator.get_status() == AppIndicator.IndicatorStatus.ACTIVE)
                    this.updateviews();
            });
        this.notify["speed"].connect(() => {
                if (this.timeout != null)
                    this.timeout.destroy();
                if (this.speed == 0) {
                    this.timeout = null;
                    return;
                }
                if (this.speed % 1000 == 0)
                    this.timeout = new TimeoutSource.seconds(this.speed / 1000);
                else
                    this.timeout = new TimeoutSource(this.speed);
                this.timeout.attach(null);
                this.timeout.set_callback(() => {
                        this.updateall();
                        return true;
                    });
            });
    }

    ~MultiLoadIndicator() {
        FileUtils.remove(this.iconpath(0));
        FileUtils.remove(this.iconpath(1));
        DirUtils.remove(this.icondirectory);
    }

    public void updateall() {
        stdout.printf("\n");
        this.updateproviders();
        this.updatemodels();
        this.updateviews();
    }

    private void updateproviders() {
        this.providers.update();
    }

    private void updatemodels() {
        this.labelmodel.update();
        this.menumodel.update();
        this.graphmodels.update(this.providers, this.width);
    }

    private void updateviews() {
        this.updatelabelview();
        this.updatemenuview();
        this.updategraphsview();

        // ready if both a menu and graphs/a label are available
        if (this.menu != null && this.graphmodels != null) {
            // prevent an indicator without icon and text
            if ((this.indicator.get_icon().length == 0) &&
                (this.indicator.label == null || this.indicator.label.length == 0))
                this.indicator.set_label("indicator-multiload", "indicator-multiload");
            this.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE);
        } else {
            this.indicator.set_status(AppIndicator.IndicatorStatus.PASSIVE);
        }
    }

    private void updatemenuview() {
        if (this.menu == null)
            return;

        uint menu_position = 2;
        var length = this.menumodel.expressions.length;
        for (uint j = 0; j < length; ++j) {
            Gtk.MenuItem item;
            if (j < this.menuitems.length) {
                item = this.menuitems[j];
            } else {
                item = new Gtk.MenuItem();
                item.visible = true;
                this.menu.insert(item, (int)menu_position);
                this.menuitems += item;
            }
            item.label = this.menumodel.label(j);
            ++menu_position;
        }
        if (length != this.menuitems.length) {
            for (uint j = length, jsize = this.menuitems.length; j < jsize; ++j)
                menuitems[j].destroy();
            this.menuitems = this.menuitems[0:length];
        }
        if (!this.menuset) {
            this.indicator.set_menu(this.menu);
            this.menuset = true;
        }
    }

    private void updatelabelview() {
        var indicatorcount = this.labelmodel.expressions.length;
        var indicatorlabel = 0 <= this.indicator_index &&
            this.indicator_index < indicatorcount ?
            this.labelmodel.label(this.indicator_index) : "";
        var indicatorguide = 0 <= this.indicator_index &&
            this.indicator_index < indicatorcount ?
            this.labelmodel.guide(this.indicator_index) : "";
        this.indicator.set_label(indicatorlabel, indicatorguide);
    }

    private void updategraphsview() {
        this.indicator.set_icon(this.iconwrite());
        // fix icon size if using the fallback GtkStatusIcon
        foreach (var toplevel in Gtk.Window.list_toplevels()) {
            if (toplevel.get_type().name() != "GtkTrayIcon" || !(toplevel is Gtk.Container))
                continue;
            ((Gtk.Container) toplevel).foreach((w) => {
                if (!(w is Gtk.Image))
                    return;
                ((Gtk.Image) w).pixel_size = (int) uint.max(this.lasticonwidth, this.height);
            });
        }
    }

    private string iconname(uint index) {
        return @"indicator-multiload-graphs-$index";
    }

    private string iconpath(uint index) {
        return Path.build_filename(this.icondirectory, this.iconname(index) + ".png");
    }

    // Create dummy icons because the availability of icons is cached per theme
    private void iconwritedummy() {
        var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, 1, 1);
        surface.write_to_png(this.iconpath(0));
        surface.write_to_png(this.iconpath(1));
    }

    private string iconwrite() {
        this.lasticonwidth = 0;
        if (this.graphmodels == null)
            return "";
        uint count = 0;
        foreach (var graphmodel in this.graphmodels.graphmodels)
            if (graphmodel.enabled)
                ++count;
        if (count == 0)
            return "";

        this.lasticonwidth = (int) (count * (this._width + 2)) - 2;
        var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,
                (int) this.lasticonwidth, (int) this.height);
        var ctx = new Cairo.Context(surface);
        ctx.set_antialias(Cairo.Antialias.NONE);
        ctx.set_line_width(1);
        uint offset = 0;
        foreach (var graphmodel in this.graphmodels.graphmodels) {
            if (!graphmodel.enabled)
                continue;
            graphmodel.set_source_color(ctx);
            ctx.rectangle(offset, 0, this._width, this.height);
            ctx.fill();
            var tracemodels = graphmodel.tracemodels;
            var values = new double[tracemodels.length, this._width];
            var scale = graphmodel.scale;
            for (uint j = 0, jsize = values.length[0]; j < jsize; ++j) {
                var enabled = tracemodels[j].enabled;
                unowned double[] tracedata = tracemodels[j].values;
                for (uint i = 0, isize = values.length[1]; i < isize; ++i)
                    values[j, i] = (j > 0 ? values[j - 1, i] : 0) + (enabled ? tracedata[i] : 0) / scale;
            }

            for (int j = values.length[0] - 1; j >= 0; --j) {
                Gdk.cairo_set_source_color(ctx, graphmodel.tracemodels[j].color);
                for (uint i = 0, isize = values.length[1]; i < isize; ++i) {
                    // the baseline is outside the canvas
                    ctx.move_to(0.5 + offset + i, this.height + 0.5);
                    ctx.line_to(0.5 + offset + i,
                            this.height + 0.5 - this.height * values[j, i]);
                }
                ctx.stroke();
            }
            offset += this._width + 2;
        }
        this.currenticonindex = 1 - this.currenticonindex;
        surface.write_to_png(this.iconpath(this.currenticonindex));
        return this.iconname(this.currenticonindex);
    }
}
