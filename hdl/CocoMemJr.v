`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:29:06 03/23/2018 
// Design Name: 
// Module Name:    CocoMemJr 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module CocoMemJr(
                 input _reset,
                 input e, 
                 input [15:0]address_cpu,
                 output [15:13]address_brd,
                 inout [7:0]data_cpu,
                 inout [7:0]data_brd,
                 output [20:0]address_mem,
                 inout [7:0]data_mem, 
                 output [14:0]address_dat,
                 inout [15:0]data_dat, 
                 output _we_ram,
                 output _we_dat_l,
                 output _we_dat_h,
                 input r_w_cpu,
                 output r_w_brd 
                );

//`define TESTING

`ifdef TESTING
wire ce_test_low, ce_test_mid, ce_access_mem, ce_access_dat_lo;
wire [20:0]addr;

assign ce_test_low =                   address_cpu == 16'hfd00;
assign ce_test_mid =                   address_cpu == 16'hfd01;
assign ce_test_high =                  address_cpu == 16'hfd02;

assign ce_access_mem =                 address_cpu == 16'hfd03;
assign ce_access_dat_lo =              address_cpu == 16'hfd04;
assign ce_access_dat_hi =              address_cpu == 16'hfd05;
`endif

wire ce_fxxx;
wire ce_ffxx;
wire ce_fexx;
wire ce_mmu_regs;
wire ce_init0;
wire ce_init1;
wire ce_task_hi;
wire ce_mem;
wire we_mem;
wire ce_dat;
wire flag_mmu_enabled;
wire flag_crm_enabled;
wire flag_alt_regs;
wire flag_ext_mmu;
wire [11:0]dat_task_active; // 5 bits of task number in init1 register + 7 bits of tasklets in another register.
wire [11:0]dat_task_access;   // used to select "window" of task values to show in $ffax

reg [7:0]data_out;
wire we_dat_l;
wire we_dat_h;
reg [20:13]address_out;
reg [14:0]address_dat_out;

assign ce_fxxx =                       (address_cpu[15:9] == 7'b1111111);
assign ce_ffxx =                       ce_fxxx & (address_cpu[8] == 1);
assign ce_fexx =                       ce_fxxx & (address_cpu[8] == 0);
assign ce_mmu_regs =                   ce_ffxx & (address_cpu[7:4] == 4'h9);
assign ce_init0 =                      ce_mmu_regs & (address_cpu[3:0] == 4'h0);
assign ce_init1 =                      ce_mmu_regs & (address_cpu[3:0] == 4'h1);
assign ce_task_hi =                    ce_mmu_regs & (address_cpu[3:0] == 4'h7);
assign ce_dat =                        ce_ffxx & (address_cpu[7:4] == 4'ha);
assign ce_crm =                        flag_crm_enabled & ce_fexx;
assign ce_mem =                        (address_out[20:16] != 5'b00111);
assign we_mem =                        ce_mem & !r_w_cpu;
assign we_dat_l =                      (e & !r_w_cpu & ce_dat & (!flag_alt_regs | (flag_alt_regs & !flag_ext_mmu) | (flag_ext_mmu & address_cpu[0])));
assign we_dat_h =                      (e & !r_w_cpu & ce_dat & (flag_ext_mmu & !address_cpu[0]));

`ifdef TESTING
assign address_mem =                   (ce_access_mem ? addr : {address_out[20:13], address_cpu[12:0]});
`else
assign address_mem =                   {address_out[20:13], address_cpu[12:0]};
`endif
assign address_brd[15:13] =            address_out[15:13];
assign address_dat[14:0] =             address_dat_out;

// write to PCB when cpu asks, mmu is off, we're in IO page, or mmu is on and bank is local ram
assign r_w_brd =                       !(!r_w_cpu & (!flag_mmu_enabled | (flag_mmu_enabled & !ce_mem)));

assign data_brd =                      (!r_w_brd ? data_cpu : 8'bz);
assign data_cpu =                      (r_w_cpu ? data_out : 8'bz);
assign data_mem =                      (!r_w_cpu ? data_cpu : 8'bz);
assign data_dat[7:0] =                 (we_dat_l ? data_cpu : 8'bz);
assign data_dat[15:8] =                (we_dat_h ? data_cpu : 8'bz);
assign _we_ram =                       !(we_mem);
assign _we_dat_l =                     !we_dat_l;
assign _we_dat_h =                     !we_dat_h;

register #(.WIDTH(1))                  reg_mmu(e, !_reset, !r_w_cpu & ce_init0, data_cpu[6], flag_mmu_enabled);
register #(.WIDTH(1))                  reg_crm(e, !_reset, !r_w_cpu & ce_init0, data_cpu[3], flag_crm_enabled);
register #(.WIDTH(1))                  reg_mmu_set(e, !_reset, !r_w_cpu & ce_init1, data_cpu[7], flag_alt_regs);
register #(.WIDTH(1))                  reg_mmu_ext_set(e, !_reset, !r_w_cpu & ce_init1, data_cpu[7] & data_cpu[6], flag_ext_mmu);
register #(.WIDTH(5))                  reg_dat_task_lo(e, !_reset, !r_w_cpu & ce_init1 & !data_cpu[7], data_cpu[4:0], dat_task_active[4:0]);
register #(.WIDTH(7))                  reg_dat_task_hi(e, !_reset, !r_w_cpu & ce_task_hi & !flag_alt_regs, data_cpu[6:0], dat_task_active[11:5]);register #(.WIDTH(5))                  reg_dat_task_lo_access(e, !_reset, !r_w_cpu & ce_init1 & data_cpu[7], data_cpu[4:0], dat_task_access[4:0]);
register #(.WIDTH(7))                  reg_dat_task_hi_access(e, !_reset, !r_w_cpu & ce_task_hi & flag_alt_regs, data_cpu[6:0], dat_task_access[11:5]);
`ifdef TESTING
register #(.WIDTH(8))                  reg_addrl(e, !_reset, ce_test_low & !r_w_cpu, data_cpu, addr[7:0]);
register #(.WIDTH(8))                  reg_addrm(e, !_reset, ce_test_mid & !r_w_cpu, data_cpu, addr[15:8]);
register #(.WIDTH(5))                  reg_addrh(e, !_reset, ce_test_high & !r_w_cpu, data_cpu[4:0], addr[20:16]);
`endif

always @(*)
begin
`ifdef TESTING
   if(ce_access_dat_lo | ce_access_dat_hi)   // test code
      address_dat_out = addr[14:0];
   else 
`endif
   if(ce_dat & !flag_ext_mmu)       // DAT register access
      address_dat_out = {dat_task_access,3'b0} + address_cpu[3:0];
   else if(ce_dat & flag_ext_mmu)        // Extended DAT register access
      address_dat_out = {dat_task_access, address_cpu[3:1]};
   else                                      // DAT MMU usage
      address_dat_out = {dat_task_active, address_cpu[15:13]};
end

always @(*)
begin
   if(ce_init0)                              // if accessing mmu register init0
      data_out = {0,flag_mmu_enabled,2'b0,flag_crm_enabled,3'b0};
   else if(ce_init1 & !flag_alt_regs)         // read active task low bits
      data_out = {3'b0, dat_task_active[4:0]}; 
   else if(ce_init1 & flag_alt_regs)          // read windowed task low bits
      data_out = {'b1, flag_ext_mmu, 'b0, dat_task_access[4:0]}; 
   else if(ce_task_hi & !flag_alt_regs)       // read active task high bits
      data_out = {'b0, dat_task_active[11:5]}; 
   else if(ce_task_hi & flag_alt_regs)        // read windowed task high bits
      data_out = {'b0, dat_task_access[11:5]}; 
   else if(ce_dat & !flag_ext_mmu)       // read MMU task regs low bytes
      data_out = data_dat[7:0];
   else if(ce_dat & flag_ext_mmu & !address_cpu[0]) // high byte
      data_out = data_dat[15:8];
   else if(ce_dat & flag_ext_mmu & address_cpu[0]) // low byte
      data_out = data_dat[7:0];
`ifdef TESTING      
   else if(ce_test_low)
      data_out = addr[7:0];
   else if(ce_test_mid)
      data_out = addr[15:8];
   else if(ce_test_high)
      data_out = {3'b0,addr[20:16]};
   else if(ce_access_mem)
      data_out = data_mem;
   else if(ce_access_dat_lo)
      data_out = data_dat[7:0];
   else if(ce_access_dat_hi)
      data_out = data_dat[15:8];
`endif
   else if(ce_mem) // we are accessing on-board RAM
      data_out = data_mem;
   else   
      data_out = data_brd;
end

always @(*)
begin
`ifdef TESTING      
   if(ce_access_mem)
      address_out[20:13] = {5'b0,addr[15:13]};
   else
`endif   
   if (ce_crm)                       // if CRM enabled, and $fexx access, pin bank to $3f
    address_out = 8'h3f;   else if(flag_mmu_enabled & !ce_ffxx)   // if we're in MMU and not asking for IO page, use DAT
      address_out[20:13] = data_dat[7:0];
   else                                   // otherwise, pass through upper 3 bits.
      address_out[20:13] = {5'b0,address_cpu[15:13]};
end

endmodule
