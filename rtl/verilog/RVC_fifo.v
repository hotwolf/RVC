//###############################################################################
//# RVC - Reusable Verilog Components - FIFO Buffer                             #
//###############################################################################
//#    Copyright 2019 Dirk Heisswolf                                            #
//#    This file is part of the RVC project.                                    #
//#                                                                             #
//#    RVC is free software: you can redistribute it and/or modify              #
//#    it under the terms of the GNU General Public License as published by     #
//#    the Free Software Foundation, either version 3 of the License, or        #
//#    (at your option) any later version.                                      #
//#                                                                             #
//#    RVC is distributed in the hope that it will be useful,                   #
//#    but WITHOUT ANY WARRANTY; without even the implied warranty of           #
//#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
//#    GNU General Public License for more details.                             #
//#                                                                             #
//#    You should have received a copy of the GNU General Public License        #
//#    along with RVC.  If not, see <http://www.gnu.org/licenses/>.             #
//###############################################################################
//# Description:                                                                #
//#    This module implements a memory controller for a FIFO buffer. It         #
//#    requires an external dual ported RAM. The address sequence is generated  #
//#    a LSFR.                                                                  #
//#                                                                             #
//#    SKIP_FROM and SKIP_TO:                                                   #
//#     These parameters make it possible to share the address space of the RAM #
//#     between several ring buffers. If set to unequal values, the address     #
//#     sequence will be altered so that address SKIP_TO will follow sddress    #
//#     SKIP_FROM. RESET_STATE should be within the reachable address sequence. #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   May 20, 2019                                                              #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module RVC_fifo
  #(parameter ADR_WIDTH      =  8,                             //address width
    parameter DAT_WIDTH      =  8,                             //data width
    parameter SKIP_ENABLE    =  0,                             //skip over partial sequence
    parameter SKIP_FROM      =  0,                             //last state before skipped sequence
    parameter SKIP_TO        =  0,                             //first state after skipped sequence
    parameter RESET_STATE    =  0)                             //reset state

   (//Clock and reset
    //---------------
    input wire 		                   clk_i,              //module clock
    input wire 		                   async_rst_i,        //asynchronous reset
    input wire 		                   sync_rst_i,         //synchronous reset

    //Buffer output
    //-------------
    input  wire [ITR_CNT-1:0]              out_stb_i,          //access request            
    output wire [ITR_CNT-1:0]              out_ack_o,          //acknowledge     
    output wire [ITR_CNT-1:0]              out_rty_o,          //retry request (buffer is empty)            
    output wire                            out_stall_o,        //access delay  
    output wire [(ITR_CNT*DAT_WIDTH)-1:0]  out_dat_o,          //read data bus             

    //Buffer input
    //------------
    input  wire                            in_stb_i,           //access request         
    input  wire [DAT_WIDTH-1:0]            in_dat_i,           //data bus         
    output wire                            in_ack_o,           //acknowledge    
    output wire                            in_rty_o,           //retry request (buffer is full)          
    output wire                            in_stall_o,         //access delay  

    //DPRAM read bus
    //--------------
    output reg                             rdbus_cyc_o,        //bus cycle indicator       +-
    output reg                             rdbus_stb_o,        //access request            | target to
    output reg  [ADR_WIDTH-1:0]            rdbus_adr_o,        //address bus               | initiator
    input  wire                            rdbus_ack_i,        //bus cycle acknowledge     +-
    input  wire                            rdbus_stall_i,      //access delay              | initiator to target
    input  wire [DAT_WIDTH-1:0]            rdbus_dat_i);       //read data bus             +-
   
    //DPRAM write bus
    //---------------
    output reg                             wrbus_cyc_o,        //bus cycle indicator       +-
    output reg                             wrbus_stb_o,        //access request            | target to
    output reg  [ADR_WIDTH-1:0]            wrbus_adr_o,        //address bus               | initiator
    output reg  [DAT_WIDTH-1:0]            wrbus_dat_o,        //write data bus            +-
    input  wire                            wrbus_ack_i,        //bus cycle acknowledge     | initiator to target
    input  wire                            wrbus_stall_i);     //access delay              +- 
   
   //Internal signals
   //----------------         
   //LSFRs
   wire                                    advance_in_ptr;     //switch to next in pointer
   wire [ADR_WIDTH-1:0] 		   in_ptr;             //current input pointer
   wire [ADR_WIDTH-1:0] 		   in_ptr_next;        //next input pointer
   wire                                    advance_in_ptr;     //switch to next out pointer
   wire [ADR_WIDTH-1:0] 		   out_ptr;            //current output pointer
   wire [ADR_WIDTH-1:0] 		   out_ptr_next;       //next output pointer
   //FIFO status
   wire 				   fifo_empty;         //FIFO is empty
   wire                                    fifo_full;          //FIFO is full
				   
   //FIFOs
   //-----         
   RVC_lsfr
     #(.WIDTH                             (ADR_WIDTH),         //width of the shift register
       .INCLUDE_LOCK_UP                   (1),                 //include "lock-up" state (-1)
       .SKIP_FROM                         (SKIP_FROM),         //last state before skipped sequence
       .SKIP_TO                           (SKIP_TO),           //first state after skipped sequence
       .RESET_STATE                       (RESET_STATE))       //reset state
   in_lsfr  		                  
     (//Clock and reset	                  
      //---------------	                  
      .clk_i                              (clk_i),             //module clock
      .async_rst_i                        (async_rst_i),       //asynchronous reset
      .sync_rst_i                         (sync_rst_i),        //synchronous reset   			                  
      //LSFR		                  
      //----		                  
      .advance_i                          (advance_in_ptr),    //switch to next LSFR state
      .lsfr_o                             (in_ptr),            //current LSFR state
      .lsfr_next_o                        (in_ptr_next));      //next LSFR state

   RVC_lsfr
     #(.WIDTH                             (ADR_WIDTH),         //width of the shift register
       .INCLUDE_LOCK_UP                   (1),                 //include "lock-up" state (-1)
       .SKIP_FROM                         (SKIP_FROM),         //last state before skipped sequence
       .SKIP_TO                           (SKIP_TO),           //first state after skipped sequence
       .RESET_STATE                       (RESET_STATE))       //reset state
   out_lsfr  		                  
     (//Clock and reset	                  
      //---------------	                  
      .clk_i                              (clk_i),             //module clock
      .async_rst_i                        (async_rst_i),       //asynchronous reset
      .sync_rst_i                         (sync_rst_i),        //synchronous reset   			                  
      //LSFR		                  
      //----		                  
      .advance_i                          (advance_out_ptr),   //switch to next LSFR state
      .lsfr_o                             (out_ptr),           //current LSFR state
      .lsfr_next_o                        (out_ptr_next));     //next LSFR state

   //FIFO Status
   //-----------
   assign fifo_empty = ~|(in_ptr      ^ out_ptr);              //FIFO is empty
   assign fifo_full  = ~|(in_ptr_next ^ out_ptr);              //FIFO is full
 
   //FIFO reads
   //----------

    input  wire [ITR_CNT-1:0]              out_stb_i,          //access request            
   assign out_ack_o,          //acknowledge     
   assign out_rty_o,          //retry request (buffer is empty)            
   assign out_stall_o = rdbus_stall_i;                    //access delay  
   assign out_dat_o   = rdbus_dat_i;                      //read data bus             



    assign rdbus_cyc_o,        //bus cycle indicator    
    assign rdbus_stb_o,        //access request         
    assign rdbus_adr_o,        //address bus            
    input  wire                            rdbus_ack_i,        //bus cycle acknowledge  
    input  wire [DAT_WIDTH-1:0]            rdbus_dat_i);       //read data bus          

					   
   
   
   //FIFO writes
   //-----------

   
   
   


endmodule // RVC_fifo
