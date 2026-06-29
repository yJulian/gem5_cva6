// Copyright 2026 Antigravity
// Description: Top-level wrapper for CVA6 simulation inside gem5.
//              Flattens AXI transaction structs into individual scalar signals.

module cva6_top import ariane_pkg::*; (
  input  logic                         clk_i,
  input  logic                         rst_ni,
  input  logic [63:0]                  boot_addr_i,
  input  logic [63:0]                  hart_id_i,
  input  logic [1:0]                   irq_i,
  input  logic                         ipi_i,
  input  logic                         time_irq_i,
  input  logic                         debug_req_i,
  
  // AXI AW Channel (out)
  output logic                         noc_req_aw_valid_o,
  output logic [ariane_axi::IdWidth-1:0] noc_req_aw_id_o,
  output logic [63:0]                  noc_req_aw_addr_o,
  output logic [7:0]                   noc_req_aw_len_o,
  output logic [2:0]                   noc_req_aw_size_o,
  input  logic                         noc_resp_aw_ready_i,

  // AXI W Channel (out)
  output logic                         noc_req_w_valid_o,
  output logic [63:0]                  noc_req_w_data_o,
  output logic                         noc_req_w_last_o,
  input  logic                         noc_resp_w_ready_i,

  // AXI B Channel (in)
  input  logic                         noc_resp_b_valid_i,
  input  logic [ariane_axi::IdWidth-1:0] noc_resp_b_id_i,
  input  logic [1:0]                   noc_resp_b_resp_i,
  output logic                         noc_req_b_ready_o,

  // AXI AR Channel (out)
  output logic                         noc_req_ar_valid_o,
  output logic [ariane_axi::IdWidth-1:0] noc_req_ar_id_o,
  output logic [63:0]                  noc_req_ar_addr_o,
  output logic [7:0]                   noc_req_ar_len_o,
  output logic [2:0]                   noc_req_ar_size_o,
  output logic [2:0]                   noc_req_ar_prot_o,
  input  logic                         noc_resp_ar_ready_i,

  // AXI R Channel (in)
  input  logic                         noc_resp_r_valid_i,
  input  logic [ariane_axi::IdWidth-1:0] noc_resp_r_id_i,
  input  logic [63:0]                  noc_resp_r_data_i,
  input  logic                         noc_resp_r_last_i,
  input  logic [1:0]                   noc_resp_r_resp_i,
  output logic                         noc_req_r_ready_o,

  // Debug Channels
  output logic                         ebreak_o,
  output logic                         illegal_instr_o,
  output logic [63:0]                  program_counter
);

  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

  ariane_axi::req_t  noc_req_o;
  ariane_axi::resp_t noc_resp_i;

  // Unpack outputs from core
  assign noc_req_aw_valid_o = noc_req_o.aw_valid;
  assign noc_req_aw_id_o    = noc_req_o.aw.id;
  assign noc_req_aw_addr_o  = noc_req_o.aw.addr;
  assign noc_req_aw_len_o   = noc_req_o.aw.len;
  assign noc_req_aw_size_o  = noc_req_o.aw.size;

  assign noc_req_w_valid_o  = noc_req_o.w_valid;
  assign noc_req_w_data_o   = noc_req_o.w.data;
  assign noc_req_w_last_o   = noc_req_o.w.last;

  assign noc_req_b_ready_o  = noc_req_o.b_ready;

  assign noc_req_ar_valid_o = noc_req_o.ar_valid;
  assign noc_req_ar_id_o    = noc_req_o.ar.id;
  assign noc_req_ar_addr_o  = noc_req_o.ar.addr;
  assign noc_req_ar_len_o   = noc_req_o.ar.len;
  assign noc_req_ar_size_o  = noc_req_o.ar.size;
  assign noc_req_ar_prot_o  = noc_req_o.ar.prot;

  assign noc_req_r_ready_o  = noc_req_o.r_ready;

  // Pack inputs to core
  always_comb begin
    noc_resp_i = '0;
    noc_resp_i.aw_ready = noc_resp_aw_ready_i;
    noc_resp_i.w_ready  = noc_resp_w_ready_i;
    noc_resp_i.b_valid  = noc_resp_b_valid_i;
    noc_resp_i.b.id     = noc_resp_b_id_i;
    noc_resp_i.b.resp   = noc_resp_b_resp_i;
    noc_resp_i.ar_ready = noc_resp_ar_ready_i;
    noc_resp_i.r_valid  = noc_resp_r_valid_i;
    noc_resp_i.r.id     = noc_resp_r_id_i;
    noc_resp_i.r.data   = noc_resp_r_data_i;
    noc_resp_i.r.last   = noc_resp_r_last_i;
    noc_resp_i.r.resp   = noc_resp_r_resp_i;
  end


  ariane #(
    .CVA6Cfg ( CVA6Cfg ),
    .AxiAddrWidth ( ariane_axi::AddrWidth ),
    .AxiDataWidth ( ariane_axi::DataWidth ),
    .AxiIdWidth   ( ariane_axi::IdWidth ),
    .axi_ar_chan_t ( ariane_axi::ar_chan_t ),
    .axi_aw_chan_t ( ariane_axi::aw_chan_t ),
    .axi_w_chan_t  ( ariane_axi::w_chan_t  ),
    .noc_req_t     ( ariane_axi::req_t     ),
    .noc_resp_t    ( ariane_axi::resp_t    )
  ) i_ariane (
    .clk_i                ( clk_i                     ),
    .rst_ni               ( rst_ni                    ),
    .boot_addr_i          ( boot_addr_i[CVA6Cfg.VLEN-1:0] ),
    .hart_id_i            ( hart_id_i[CVA6Cfg.XLEN-1:0]   ),
    .irq_i                ( irq_i                     ),
    .ipi_i                ( ipi_i                     ),
    .time_irq_i           ( time_irq_i                ),
    .debug_req_i          ( debug_req_i               ),
    .rvfi_probes_o        (                           ), // open
    .noc_req_o            ( noc_req_o                 ),
    .noc_resp_i           ( noc_resp_i                )
  );

/*
  always @(posedge clk_i) begin
    if (rst_ni && (noc_req_ar_valid_o || noc_resp_r_valid_i || i_ariane.i_cva6.gen_cache_wt.i_cache_subsystem.i_adapter.i_rd_icache_id.pop_i)) begin
      $display("[SV MON] posedge clk: ar_valid=%b ar_ready=%b push_i=%b | r_valid=%b r_ready=%b r_last=%b pop_i=%b empty_o=%b",
               noc_req_ar_valid_o,
               noc_resp_ar_ready_i,
               i_ariane.i_cva6.gen_cache_wt.i_cache_subsystem.i_adapter.i_rd_icache_id.push_i,
               noc_resp_r_valid_i,
               noc_req_r_ready_o,
               noc_resp_r_last_i,
               i_ariane.i_cva6.gen_cache_wt.i_cache_subsystem.i_adapter.i_rd_icache_id.pop_i,
               i_ariane.i_cva6.gen_cache_wt.i_cache_subsystem.i_adapter.i_rd_icache_id.empty_o);
    end
  end
*/

  // Debug signals
  // Detect ebreak instruction commit (Breakpoint exception has cause 3)
  assign ebreak_o = i_ariane.i_cva6.commit_stage_i.exception_o.valid && 
                    (i_ariane.i_cva6.commit_stage_i.exception_o.cause == 3);

  // Detect illegal instruction exception commit (Illegal instruction exception has cause 2)
  assign illegal_instr_o = i_ariane.i_cva6.commit_stage_i.exception_o.valid && 
                           (i_ariane.i_cva6.commit_stage_i.exception_o.cause == 2);
  assign program_counter = 64'(i_ariane.i_cva6.commit_stage_i.commit_instr_i[0].pc);

endmodule
