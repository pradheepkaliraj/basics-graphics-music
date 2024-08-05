`include "config.svh"

module a_plus_b_using_fifos
# (
    parameter width = 8, depth = 10
)
(
    input                clk,
    input                rst,

    input                a_valid,
    output               a_ready,
    input  [width - 1:0] a_data,

    input                b_valid,
    output               b_ready,
    input  [width - 1:0] b_data,

    output               sum_valid,
    input                sum_ready,
    output [width - 1:0] sum_data
);

    //------------------------------------------------------------------------

    wire               a_down_valid;
    wire               a_down_ready;
    wire [width - 1:0] a_down_data;

    //------------------------------------------------------------------------

    ff_fifo_wrapped_in_valid_ready
    # (.width (width), .depth (depth))
    fifo_a
    (
        .clk         ( clk          ),
        .rst         ( rst          ),

        .up_valid    ( a_valid      ),
        .up_ready    ( a_ready      ),
        .up_data     ( a_data       ),

        .down_valid  ( a_down_valid ),
        .down_ready  ( a_down_ready ),
        .down_data   ( a_down_data  )
    );

    //------------------------------------------------------------------------

    wire               b_down_valid;
    wire               b_down_ready;
    wire [width - 1:0] b_down_data;

    //------------------------------------------------------------------------

    ff_fifo_wrapped_in_valid_ready
    # (.width (width), .depth (depth))
    fifo_b
    (
        .clk         ( clk          ),
        .rst         ( rst          ),

        .up_valid    ( b_valid      ),
        .up_ready    ( b_ready      ),
        .up_data     ( b_data       ),

        .down_valid  ( b_down_valid ),
        .down_ready  ( b_down_ready ),
        .down_data   ( b_down_data  )
    );

    //------------------------------------------------------------------------

    wire               sum_up_valid = a_down_valid & b_down_valid;
    wire               sum_up_ready;
    wire [width - 1:0] sum_up_data  = a_down_data  + b_down_data;

    assign a_down_ready = b_down_valid & sum_up_ready;
    assign b_down_ready = a_down_valid & sum_up_ready;

    //------------------------------------------------------------------------

    ff_fifo_wrapped_in_valid_ready
    # (.width (width), .depth (depth))
    fifo_sum
    (
        .clk         ( clk          ),
        .rst         ( rst          ),

        .up_valid    ( sum_up_valid ),
        .up_ready    ( sum_up_ready ),
        .up_data     ( sum_up_data  ),

        .down_valid  ( sum_valid    ),
        .down_ready  ( sum_ready    ),
        .down_data   ( sum_data     )
    );

    //------------------------------------------------------------------------

endmodule
