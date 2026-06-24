// Copyright 2026 Antigravity
// Description: SystemVerilog FIFO DMA Accelerator with AXI4/AXI4-Lite interfaces.

module fifo_accel #(
    parameter int N = 4,
    parameter int DATA_WIDTH = 64
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // AXI4-Lite Slave Interface (MMIO Registers)
    input  logic [31:0]             s_axi_awaddr,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    
    input  logic [31:0]             s_axi_araddr,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // AXI4 Master Interface (DMA Read and Write)
    output logic [63:0]             m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output logic                    m_axi_wlast,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    
    input  logic [1:0]              m_axi_bresp,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    
    output logic [63:0]             m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    
    input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rlast,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,

    // Status/DMA Flags
    output logic                    dma_busy_o,
    output logic                    dma_done_o
);

    // --------------------------------------------------------
    // Internal Registers
    // --------------------------------------------------------
    logic [63:0] src_addr_reg;
    logic [63:0] dst_addr_reg;
    logic [63:0] len_reg;
    
    logic        start_dma;
    logic        clear_done;
    logic        busy_dma;
    logic        done_dma;

    assign dma_busy_o = busy_dma;
    assign dma_done_o = done_dma;

    // DMA progress counters
    logic [63:0] words_read;
    logic [63:0] words_written;
    logic [63:0] current_read_addr;
    logic [63:0] current_write_addr;

    // --------------------------------------------------------
    // FIFO Queue Circular Buffer
    // --------------------------------------------------------
    localparam int ADDR_WIDTH = (N > 1) ? $clog2(N) : 1;
    logic [DATA_WIDTH-1:0] fifo_mem [N-1:0];
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [ADDR_WIDTH:0]   count;

    logic fifo_full;
    logic fifo_empty;
    
    // cast N to match count's width
    assign fifo_full  = (count == (ADDR_WIDTH+1)'(N));
    assign fifo_empty = (count == '0);

    logic fifo_push;
    logic fifo_pop;
    logic [DATA_WIDTH-1:0] fifo_wdata;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            if (fifo_push && !fifo_full && fifo_pop && !fifo_empty) begin
                fifo_mem[wr_ptr] <= fifo_wdata;
                wr_ptr <= (wr_ptr == ADDR_WIDTH'(N-1)) ? '0 : wr_ptr + 1;
                rd_ptr <= (rd_ptr == ADDR_WIDTH'(N-1)) ? '0 : rd_ptr + 1;
            end else if (fifo_push && !fifo_full) begin
                fifo_mem[wr_ptr] <= fifo_wdata;
                wr_ptr <= (wr_ptr == ADDR_WIDTH'(N-1)) ? '0 : wr_ptr + 1;
                count  <= count + 1;
            end else if (fifo_pop && !fifo_empty) begin
                rd_ptr <= (rd_ptr == ADDR_WIDTH'(N-1)) ? '0 : rd_ptr + 1;
                count  <= count - 1;
            end
        end
    end

    // --------------------------------------------------------
    // AXI4-Lite Slave Interface (Register access)
    // --------------------------------------------------------
    logic        reg_write_pulse;
    logic [5:0]  reg_write_addr;
    logic [63:0] reg_write_data;
    logic [63:0] reg_rdata_next;

    // AXI4-Lite Read
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= '0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b1;
                s_axi_rdata   <= reg_rdata_next;
                s_axi_rresp   <= 2'b00; // OKAY
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;
                s_axi_arready <= 1'b1;
            end
        end
    end

    // AXI4-Lite Write
    logic aw_captured;
    logic w_captured;
    logic [5:0] awaddr_reg;
    logic [63:0] wdata_reg;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            s_axi_awready   <= 1'b1;
            s_axi_wready    <= 1'b1;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= '0;
            aw_captured     <= 1'b0;
            w_captured      <= 1'b0;
            awaddr_reg      <= '0;
            wdata_reg       <= '0;
            reg_write_pulse <= 1'b0;
            reg_write_addr  <= '0;
            reg_write_data  <= '0;
        end else begin
            reg_write_pulse <= 1'b0;

            if (s_axi_awvalid && s_axi_awready) begin
                s_axi_awready <= 1'b0;
                awaddr_reg    <= s_axi_awaddr[5:0];
                aw_captured   <= 1'b1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                s_axi_wready <= 1'b0;
                wdata_reg    <= s_axi_wdata;
                w_captured   <= 1'b1;
            end

            if ((aw_captured || (s_axi_awvalid && s_axi_awready)) &&
                (w_captured || (s_axi_wvalid && s_axi_wready))) begin
                
                reg_write_pulse <= 1'b1;
                reg_write_addr  <= aw_captured ? awaddr_reg : s_axi_awaddr[5:0];
                reg_write_data  <= w_captured ? wdata_reg : s_axi_wdata;

                aw_captured  <= 1'b0;
                w_captured   <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end
        end
    end

    // Clocked register writes
    logic        fifo_push_mmio;
    logic [63:0] fifo_wdata_mmio;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            src_addr_reg    <= '0;
            dst_addr_reg    <= '0;
            len_reg         <= '0;
            start_dma       <= 1'b0;
            clear_done      <= 1'b0;
            fifo_push_mmio  <= 1'b0;
            fifo_wdata_mmio <= '0;
        end else begin
            start_dma      <= 1'b0;
            clear_done     <= 1'b0;
            fifo_push_mmio <= 1'b0;

            if (reg_write_pulse) begin
                case (reg_write_addr)
                    6'h00: begin // CTRL
                        start_dma  <= reg_write_data[0];
                        clear_done <= reg_write_data[2];
                    end
                    6'h08: src_addr_reg <= reg_write_data;
                    6'h10: dst_addr_reg <= reg_write_data;
                    6'h18: len_reg      <= reg_write_data;
                    6'h28: begin // FIFO_DATA
                        fifo_push_mmio  <= 1'b1;
                        fifo_wdata_mmio <= reg_write_data;
                    end
                    default: ;
                endcase
            end
        end
    end

    // Combinational register reads & FIFO pop MMIO
    logic fifo_pop_mmio;
    assign fifo_pop_mmio = s_axi_arvalid && s_axi_arready && (s_axi_araddr[5:0] == 6'h28);

    always_comb begin
        reg_rdata_next = '0;
        case (s_axi_araddr[5:0])
            6'h00: reg_rdata_next = {61'b0, done_dma, busy_dma, 1'b0};
            6'h08: reg_rdata_next = src_addr_reg;
            6'h10: reg_rdata_next = dst_addr_reg;
            6'h18: reg_rdata_next = len_reg;
            6'h20: reg_rdata_next = 64'({count, 6'b0, fifo_full, fifo_empty});
            6'h28: reg_rdata_next = fifo_empty ? '0 : fifo_mem[rd_ptr];
            default: reg_rdata_next = '0;
        endcase
    end

    // --------------------------------------------------------
    // DMA Read Engine (AXI Master Read)
    // --------------------------------------------------------
    typedef enum logic [1:0] {
        RD_DMA_IDLE,
        RD_DMA_REQ,
        RD_DMA_WAIT
    } rd_dma_state_t;

    rd_dma_state_t rd_dma_state;
    logic                  dma_read_push;
    logic [DATA_WIDTH-1:0] dma_read_data;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rd_dma_state      <= RD_DMA_IDLE;
            m_axi_arvalid     <= 1'b0;
            m_axi_araddr      <= '0;
            m_axi_arlen       <= '0;
            m_axi_arsize      <= '0;
            m_axi_arburst     <= '0;
            m_axi_rready      <= 1'b0;
            words_read        <= '0;
            current_read_addr <= '0;
            dma_read_push     <= 1'b0;
            dma_read_data     <= '0;
        end else begin
            dma_read_push <= 1'b0;

            if (start_dma) begin
                words_read        <= '0;
                current_read_addr <= src_addr_reg;
                rd_dma_state      <= RD_DMA_REQ;
            end else if (busy_dma) begin
                case (rd_dma_state)
                    RD_DMA_IDLE: begin
                        if (words_read < len_reg) begin
                            rd_dma_state <= RD_DMA_REQ;
                        end
                    end
                    RD_DMA_REQ: begin
                        if (!fifo_full) begin
                            m_axi_arvalid <= 1'b1;
                            m_axi_araddr  <= current_read_addr;
                            m_axi_arlen   <= 8'd0;    // 1 beat
                            m_axi_arsize  <= 3'd3;   // 8 bytes (64-bit)
                            m_axi_arburst <= 2'b01; // INCR

                            if (m_axi_arready) begin
                                m_axi_arvalid     <= 1'b0;
                                words_read        <= words_read + 1;
                                current_read_addr <= current_read_addr + 8;
                                m_axi_rready      <= 1'b1;
                                rd_dma_state      <= RD_DMA_WAIT;
                            end
                        end
                    end
                    RD_DMA_WAIT: begin
                        if (m_axi_rvalid) begin
                            m_axi_rready  <= 1'b0;
                            dma_read_push <= 1'b1;
                            dma_read_data <= m_axi_rdata;
                            if (words_read < len_reg) begin
                                rd_dma_state <= RD_DMA_REQ;
                            end else begin
                                rd_dma_state <= RD_DMA_IDLE;
                            end
                        end
                    end
                    default: ;
                endcase
            end else begin
                m_axi_arvalid <= 1'b0;
                m_axi_rready  <= 1'b0;
                rd_dma_state  <= RD_DMA_IDLE;
            end
        end
    end

    // --------------------------------------------------------
    // DMA Write Engine (AXI Master Write)
    // --------------------------------------------------------
    typedef enum logic [1:0] {
        WR_DMA_IDLE,
        WR_DMA_REQ,
        WR_DMA_RESP
    } wr_dma_state_t;

    wr_dma_state_t wr_dma_state;
    logic                  dma_write_pop;
    logic [DATA_WIDTH-1:0] dma_write_data;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_dma_state       <= WR_DMA_IDLE;
            m_axi_awvalid      <= 1'b0;
            m_axi_awaddr       <= '0;
            m_axi_awlen        <= '0;
            m_axi_awsize       <= '0;
            m_axi_awburst      <= '0;
            m_axi_wvalid       <= 1'b0;
            m_axi_wdata        <= '0;
            m_axi_wstrb        <= '0;
            m_axi_wlast        <= 1'b0;
            m_axi_bready       <= 1'b0;
            words_written      <= '0;
            current_write_addr <= '0;
            dma_write_pop      <= 1'b0;
            dma_write_data     <= '0;
        end else begin
            dma_write_pop <= 1'b0;

            if (start_dma) begin
                words_written      <= '0;
                current_write_addr <= dst_addr_reg;
                wr_dma_state       <= WR_DMA_IDLE;
            end else if (busy_dma) begin
                case (wr_dma_state)
                    WR_DMA_IDLE: begin
                        if (words_written < len_reg && !fifo_empty) begin
                            dma_write_data <= fifo_mem[rd_ptr];
                            dma_write_pop  <= 1'b1;
                            wr_dma_state   <= WR_DMA_REQ;
                        end
                    end
                    WR_DMA_REQ: begin
                        m_axi_awvalid <= 1'b1;
                        m_axi_awaddr  <= current_write_addr;
                        m_axi_awlen   <= 8'd0;
                        m_axi_awsize  <= 3'd3;
                        m_axi_awburst <= 2'b01;

                        m_axi_wvalid <= 1'b1;
                        m_axi_wdata  <= dma_write_data;
                        m_axi_wstrb  <= 8'hFF;
                        m_axi_wlast  <= 1'b1;

                        if (m_axi_awready) m_axi_awvalid <= 1'b0;
                        if (m_axi_wready)  m_axi_wvalid  <= 1'b0;

                        if (m_axi_awready && m_axi_wready) begin
                            m_axi_awvalid      <= 1'b0;
                            m_axi_wvalid       <= 1'b0;
                            words_written      <= words_written + 1;
                            current_write_addr <= current_write_addr + 8;
                            m_axi_bready       <= 1'b1;
                            wr_dma_state       <= WR_DMA_RESP;
                        end
                    end
                    WR_DMA_RESP: begin
                        if (m_axi_bvalid) begin
                            m_axi_bready <= 1'b0;
                            wr_dma_state <= WR_DMA_IDLE;
                        end
                    end
                    default: ;
                endcase
            end else begin
                m_axi_awvalid <= 1'b0;
                m_axi_wvalid  <= 1'b0;
                m_axi_bready  <= 1'b0;
                wr_dma_state  <= WR_DMA_IDLE;
            end
        end
    end

    // --------------------------------------------------------
    // Main Control and Handshaking logic
    // --------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            busy_dma <= 1'b0;
            done_dma <= 1'b0;
        end else begin
            if (start_dma) begin
                busy_dma <= 1'b1;
                done_dma <= 1'b0;
            end else if (clear_done) begin
                done_dma <= 1'b0;
            end else if (busy_dma && (words_written == len_reg) && (wr_dma_state == WR_DMA_IDLE)) begin
                busy_dma <= 1'b0;
                done_dma <= 1'b1;
            end
        end
    end

    assign fifo_push = fifo_push_mmio || dma_read_push;
    assign fifo_pop  = fifo_pop_mmio  || dma_write_pop;
    assign fifo_wdata = fifo_push_mmio ? fifo_wdata_mmio : dma_read_data;

endmodule
