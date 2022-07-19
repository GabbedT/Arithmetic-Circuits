`ifndef CONFIGURATION_INCLUDE_SV
    `define CONFIGURATION_INCLUDE_SV

package configuration_pkg;

    /* Target ASIC synthesis */
    `define ASIC
    
    /* Target FPGA synthesis */
    `define FPGA

    /* Enable Floating Point Unit and F - D extensions */
    `define FPU

    /* Enable cache system */
    `define CACHE
    
    /* Enable asyncronous reset */
    `define ASYNC

    localparam XLEN = 32;

endpackage : configuration_pkg

import configuration_pkg::*;

`endif 