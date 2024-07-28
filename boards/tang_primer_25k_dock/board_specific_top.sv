// TODO
// Parameterize red, green, blue width
// Create a variant of 25K with 7-segment, leds and buttons on pmod.

`include "config.svh"
`include "lab_specific_config.svh"

module board_specific_top
# (
    parameter   clk_mhz   = 50,
                pixel_mhz = 25,
                w_key     = 2,
                w_sw      = 0,
                w_led     = 0,
                w_digit   = 0,

                w_red     = 8,
                w_green   = 8,
                w_blue    = 8,

                w_gpio    = 38

                // gpio 0..5 are reserved for INMP 441 I2S microphone.
                // Odd gpio 17..27 are reserved I2S audio.
                // Odd gpio 29..37 are reserved for TM1638.
)
(
    input                  clk,
    input  [w_key  - 1:0]  key,

    input                  serial_rx,
    output                 serial_tx,

    inout  [w_gpio - 1:0]  gpio,

    //`ifdef ENABLE_DVI

    output                 tmds_clk_n,
    output                 tmds_clk_p,
    output [         2:0]  tmds_d_n,
    output [         2:0]  tmds_d_p,

    //`endif

    //inout  [         7:0]  pmod_0,
    inout  [         7:0]  pmod_1,
    inout  [         7:0]  pmod_2
);

    //------------------------------------------------------------------------

    localparam w_tm_key    = 8,
               w_tm_led    = 8,
               w_tm_digit  = 8;

    //------------------------------------------------------------------------

    wire  [w_tm_key    - 1:0] tm_key;
    wire                      rst = tm_key [w_tm_key - 1];

    wire  [w_tm_led    - 1:0] led;

    wire  [              7:0] abcdefgh;
    wire  [w_tm_digit  - 1:0] digit;

     
    wire                      clk_hdl;
    wire                      clk_hd;
    wire                      clk_px;
    wire                      pll_lock;
    wire                      sys_resetn;
    wire                      display_on;

    wire                      vsync;
    wire                      hsync;

    wire  [w_red       - 1:0] red;
    wire  [w_green     - 1:0] green;
    wire  [w_blue      - 1:0] blue;

    wire  [             23:0] mic;
    wire  [             15:0] sound;

    int cnt, cnt_100;

    //------------------------------------------------------------------------

    wire slow_clk;

    slow_clk_gen # (.fast_clk_mhz (clk_mhz), .slow_clk_hz (1))
    i_slow_clk_gen (.slow_clk (slow_clk), .*);

    //------------------------------------------------------------------------

    top
    # (
        .clk_mhz   ( clk_mhz    ),
        .pixel_mhz ( pixel_mhz  ),

        .w_key     ( w_tm_key   ),
        .w_sw      ( w_tm_key   ),
        .w_led     ( w_tm_led   ),
        .w_digit   ( w_tm_digit ),

        .w_red     ( w_red      ),
        .w_green   ( w_green    ),
        .w_blue    ( w_blue     ),

        .w_gpio    ( w_gpio     )
    )
    i_top
    (
        .clk       ( clk        ),
        .slow_clk  ( slow_clk   ),
        .rst       ( rst        ),

        .key       ( tm_key     ),
        .sw        ( tm_key     ),

        .led       ( led        ),

        .abcdefgh  ( abcdefgh   ),
        .digit     ( digit      ),

        .vsync     ( vsync      ),
        .hsync     ( hsync      ),

        .display_on (display_on),
<<<<<<< HEAD
        .pixel_clk  (clk_px),
=======
        .pixel_clk  (pixel_clk),
>>>>>>> b0a0c35710ac5178539e7c9f3513d395b6104e17

        .red       ( red        ),
        .green     ( green      ),
        .blue      ( blue       ),

        .uart_rx   ( serial_rx  ),
        .uart_tx   ( serial_tx  ),

        .mic       ( mic        ),
        .sound     ( sound      ),

        .gpio      ( gpio       )
    );

    //------------------------------------------------------------------------

    wire [$left (abcdefgh):0] hgfedcba;

    generate
        genvar i;

        for (i = 0; i < $bits (abcdefgh); i ++)
        begin : abc
            assign hgfedcba [i] = abcdefgh [$left (abcdefgh) - i];
        end
    endgenerate

    //------------------------------------------------------------------------

    inmp441_mic_i2s_receiver i_microphone
    (
        .clk   ( clk        ),
        .rst   ( rst        ),
        .lr    ( gpio   [0] ),
        .ws    ( gpio   [2] ),
        .sck   ( gpio   [4] ),
        .sd    ( gpio   [5] ),
        .value ( mic        )
    );

    assign gpio [1] = 1'b0;  // GND
    assign gpio [3] = 1'b1;  // VCC

    //------------------------------------------------------------------------

    i2s_audio_out
    # (
        .clk_mhz ( clk_mhz     )
    )
    i_audio
    (
        .clk     ( clk       ),
        .reset   ( rst       ),
        .data_in ( sound     ),

        .mclk    ( /*pmod_0[4]*/ ),
        .bclk    ( /*pmod_0[5]*/ ),
        .sdata   ( /*pmod_0[6]*/ ),
        .lrclk   ( /*pmod_0[7]*/ )
    );

    //------------------------------------------------------------------------

    tm1638_board_controller
    # (
        .clk_mhz ( clk_mhz    ),
        .w_digit ( w_tm_digit )
    )
    i_tm1638
    (
        .clk        ( clk       ),
        .rst        ( rst       ),
        .hgfedcba   ( hgfedcba  ),
        .digit      ( digit     ),
        .ledr       ( led       ),
        .keys       ( tm_key    ),
        .sio_clk    ( gpio [35] ),
        .sio_stb    ( gpio [33] ),
        .sio_data   ( gpio [37] )
    );

    assign gpio [31] = 1'b0;
    assign gpio [29] = 1'b1;

    //------------------------------------------------------------------------

    //`ifdef ENABLE_DVI

    Gowin_PLL pll_inst(
        .lock(pll_lock), //output lock
        .clkout0(clk_hdl), //output clkout0
        .clkin(clk) //input clkin
    );
    //BUFG clHD(.I(clk_hdl), .O(clk_hd));

    DVI_TX_PK  i_dvi_tx
    (
        .I_rst_n        ( ~rst  && pll_lock ),
        .I_serial_clk ( clk_hdl      ), //input I_serial_clk
        .I_rgb_clk    ( clk_px      ), //input I_rgb_clk
        .I_rgb_vs       (   ~vsync       ),
        .I_rgb_hs       (   ~hsync       ),
        .I_rgb_de       ( display_on  ), //input I_rgb_de
        .I_rgb_r        (   red         ),
        .I_rgb_g        (   green       ),
        .I_rgb_b        (   blue        ),
        .O_tmds_clk_p   (   tmds_clk_p  ),
        .O_tmds_clk_n   (   tmds_clk_n  ),
        .O_tmds_data_p  (   tmds_data_p ),
        .O_tmds_data_n  (   tmds_data_n )
    );

<<<<<<< HEAD
    // assign led [0] = display_on; ALL inputs are toggling
    // assign led [1] = vsync;
    // assign led [2] = hsync;
    // assign led [3] = pll_lock;
    // assign led [4] = red;
    // assign led [5] = green;
    // assign led [6] = cnt_100;
    // //assign led [7] = clk_px;


always @(posedge clk_hdl) begin
    cnt = cnt + 1;
    if(cnt == 'd100)
     cnt_100 <= 1'b1;

end
=======
>>>>>>> b0a0c35710ac5178539e7c9f3513d395b6104e17
    //`endif

    //------------------------------------------------------------------------

    // Pmod VGA

    assign pmod_1 = { green [7:4], 2'b0, vsync, hsync };
    assign pmod_2 = { red   [7:4], blue [7:4] };

endmodule
