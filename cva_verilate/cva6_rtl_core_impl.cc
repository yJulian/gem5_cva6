// Copyright 2026 Antigravity
// Description: Implementation of the CVA6 RTL Core interface wrapping
// Verilated Vcva6_top, mapping generic AXI calls to CVA6 signals.

#include "Vcva6_top.h"
#include "Vcva6_top__Syms.h"
#include "rtl_core_interface.hh"
#include "verilated.h"

#if VM_TRACE
#include "verilated_vcd_c.h"
#endif

namespace gem5
{

class CVA6RtlCoreImpl : public RtlCoreInterface
{
  private:
    Vcva6_top *core;
#if VM_TRACE
    VerilatedVcdC *tfp;
#endif

  public:
    CVA6RtlCoreImpl()
        : core(new Vcva6_top())
#if VM_TRACE
          ,
          tfp(nullptr)
#endif
    {}

    ~CVA6RtlCoreImpl() override
    {
        close_trace();
        delete core;
    }

    // Inputs to core
    void
    set_clk(uint8_t val) override
    {
        core->clk_i = val;
    }
    void
    set_rst_n(uint8_t val) override
    {
        core->rst_ni = val;
    }
    void
    set_debug_req(uint8_t val) override
    {
        core->debug_req_i = val;
    }
    void
    set_aw_ready(uint8_t val) override
    {
        core->noc_resp_aw_ready_i = val;
    }
    void
    set_w_ready(uint8_t val) override
    {
        core->noc_resp_w_ready_i = val;
    }
    void
    set_ar_ready(uint8_t val) override
    {
        core->noc_resp_ar_ready_i = val;
    }
    void
    set_irq(uint8_t val) override
    {
        core->irq_i = val;
    }
    void
    set_ipi(uint8_t val) override
    {
        core->ipi_i = val;
    }
    void
    set_time_irq(uint8_t val) override
    {
        core->time_irq_i = val;
    }
    void
    set_b_valid(uint8_t val) override
    {
        core->noc_resp_b_valid_i = val;
    }
    void
    set_b_id(uint8_t val) override
    {
        core->noc_resp_b_id_i = val;
    }
    void
    set_b_resp(uint8_t val) override
    {
        core->noc_resp_b_resp_i = val;
    }
    void
    set_r_valid(uint8_t val) override
    {
        core->noc_resp_r_valid_i = val;
    }
    void
    set_r_id(uint8_t val) override
    {
        core->noc_resp_r_id_i = val;
    }
    void
    set_r_last(uint8_t val) override
    {
        core->noc_resp_r_last_i = val;
    }
    void
    set_r_resp(uint8_t val) override
    {
        core->noc_resp_r_resp_i = val;
    }
    void
    set_boot_addr(uint64_t val) override
    {
        core->boot_addr_i = val;
    }
    void
    set_hart_id(uint64_t val) override
    {
        core->hart_id_i = val;
    }
    void
    set_boot_reg(uint64_t val) override
    {
        auto &regfile =
            core->rootp->vlSymsp
                ->TOP__cva6_top__i_ariane__i_cva6__issue_stage_i__i_issue_read_operands__gen_asic_regfile__DOT__i_ariane_regfile;
        regfile.mem[22] = (uint32_t)(val & 0xFFFFFFFF);
        regfile.mem[23] = (uint32_t)((val >> 32) & 0xFFFFFFFF);
    }
    void
    set_r_data(uint64_t val) override
    {
        core->noc_resp_r_data_i = val;
    }

    // Outputs from core
    uint8_t
    get_w_last() override
    {
        return core->noc_req_w_last_o;
    }
    uint8_t
    get_aw_valid() override
    {
        return core->noc_req_aw_valid_o;
    }
    uint8_t
    get_aw_id() override
    {
        return core->noc_req_aw_id_o;
    }
    uint8_t
    get_aw_len() override
    {
        return core->noc_req_aw_len_o;
    }
    uint8_t
    get_aw_size() override
    {
        return core->noc_req_aw_size_o;
    }
    uint8_t
    get_w_valid() override
    {
        return core->noc_req_w_valid_o;
    }
    uint8_t
    get_b_ready() override
    {
        return core->noc_req_b_ready_o;
    }
    uint8_t
    get_ar_valid() override
    {
        return core->noc_req_ar_valid_o;
    }
    uint8_t
    get_ar_id() override
    {
        return core->noc_req_ar_id_o;
    }
    uint8_t
    get_ar_len() override
    {
        return core->noc_req_ar_len_o;
    }
    uint8_t
    get_ar_size() override
    {
        return core->noc_req_ar_size_o;
    }
    uint8_t
    get_ar_prot() override
    {
        return core->noc_req_ar_prot_o;
    }
    uint8_t
    get_r_ready() override
    {
        return core->noc_req_r_ready_o;
    }
    uint64_t
    get_aw_addr() override
    {
        return core->noc_req_aw_addr_o;
    }
    uint64_t
    get_w_data() override
    {
        return core->noc_req_w_data_o;
    }
    uint64_t
    get_ar_addr() override
    {
        return core->noc_req_ar_addr_o;
    }
    uint8_t
    get_ebreak() override
    {
        return core->ebreak_o;
    }
    uint8_t
    get_illegal_instr() override
    {
        return core->illegal_instr_o;
    }
    uint64_t
    get_illegal_instr_pc() override
    {
        return core->program_counter;
    }
    uint64_t
    get_pc() override
    {
        return core->program_counter;
    }

    // Control
    void
    eval() override
    {
        core->eval();
    }

    // Tracing
    void
    setup_trace(const std::string &trace_file) override
    {
#if VM_TRACE
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        core->trace(tfp, 99);
        tfp->open(trace_file.c_str());
#endif
    }

    void
    dump_trace(uint64_t time) override
    {
#if VM_TRACE
        if (tfp) {
            tfp->dump(time);
        }
#endif
    }

    void
    close_trace() override
    {
#if VM_TRACE
        if (tfp) {
            tfp->close();
            delete tfp;
            tfp = nullptr;
        }
#endif
    }
};

} // namespace gem5

extern "C" {
gem5::RtlCoreInterface *
create_core()
{
    return new gem5::CVA6RtlCoreImpl();
}
void
destroy_core(gem5::RtlCoreInterface *core)
{
    delete core;
}
}
