//###############################################################################
//# RVC - Reusable Verilog Components - Linear Feedback Shift Register          #
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
//#    This module implements a Fibunacci-LSFR with XNOR feedback and           #
//#    configurable cycle length.                                               #
//#                                                                             #
//#    INCLUDE_LOCK_UP:                                                         #
//#     If this parameter is set to zero, then the module generate a LSFR       #
//#     sequence of (2**WIDTH)-1 states. The "lock-up" state {WIDTH{1'b1}} will #
//#     be omittet.                                                             #
//#     If this parameter is set to a non-zero value, then the module generate  #
//#     a sequence of (2**WIDTH) states, including the "lock-up" state.         #
//#                                                                             #
//#    SKIP_FROM and SKIP_TO:                                                   #
//#     These parameters will only take effect if set to unequal values. In     #
//#     this case the state sequence will be altered and state SKIP_TO will     #
//#     follow state SKIP_FROM.                                                 #
//#                                                                             #
//###############################################################################
//# Version History:                                                            #
//#   May 20, 2019                                                              #
//#      - Initial release                                                      #
//###############################################################################
`default_nettype none

module RVC_lsfr
  #(parameter WIDTH           =  8,                                                  //width of the shift register
    parameter INCLUDE_LOCK_UP =  0,                                                  //include "lock-up" state (-1)
    parameter SKIP_FROM       =  0,                                                       //last state before skipped sequence
    parameter SKIP_TO         =  0,                                                       //first state after skipped sequence
    parameter RESET_STATE     =  0)                                                       //reset state

   (//Clock and reset
    //---------------
    input wire                             clk_i,                                    //module clock
    input wire                             async_rst_i,                              //asynchronous reset
    input wire                             sync_rst_i,                               //synchronous reset

    //LSFR
    //----
    input  wire                            advance_i,                                //switch to next LSFR state
    output wire [WIDTH-1:0]                lsfr_o,                                   //current LSFR state
    output wire [WIDTH-1:0]                lsfr_next_o);                             //next LSFR state

   //Parameters
   //----------
   //Polynom
   parameter POLYNOM = (WIDTH ==  2) ? 32'b00000000_00000000_00000000_00000011 :     // 2,  1
                       (WIDTH ==  3) ? 32'b00000000_00000000_00000000_00000110 :     // 3,  2
                       (WIDTH ==  4) ? 32'b00000000_00000000_00000000_00001100 :     // 4,  3
                       (WIDTH ==  5) ? 32'b00000000_00000000_00000000_00010100 :     // 5,  3
                       (WIDTH ==  6) ? 32'b00000000_00000000_00000000_00110000 :     // 6,  5
                       (WIDTH ==  7) ? 32'b00000000_00000000_00000000_01100000 :     // 7,  6
                       (WIDTH ==  8) ? 32'b00000000_00000000_00000000_10111000 :     // 8,  6,  5,  4
                       (WIDTH ==  9) ? 32'b00000000_00000000_00000001_00010000 :     // 9,  5
                       (WIDTH == 10) ? 32'b00000000_00000000_00000010_01000000 :     //10,  7
                       (WIDTH == 11) ? 32'b00000000_00000000_00000101_00000000 :     //11,  9
                       (WIDTH == 12) ? 32'b00000000_00000000_00001100_10100000 :     //12, 11,  8,  6
                       (WIDTH == 13) ? 32'b00000000_00000000_00011011_00000000 :     //13, 12, 10,  9
                       (WIDTH == 14) ? 32'b00000000_00000000_00110101_00000000 :     //14, 13, 11,  9
                       (WIDTH == 15) ? 32'b00000000_00000000_01100000_00000000 :     //15, 14
                       (WIDTH == 16) ? 32'b00000000_00000000_10110100_00000000 :     //16, 14, 13, 11
                       (WIDTH == 17) ? 32'b00000000_00000001_00100000_00000000 :     //17, 14
                       (WIDTH == 18) ? 32'b00000000_00000010_00000100_00000000 :     //18, 11
                       (WIDTH == 19) ? 32'b00000000_00000111_00100000_00000000 :     //19, 18, 17, 14
                       (WIDTH == 20) ? 32'b00000000_00001001_00000000_00000000 :     //20, 17
                       (WIDTH == 21) ? 32'b00000000_00010100_00000000_00000000 :     //21, 19
                       (WIDTH == 22) ? 32'b00000000_00110000_00000000_00000000 :     //22, 21
                       (WIDTH == 23) ? 32'b00000000_01000010_00000000_00000000 :     //23, 18
                       (WIDTH == 24) ? 32'b00000000_11011000_00000000_00000000 :     //24, 23, 21, 20
                       (WIDTH == 25) ? 32'b00000001_00100000_00000000_00000000 :     //25, 22
                       (WIDTH == 26) ? 32'b00000011_10001000_00000000_00000000 :     //26, 25, 24, 20
                       (WIDTH == 27) ? 32'b00000111_00100000_00000000_00000000 :     //27, 26, 25, 22
                       (WIDTH == 28) ? 32'b00001001_00000000_00000000_00000000 :     //28, 25
                       (WIDTH == 29) ? 32'b00010100_00000000_00000000_00000000 :     //29, 27
                       (WIDTH == 30) ? 32'b00110010_10000000_00000000_00000000 :     //30, 29, 26, 24
                       (WIDTH == 31) ? 32'b01001000_00000000_00000000_00000000 :     //31, 28
                       (WIDTH == 32) ? 32'b10100011_00000000_00000000_00000000 :     //32, 30, 26, 25
                                       32'bxxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx;

   //Internal signals
   //----------------
   //Polynom
   wire [WIDTH-1:0]                        polynom;                                  //bit mask to determine feedback

   //Sequence skipping
   wire [WIDTH-1:0]                        skip_from;                                //determined by parameter SKIP_FROM
   wire [WIDTH-1:0]                        skip_to;                                  //determined by parameter SKIP_TO

   //Next state
   reg  [WIDTH-1:0]                        lsfr_reg;                                 //current LSFR state
   wire [WIDTH-1:0]                        lsfr_next;                                //next LSFR state

   //Calculate next state
   //--------------------
   assign polynom    = POLYNOM[WIDTH-1:0];                                           //bit mask to determine feedback
   assign skip_from  = SKIP_FROM[WIDTH-1:0];                                         //last state before skipped sequence
   assign skip_to    = SKIP_TO[WIDTH-1:0];                                           //first state after skipped sequence
   assign lsfr_next  = (|(SKIP_FROM ^ SKIP_TO) & ~|(skip_from ^ lsfr_reg)) ?         //skip condition
                       skip_to :                                                     //skip destination
                       {skip_from[WIDTH-1:1],                                        //shift upper bits
                        ~^(polynom & skip_from) ^                                    //feedback from polynom
                        (|INCLUDE_LOCK_UP & &skip_from[WIDTH-2:0])};                 //handle "lock-up" state

   //Shift register
   //--------------
   always @(posedge async_rst_i or posedge clk_i)
     if(async_rst_i)                                                                 //asynchronous reset
       lsfr_reg <= RESET_STATE[WIDTH-1:0];                                           //reset state
     else if(sync_rst_i)                                                             //synchronous reset
       lsfr_reg <= RESET_STATE[WIDTH-1:0];                                           //reset state
     else if (advance_i)                                                             //shift request
       lsfr_reg <= lsfr_next;                                                        //next state

   assign lsfr_o      = lsfr_reg;                                                    //current LSFR state
   assign lsfr_next_o = lsfr_next;                                                   //next LSFR state

endmodule // RVC_lsfr
