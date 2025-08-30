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
                 input q,
					  input ba,
                 input r_w_cpu,
                 input [15:0]address_cpu,
                 inout [7:0]data_cpu,
                 output r_w_brd,
                 output [15:13]address_brd,
                 inout [7:0]data_brd,
                 output _we_dat_l,
                 output _we_dat_h,
                 output [14:0]address_dat,
                 inout [15:0]data_dat,
					  output _we_mem,
					  output [20:0]address_mem,
					  inout [7:0]data_mem,
					  output [2:0]bank,
					  output _irq,
					  output _firq
					 );


wire ce_fxxx;
wire ce_ffxx;
wire ce_fexx;
wire ce_crm;
wire ce_mmu_regs;
wire ce_init0;
wire ce_init1;
wire ce_dat;
wire ce_mem;
wire we_dat_l;
wire we_dat_h;

wire flag_mmu_enabled;
wire flag_crm_enabled;
wire [3:0]cfg_mem;
wire [2:0]cfg_vdg;
wire dat_task_active; 						// 1 bit of task register for now.

reg [20:13]address_out;
reg [4:0]address_dat_out;
reg [7:0]data_out;

assign _irq = 									1'bz;
assign _firq = 								1'bz;

// fexx or ffxx
assign ce_fxxx =                       (address_cpu[15:9] == 7'b1111111); 			
assign ce_fexx =                       ce_fxxx & (address_cpu[8] == 0);
assign ce_ffxx =                       ce_fxxx & (address_cpu[8] == 1);	
//ff9x
assign ce_mmu_regs =                   ce_ffxx & (address_cpu[7:4] == 4'h9);
//ff90
assign ce_init0 =                      ce_mmu_regs & (address_cpu[3:0] == 4'h0);
//ff91
assign ce_init1 =                      ce_mmu_regs & (address_cpu[3:0] == 4'h1);

//ffax
assign ce_dat =                        ce_ffxx & (address_cpu[7:4] == 4'ha);
//if CRM enabled, and ffex
assign ce_crm =                        flag_crm_enabled & ce_fexx;

assign ce_ffcx = 								ce_ffxx & (address_cpu[7:4] == 4'hc);
assign ce_ffdx = 								ce_ffxx & (address_cpu[7:4] == 4'hd);

/*
	There's a nuance here. If we're using internal memory, the simple approach
	is to open a hole in the memory map for the motherboard 64kB RAM (in this
	design, we've put this at the bottom of the physical address space), and 
	use internal memory when the virtual address is not ffxx and the address is
	not in the lowest 64kB. 
	
	However, that introduces a bug if the programmer maps the $3f bank (top
	8kB of motherboard RAM space) into a bank where the top 256 bytes can be
	written (any bank except the top one, in effect). For example, let's say
	bank $3f is mapped into $ffa0. The code then accesses the top 8kB of
	motherboard RAM (or ROM) via an access to $0000-$1fff. All is well until
	we get to $1f00. The code reads from $1f00, the DAT converts that to $ff00,
   and tries to read from $fff0 on the motherboard, expecting a RAM read. But,
	$ffxx is IO and vectors, so the SAM reads from IO. 

	To counteract that, this design creates a 256 byte RAM mirror in internal
	RAM for that space.  So, if code is not explicitly accessing ffxx, but the
	translated address is ffxx, read/write from internal memory.
 */

assign flag_cocoram =						(address_out[20:16] == 5'b0);
assign ce_mem =               			(!flag_cocoram
													 | (flag_cocoram
   													 && (address_out[15:13] == 3'b111)
														 && (address_cpu[12:8] == 5'b11111)
														 && !ce_ffxx
														)
													);   // hole at bank 00-07 for main memory

assign we_mem =                        e                    // top half of E
                                       & !r_w_cpu           // write cycle
                                       & ce_mem;    			// anything but pages 0-7
													

assign we_dat_l =                      e                    // top half of E
                                       & !r_w_cpu           // write cycle
                                       & ce_dat;  
assign we_dat_h = 							0;

assign _we_dat_l =                     !we_dat_l;
assign _we_dat_h =                     !we_dat_h;
assign _we_mem = 								!we_mem;

assign data_brd =                      (!ce_mem & !ba & !r_w_cpu & (e | q) ? data_cpu : 8'bz);
assign data_mem =                      (ce_mem & !ba & !r_w_cpu & (e | q) ? data_cpu : 8'bz);
assign data_cpu =                      (r_w_cpu ? data_out : 8'bz);
// might need !ba on these, not sure
assign data_dat[7:0] =                 (we_dat_l ? data_cpu : 8'bz);
assign data_dat[15:8] =                (we_dat_h ? data_cpu : 8'bz);

// we need write to only happen with ce_mem is inactive
assign r_w_brd =                       !(!ba & !r_w_cpu & !ce_mem) ;

assign address_dat[14:0] =             address_dat_out;
// we may need to set address_brd to ffff or something when mem is being read.
assign address_brd[15:13] =            (!ba & (e | q) ? address_out[15:13] : 3'bz);
//assign bank = 									address_out[18:16];
assign bank = 									address_out[18:16];
assign address_mem = 						{address_out, address_cpu[12:0]};

register #(.WIDTH(1))                  reg_mmu(e, !_reset, !r_w_cpu & ce_init0, data_cpu[6], flag_mmu_enabled);
register #(.WIDTH(1))                  reg_crm(e, !_reset, !r_w_cpu & ce_init0, data_cpu[3], flag_crm_enabled);
register #(.WIDTH(1))                  reg_dat_task_lo(e, !_reset, !r_w_cpu & ce_init1, data_cpu[0], dat_task_active);

register #(.WIDTH(4))                  reg_FFCX(!e, !_reset, r_w_cpu & ce_ffcx, address_cpu[3:0], cfg_mem);
register #(.WIDTH(3))                  reg_FFDX(!e, !_reset, r_w_cpu & ce_ffdx, address_cpu[2:0], cfg_vdg);

// data for CPU
always @(*)
begin
   if(ce_init0)                                 // if accessing mmu register init0
      data_out = {0,flag_mmu_enabled,2'b0,flag_crm_enabled,3'b0};
   else if(ce_init1)           						// read active task low bits
      data_out = {7'b0, dat_task_active}; 
   //else if(ce_task_hi)         						// read active task high bits
   //   data_out = {'b0, dat_task_active[11:5]}; 
   else if(ce_dat)              // read MMU task regs low bytes
      data_out = data_dat[7:0];
	else if(ce_mem)
	   data_out = data_mem;
	else	
		data_out = data_brd;
end

// address for DAT
always @(*)
begin
   if(ce_dat)                   // DAT register access
      address_dat_out = address_cpu[3:0];
   else                                         // DAT MMU usage
      address_dat_out = {dat_task_active, address_cpu[15:13]};
end

// Address for MEM (internal or otherwise)

/*
	If the MMU is off, use the Banker Board 512kB configs to set bank
	If the MMU is on, use the task register to select a page of bank
	settings and then use the upper 3 bits of the address to select the bank
	of RAM for access.
	
	The CC3 interestingly maps the ROMs into banks 3c-3f, whereas in the 
	CC3, they are in the upper 32kB of the 64kB address range. This suggests
	that 38-3f in the CC3 represent the original 64kB of memory. Thus, this
	design also maps bank 38-3f to the original CC2 memory space, RAM and ROM.
	To make it a bit easier to perform calculations, we invert address lines
	16,17,18, which translates 38-3f into 00-07. Then, we can simply check for
	bank = 0 to denote motherboard memory. 
		
	If the CRM bit is on, pin the bank to 3f (translated to 07).
	
	If the virtual address lies in ffxx, do the same (this code can be 
	compbined with the above as an optimization
 */

always @(*)
begin
	if(!flag_mmu_enabled) // Banker Board config
	begin
		if(e)
		begin
			if(address_cpu[15])
			begin
				address_out[20:13] = {2'b0, cfg_mem[2:0], address_cpu[15:13]};
			end
			else if(cfg_mem[3]) // lock high bank to 0
			begin
				address_out[20:13] = {5'b0, address_cpu[15:13]};
			end
		   else
			begin
				address_out[20:13] = { 2'b0, cfg_mem[2:0], address_cpu[15:13]};
			end
		end
		else // VDG
		begin
			address_out[20:13] = { 2'b0, cfg_vdg[2:0], address_cpu[15:13]};
		end
	end
	else // MMU enabled
	begin
		if (ce_crm)
			address_out[20:13] = 8'h07;  	// inversion of 3f
 		else if(ce_ffxx)         			// if we're in MMU and asking for IO page, go direct
			address_out[20:13] = {5'b0,address_cpu[15:13]};
		else                             // otherwise, pass through upper 3 bits.
			address_out[20:13] = {data_dat[7:6], !data_dat[5], !data_dat[4], !data_dat[3], data_dat[2:0]};  // invert bits 3,4,5
	end
end

endmodule
