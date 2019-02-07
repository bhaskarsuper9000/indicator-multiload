/******************************************************************************
 * Copyright (C) 2018 Yukai Miao <tjumyk@gmail.com>                           *
 * Adapted for Multi GPU by Oscar Bandy <bhaskarsuper9000@gmail.com>
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

public class GpuProvider : Provider {
    private static uint64 n_gpu;

    private static string[] fields() {
        try {
            string[] templates = {"util", "memtotal", "memused", "memfree"};
            string[] spawn_args = {"nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"};
            string spawn_stdout, spawn_stderr;
            int spawn_status;
            Process.spawn_sync(null, spawn_args, null, SpawnFlags.SEARCH_PATH, null, out spawn_stdout, out spawn_stderr, out spawn_status);
            
            string[] rows = spawn_stdout.strip().split("\n");
            n_gpu = rows.length;
            
            string[] result = new string[(n_gpu + 1) * 4];
            for (uint j = 0; j < 4; ++j) {
                var template = templates[j];
                result[j] = template;
                for (uint i = 0; i < n_gpu; ++i)
                    result[(i + 1) * 4 + j] = @"gpu$i.$template";
            }
            return result;
                
        } catch (SpawnError e) {
            stdout.printf ("Error: %s\n", e.message);
            string[] templates = {"util", "memtotal", "memused", "memfree"};
            return templates;
        }
    }

    public GpuProvider() {
        base("gpu", fields() , "p");
    }

    public override void update() {
	    try {
            string[] spawn_args = {"nvidia-smi", "--query-gpu=utilization.gpu,memory.total,memory.used,memory.free", "--format=csv,noheader,nounits"};
            string spawn_stdout;
            string spawn_stderr;
            int spawn_status;
            Process.spawn_sync(null, spawn_args, null, SpawnFlags.SEARCH_PATH, null, out spawn_stdout, out spawn_stderr, out spawn_status);
            string[] rows = spawn_stdout.strip().split("\n");
            double util = 0, memtot = 0, memused = 0, memfree = 0;
            for(uint r = 0; r < rows.length; ++r) {
                string[] columns = rows[r].split(", ");
                this.values[(r + 1) * 4] = double.parse(columns[0]) / 100.0;
                util += this.values[(r + 1) * 4];
                for(int i = 1 ; i < 4; ++i)
                    this.values[(r + 1) * 4 + i] = double.parse(columns[i]) * 1000000;
                memtot = this.values[(r + 1) * 4 + 1];
                memused = this.values[(r + 1) * 4 + 2];
                memfree = this.values[(r + 1) * 4 + 3];
            }

            this.values[0] = util / rows.length;
            this.values[1] = memtot;
            this.values[2] = memused;
            this.values[3] = memfree;
        } catch (SpawnError e) {
            stdout.printf ("Error: %s\n", e.message);
        }
    }
}
