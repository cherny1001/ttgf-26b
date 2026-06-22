
`define LEVELS 5
`define DATA_WIDTH 8

`default_nettype none

module invert_el #
(
 parameter ADDR
)
(
 input wire                   cfg,
 input wire [`DATA_WIDTH-1:0]  in_data,
 output wire [`DATA_WIDTH-1:0] out_data
 );

   assign out_data = cfg ? in_data : in_data ^ ADDR;
   
endmodule // invert_el


module less_el #
(
 parameter LEVEL,
 parameter ADDR
)
(
 input wire                   cfg,
 input wire                   clk, 
 input wire [`DATA_WIDTH-1:0]  in0_data,
 input wire [`DATA_WIDTH-1:0]  in1_data,
 output wire [`DATA_WIDTH-1:0] out_data
 );

   reg                        from_0;
   
   assign out_data = cfg ? in0_data : (from_0 ? in0_data : in1_data);

   always @(posedge clk) begin
       if (cfg) begin
           from_0 <= in0_data[LEVEL] == 0;
       end
   end
endmodule // less_el


  
module more_el #
(
 parameter LEVEL,
 parameter ADDR
)
(
 input wire                   cfg,
 input wire                   clk, 
 input wire [`DATA_WIDTH-1:0]  in_data,
 output wire [`DATA_WIDTH-1:0] out0_data,
 output wire [`DATA_WIDTH-1:0] out1_data
 );

   reg                        to_0;
      
   assign out0_data = cfg ? in_data : (to_0 ? in_data : ADDR);
   assign out1_data = cfg ? in_data : (to_0 ? ADDR : in_data);

   always @(posedge clk) begin
       if (cfg) begin
           to_0 <= in_data[LEVEL] == 0;
       end
   end
endmodule // more_el



module tt_um_cherny_xor_8bi (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  //assign uo_out  = ui_in ^ uio_in;  // Example: ou_out is the XOR of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};
    wire cfg = uio_in[0];


   localparam first_inv_attr = 1 << `LEVELS;
   localparam el_cnt = first_inv_attr -1;
   localparam link_cnt = 1<<(`LEVELS + 1);

   function automatic integer floor_log2;
    input integer value;
    integer tmp;
    begin
        tmp = value;
        floor_log2 = 0;
        while (tmp > 1) begin
            tmp = tmp >> 1;
            floor_log2 = floor_log2 + 1;
        end
    end
   endfunction // floor_log2

   generate
      genvar  a;

      wire [`DATA_WIDTH-1:0] link_D[1:link_cnt];
      wire [`DATA_WIDTH-1:0] link_U[1:link_cnt];
       assign link_D[1] = ui_in;
       assign uo_out = link_U[1];
       
       for (a = 1; a <= el_cnt; a = a +1) begin: addr
          localparam lev = `LEVELS - floor_log2(a) -1;
          localparam n0 = a << 1;
          localparam n1 = (a << 1) + 1;

           more_el #(.LEVEL(lev), .ADDR(a))
           Dx (.cfg(cfg), .clk(clk),
               .in_data(link_D[a]),
               .out0_data(link_D[n0]),
               .out1_data(link_D[n1]));
           
           less_el #(.LEVEL(lev), .ADDR(a))
           Ux (.cfg(cfg), .clk(clk),
                      .in0_data(link_U[n0]),
                      .in1_data(link_U[n1]),
                      .out_data(link_U[a]));
       end // block: a

       for (a = 0; a <= el_cnt; a = a +1) begin: inv
          localparam n = first_inv_attr + a;
           
                      
           invert_el #(.ADDR(a))
           Ix  (.cfg(cfg),
                .in_data(link_D[n]),
                .out_data(link_U[n]));
     
       end

   endgenerate
       
    
endmodule
    
