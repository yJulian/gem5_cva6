// Copyright 2026 Antigravity
// Description: Wrapper implementation wrapping Verilated Vfifo_accel.

#include "Vfifo_accel.h"
#include "fifo_accel_interface.hh"
#include "verilated.h"
#include "verilated_vcd_c.h"

namespace gem5
{

class FifoAccelImpl : public FifoAccelInterface
{
  private:
    Vfifo_accel *model;
    VerilatedVcdC *tfp;

  public:
    FifoAccelImpl() : model(new Vfifo_accel()), tfp(nullptr) {}
    ~FifoAccelImpl() override
    {
        close_trace();
        delete model;
    }

    void set_clk_i(uint8_t val) override { model->clk_i = val; }
    void set_rst_ni(uint8_t val) override { model->rst_ni = val; }

    void set_s_axi_awaddr(uint32_t val) override { model->s_axi_awaddr = val; }
    void set_s_axi_awvalid(uint8_t val) override { model->s_axi_awvalid = val; }
    uint8_t get_s_axi_awready() override { return model->s_axi_awready; }

    void set_s_axi_wdata(uint64_t val) override { model->s_axi_wdata = val; }
    void set_s_axi_wstrb(uint8_t val) override { model->s_axi_wstrb = val; }
    void set_s_axi_wvalid(uint8_t val) override { model->s_axi_wvalid = val; }
    uint8_t get_s_axi_wready() override { return model->s_axi_wready; }

    uint8_t get_s_axi_bresp() override { return model->s_axi_bresp; }
    uint8_t get_s_axi_bvalid() override { return model->s_axi_bvalid; }
    void set_s_axi_bready(uint8_t val) override { model->s_axi_bready = val; }

    void set_s_axi_araddr(uint32_t val) override { model->s_axi_araddr = val; }
    void set_s_axi_arvalid(uint8_t val) override { model->s_axi_arvalid = val; }
    uint8_t get_s_axi_arready() override { return model->s_axi_arready; }

    uint64_t get_s_axi_rdata() override { return model->s_axi_rdata; }
    uint8_t get_s_axi_rresp() override { return model->s_axi_rresp; }
    uint8_t get_s_axi_rvalid() override { return model->s_axi_rvalid; }
    void set_s_axi_rready(uint8_t val) override { model->s_axi_rready = val; }

    uint64_t get_m_axi_awaddr() override { return model->m_axi_awaddr; }
    uint8_t get_m_axi_awlen() override { return model->m_axi_awlen; }
    uint8_t get_m_axi_awsize() override { return model->m_axi_awsize; }
    uint8_t get_m_axi_awburst() override { return model->m_axi_awburst; }
    uint8_t get_m_axi_awvalid() override { return model->m_axi_awvalid; }
    void set_m_axi_awready(uint8_t val) override { model->m_axi_awready = val; }

    uint64_t get_m_axi_wdata() override { return model->m_axi_wdata; }
    uint8_t get_m_axi_wstrb() override { return model->m_axi_wstrb; }
    uint8_t get_m_axi_wlast() override { return model->m_axi_wlast; }
    uint8_t get_m_axi_wvalid() override { return model->m_axi_wvalid; }
    void set_m_axi_wready(uint8_t val) override { model->m_axi_wready = val; }

    void set_m_axi_bresp(uint8_t val) override { model->m_axi_bresp = val; }
    void set_m_axi_bvalid(uint8_t val) override { model->m_axi_bvalid = val; }
    uint8_t get_m_axi_bready() override { return model->m_axi_bready; }

    uint64_t get_m_axi_araddr() override { return model->m_axi_araddr; }
    uint8_t get_m_axi_arlen() override { return model->m_axi_arlen; }
    uint8_t get_m_axi_arsize() override { return model->m_axi_arsize; }
    uint8_t get_m_axi_arburst() override { return model->m_axi_arburst; }
    uint8_t get_m_axi_arvalid() override { return model->m_axi_arvalid; }
    void set_m_axi_arready(uint8_t val) override { model->m_axi_arready = val; }

    void set_m_axi_rdata(uint64_t val) override { model->m_axi_rdata = val; }
    void set_m_axi_rresp(uint8_t val) override { model->m_axi_rresp = val; }
    void set_m_axi_rlast(uint8_t val) override { model->m_axi_rlast = val; }
    void set_m_axi_rvalid(uint8_t val) override { model->m_axi_rvalid = val; }
    uint8_t get_m_axi_rready() override { return model->m_axi_rready; }

    uint8_t get_dma_busy_o() override { return model->dma_busy_o; }
    uint8_t get_dma_done_o() override { return model->dma_done_o; }

    void eval() override { model->eval(); }

    void setup_trace(const std::string &trace_file) override
    {
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        model->trace(tfp, 99);
        tfp->open(trace_file.c_str());
    }

    void dump_trace(uint64_t time) override
    {
        if (tfp) {
            tfp->dump(time);
        }
    }

    void close_trace() override
    {
        if (tfp) {
            tfp->close();
            delete tfp;
            tfp = nullptr;
        }
    }
};

} // namespace gem5

extern "C" {
gem5::FifoAccelInterface *
create_accel()
{
    return new gem5::FifoAccelImpl();
}
void
destroy_accel(gem5::FifoAccelInterface *accel)
{
    delete accel;
}
}
