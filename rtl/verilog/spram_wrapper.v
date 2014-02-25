// Single-Port SRAM Wrapper
//
// Try auto generate the SRAM by EDA tools but not use the vendors' primitive.
//
// Author: Xiongfei Guo <xfguo@credosemi.com>
//
// Support Devices:
//      * Spartan 6 Block RAM (follow the Xilinx ISE language templete).
//
// TODO: support more deivce

module spram_bw_wrapper #(
    parameter
        dw = 32,
        aw = 32,
        col_w = 8,
        nb_w = dw/col_w,
        mem_size_bytes = 32'h0000_0400
) (
    input               clk_i,
    input               rst_i,

    input   [aw-1:0]    adr_i,
    input               ce_i,
    input   [nb_w-1:0]  we_i,
    input   [dw-1:0]    dat_i,
    output  [dw-1:0]    dat_o
);
    // Important!
    // This is the recommended coding style to describe read-first synchronized byte-write enable functionality for Virtex-6,
    // Spartan-6 and newer device families. This coding style is not supported for older device families. In that case, please refer
    // to the corresponding 2-bit and 4-bit write enable templates for device families before Virtex-6 and Spartan-6.
    //
    
    reg     [dw-1:0]    dout_r;
    reg	    [dw-1:0]    mem [0:mem_size_bytes/nb_w-1];

    //  The forllowing code is only necessary if you wish to initialize the RAM 
    //  contents via an external file (use $readmemb for binary data)
    // initial
    //    $readmemh("<data_file_name>", <mem>, <begin_adr_i>, <end_adr_i>);

    always @(posedge clk_i)
    begin 
       dout_r <= mem[adr_i];
    end
    assign dat_o = dout_r;

    generate
    genvar i;
       for (i = 0; i < nb_w; i = i+1)
       begin:sram_bw
          always @(posedge clk_i)
          begin  
             if (we_i[i]) 
                mem[adr_i][(i+1)*col_w-1:i*col_w]
                  <= dat_i[(i+1)*col_w-1:i*col_w];
          end
       end
    endgenerate
endmodule
