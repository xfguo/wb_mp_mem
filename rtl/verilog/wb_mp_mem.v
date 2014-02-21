module wb_mp_mem #(
    parameter
        dw = 32,
        aw = 32,
        col_w = 8,
        nb_w = dw/col_w,
        mem_size_bytes = 32'h0000_0400,
        mem_adr_width = 10
) (
    // Wishbone master 0
    // Inputs
    input   [aw-1:0]    wbm0_adr_i, 
    input   [1:0]       wbm0_bte_i, 
    input   [2:0]       wbm0_cti_i, 
    input               wbm0_cyc_i, 
    input   [dw-1:0]    wbm0_dat_i, 
    input   [3:0]       wbm0_sel_i, 
    input               wbm0_stb_i, 
    input               wbm0_we_i,
    // Outputs
    output              wbm0_ack_o, 
    output              wbm0_err_o, 
    output              wbm0_rty_o, 
    output  [dw-1:0]    wbm0_dat_o,
    
    // Wishbone master 1
    // Inputs
    input   [aw-1:0]    wbm1_adr_i, 
    input   [1:0]       wbm1_bte_i, 
    input   [2:0]       wbm1_cti_i, 
    input               wbm1_cyc_i, 
    input   [dw-1:0]    wbm1_dat_i, 
    input   [3:0]       wbm1_sel_i, 
    input               wbm1_stb_i, 
    input               wbm1_we_i,
    // Outputs
    output              wbm1_ack_o, 
    output              wbm1_err_o, 
    output              wbm1_rty_o, 
    output  [dw-1:0]    wbm1_dat_o,

    // Wishbone master 2
    // Inputs
    input   [aw-1:0]    wbm2_adr_i, 
    input   [1:0]       wbm2_bte_i, 
    input   [2:0]       wbm2_cti_i, 
    input               wbm2_cyc_i, 
    input   [dw-1:0]    wbm2_dat_i, 
    input   [3:0]       wbm2_sel_i, 
    input               wbm2_stb_i, 
    input               wbm2_we_i,
    // Outputs              
    output              wbm2_ack_o, 
    output              wbm2_err_o, 
    output              wbm2_rty_o, 
    output  [dw-1:0]    wbm2_dat_o,

    // Clock, reset
    input               wb_clk_i, 
    input               wb_rst_i
);

localparam nm = 3; // number of master



reg     [2:0]       master_sel;

wire    [mem_adr_width-1:0]    mem_adr;
wire                mem_ce;
reg     [nb_w-1:0]  mem_we;
wire    [dw-1:0]    mem_din;
wire    [dw-1:0]    mem_dout;

reg     [nm-1:0]    wbm_ack_r;
wire    [nm-1:0]    wbm_err;
wire    [nm-1:0]    wbm_rty;

wire    [2:0]       wbm_we;
wire    [2:0]       wbm_cycstb;
reg     [2:0]       master_sel_last_r;

wire    [mem_adr_width-1:0]    wbm_adr_arr [0:nm-1];
wire    [dw-1:0]    wbm_din_arr [0:nm-1];
wire    [3:0]       wbm_sel_arr [0:nm-1];

assign wbm0_dat_o = mem_dout;
assign wbm1_dat_o = mem_dout;
assign wbm2_dat_o = mem_dout;


assign mem_ce = 1'b1;

assign wbm_we = {
            wbm2_we_i, 
            wbm1_we_i, 
            wbm0_we_i
        };

assign wbm_cycstb = {
            wbm2_cyc_i & wbm2_stb_i,
            wbm1_cyc_i & wbm1_stb_i,
            wbm0_cyc_i & wbm0_stb_i
        };

always @(posedge wb_clk_i or posedge wb_rst_i)
    if (wb_rst_i)
        master_sel_last_r <= 3'd1;
    else if (master_sel != 'd0)
        master_sel_last_r <= master_sel;
    else
        master_sel_last_r <= master_sel_last_r;

always @(*)
begin
    if (master_sel & wbm_we)
        mem_we = wbm_sel_arr[sel_encode(master_sel)];
    else
        mem_we = 'd0;
end

assign wbm_adr_arr[0] = wbm0_adr_i[mem_adr_width-1:0];
assign wbm_adr_arr[1] = wbm1_adr_i[mem_adr_width-1:0];
assign wbm_adr_arr[2] = wbm2_adr_i[mem_adr_width-1:0];

assign wbm_din_arr[0] = wbm0_dat_i;
assign wbm_din_arr[1] = wbm1_dat_i;
assign wbm_din_arr[2] = wbm2_dat_i;

assign wbm_sel_arr[0] = wbm0_sel_i;
assign wbm_sel_arr[1] = wbm1_sel_i;
assign wbm_sel_arr[2] = wbm2_sel_i;

function sel_encode;
    input   [nm-1:0]    sel;
    integer i;
    begin
        sel_encode = 0;
        for (i = 0;i < nm;i=i+1) begin
            if (sel == (1 << i))
                sel_encode = i;
        end
    end
endfunction

assign mem_adr = wbm_adr_arr[sel_encode(master_sel)];
assign mem_din = wbm_din_arr[sel_encode(master_sel)];

function mem_arb;
    input   [nm-1:0]   last_sel;
    input   [nm-1:0]   reqs;
    reg     [nm-1:0]   ignore;
    integer i;
    begin
        ignore[nm-1:1] = last_sel[nm-1:1] - 'd1;
        ignore[0] = 1'b0;
    
        mem_arb = ((ignore & reqs) == 'd0) && (reqs[0] == 1'b1);
    end
endfunction

generate
genvar arb_i;
    always @(*)
        master_sel[0] = mem_arb(master_sel_last_r, wbm_cycstb);
    for (arb_i = 1;arb_i < nm;arb_i=arb_i+1) begin:arb_block
        always @(*)
            master_sel[arb_i] = mem_arb
                                (
                                    {master_sel_last_r[arb_i-1:0], master_sel_last_r[nm-1:arb_i]},
                                    {wbm_cycstb[arb_i-1:0], wbm_cycstb[nm-1:arb_i]}
                                ); // always make myself as the last
    end
endgenerate

assign wbm0_ack_o = wbm_ack_r[0];
assign wbm1_ack_o = wbm_ack_r[1];
assign wbm2_ack_o = wbm_ack_r[2];

always @(posedge wb_clk_i or posedge wb_rst_i)
    if (wb_rst_i)
        wbm_ack_r <= 'd0;
    else
        wbm_ack_r <= ~wbm_ack_r & master_sel;

assign wbm0_rty_o = wbm_rty[0];
assign wbm1_rty_o = wbm_rty[1];
assign wbm2_rty_o = wbm_rty[2];

assign wbm_rty = 'd0;

assign wbm0_err_o = wbm_err[0];
assign wbm1_err_o = wbm_err[1];
assign wbm2_err_o = wbm_err[2];

assign wbm_err = 'd0;

spram_bw_wrapper spram_bw (
    .clk_i (wb_clk_i),
    .rst_i (wb_rst_i),

    .adr_i (mem_adr),
    .ce_i  (mem_ce),
    .we_i  (mem_we),
    .dat_i (mem_din),
    .dat_o (mem_dout)
);
defparam spram_bw.dw = dw;
defparam spram_bw.aw = mem_adr_width;
defparam spram_bw.col_w = col_w;
defparam spram_bw.nb_w = nb_w;
defparam spram_bw.mem_size_bytes = mem_size_bytes;
endmodule
