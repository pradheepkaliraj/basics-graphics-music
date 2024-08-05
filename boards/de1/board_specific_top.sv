`include "config.svh"
`include "lab_specific_board_config.svh"

module board_specific_top
# (
    parameter clk_mhz       = 50,
              pixel_mhz     = 25,

              w_key         = 4,
              w_sw          = 10,        // One onboard SW is used as a reset
              w_led         = 8,
              w_digit       = 4,
              w_gpio        = 72,        // GPIO_1[5:0] reserved for mic

              // gpio 0..5 are reserved for INMP 441 I2S microphone.
              // Odd gpio .. are reserved I2S audio.

              screen_width  = 640,
              screen_height = 480,

              w_red         = 4,
              w_green       = 4,
              w_blue        = 4,

              w_x           = $clog2 ( screen_width  ),
              w_y           = $clog2 ( screen_height )
)
(
    input                   CLOCK_50,

    input  [w_key    - 1:0] KEY,
    input  [w_sw     - 1:0] SW,
    output logic [     9:0] LEDR,
    output logic [     7:0] LEDG,

    output logic [     6:0] HEX0,  // HEX[7] aka dp are not connected to FPGA at DE1 board
    output logic [     6:0] HEX1,
    output logic [     6:0] HEX2,
    output logic [     6:0] HEX3,

    output                  VGA_HS,
    output                  VGA_VS,
    output [w_red    - 1:0] VGA_R,
    output [w_green  - 1:0] VGA_G,
    output [w_blue   - 1:0] VGA_B,

    input                   UART_RXD,
    output                  UART_TXD,

    inout [w_gpio / 2 - 1:0] GPIO_0,
    inout [w_gpio / 2 - 1:0] GPIO_1
);

    //------------------------------------------------------------------------

    localparam w_lab_sw = w_sw - 1;  // One sw is used as a reset

    //------------------------------------------------------------------------

    wire                    clk     = CLOCK_50;
    wire                    rst     = SW [w_lab_sw];

    // Keys, switches, LEDs

    wire [ w_lab_sw  - 1:0] lab_sw = SW [w_lab_sw - 1:0];

    // A dynamic seven-segment display

    wire [             7:0] abcdefgh;
    wire [ w_digit   - 1:0] digit;

    // Graphics

    wire [ w_x       - 1:0] x;
    wire [ w_y       - 1:0] y;

    wire [ w_red     - 1:0] red;
    wire [ w_green   - 1:0] green;
    wire [ w_blue    - 1:0] blue;

    // Microphone, sound output and UART

    wire [            23:0] mic;
    wire [            15:0] sound;

    //------------------------------------------------------------------------

    wire slow_clk;

    slow_clk_gen # (.fast_clk_mhz (clk_mhz), .slow_clk_hz (1))
    i_slow_clk_gen (.slow_clk (slow_clk), .*);

    //------------------------------------------------------------------------

    lab_top
    # (
        .clk_mhz       (   clk_mhz       ),
        .w_key         (   w_key         ),
        .w_sw          (   w_lab_sw      ),
        .w_led         (   w_led         ),
        .w_digit       (   w_digit       ),
        .w_gpio        (   w_gpio        ),

        .screen_width  (   screen_width  ),
        .screen_height (   screen_height ),

        .w_red         (   w_red         ),
        .w_green       (   w_green       ),
        .w_blue        (   w_blue        )
    )
    i_lab_top
    (
        .clk           (   clk              ),
        .slow_clk      (   slow_clk         ),
        .rst           (   rst              ),

        .key           ( ~ KEY              ),
        .sw            (   lab_sw           ),

        .led           (   LEDG             ),

        .abcdefgh      (   abcdefgh         ),
        .digit         (   digit            ),

        .x             (   x                ),
        .y             (   y                ),

        .red           (   VGA_R            ),
        .green         (   VGA_G            ),
        .blue          (   VGA_B            ),

        .mic           (   mic              ),
        .sound         (   sound            ),

        .uart_rx       (   UART_RXD         ),
        .uart_tx       (   UART_TXD         ),

    .gpio          ( { GPIO_0, GPIO_1 } )
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

    `ifdef EMULATE_DYNAMIC_7SEG_ON_STATIC_WITHOUT_STICKY_FLOPS

        // Pro: This implementation is necessary for the lab 7segment_word
        // to properly demonstrate the idea of dynamic 7-segment display
        // on a static 7-segment display.
        //

        // Con: This implementation makes the 7-segment LEDs dim
        // on most boards with the static 7-sigment display.

        // inverted logic

        assign HEX0  = digit [0] ? ~ hgfedcba [$left (HEX0):0]   : '1;
        assign HEX1  = digit [1] ? ~ hgfedcba [$left (HEX1):0]   : '1;
        assign HEX2  = digit [2] ? ~ hgfedcba [$left (HEX2):0]   : '1;
        assign HEX3  = digit [3] ? ~ hgfedcba [$left (HEX3):0]   : '1;

        // positive logic

        always_comb
        begin
            LEDR = '0;

            for (int i = 0; i < w_digit; i ++)
                LEDR [$bits (LEDR) - w_digit + i]
                    = digit [i] ? hgfedcba [$left (HEX0) + 1] : '0;
        end

    `else

        always_ff @ (posedge clk or posedge rst)
        begin
            if (rst)
            begin
                { HEX0, HEX1, HEX2, HEX3 } <= '1;
                LEDR <= '0;
            end
            else
            begin
                if (digit [0]) HEX0 <= ~ hgfedcba [$left (HEX0):0];
                if (digit [1]) HEX1 <= ~ hgfedcba [$left (HEX1):0];
                if (digit [2]) HEX2 <= ~ hgfedcba [$left (HEX2):0];
                if (digit [3]) HEX3 <= ~ hgfedcba [$left (HEX3):0];

                for (int i = 0; i < w_digit; i ++)
                    if (digit [i])
                        LEDR [$bits (LEDR) - w_digit + i] <=  hgfedcba [$left (HEX0) + 1];
            end
        end

    `endif

    //------------------------------------------------------------------------

    `ifdef INSTANTIATE_GRAPHICS_INTERFACE_MODULE

        wire [9:0] x10; assign x = x10;
        wire [9:0] y10; assign y = y10;

        vga
        # (
            .CLK_MHZ     ( clk_mhz   ),
            .PIXEL_MHZ   ( pixel_mhz )
        )
        i_vga
        (
            .clk         ( clk    ),
            .rst         ( rst    ),
            .hsync       ( VGA_HS ),
            .vsync       ( VGA_VS ),
            .display_on  (        ),
            .hpos        ( x10    ),
            .vpos        ( y10    ),
            .pixel_clk   (        )
        );

    `endif

    //------------------------------------------------------------------------

    `ifdef INSTANTIATE_MICROPHONE_INTERFACE_MODULE

        inmp441_mic_i2s_receiver i_microphone
        (
            .clk   ( clk      ),
            .rst   ( rst      ),
            .lr    ( GPIO_1 [0] ),
            .ws    ( GPIO_1 [2] ),
            .sck   ( GPIO_1 [4] ),
            .sd    ( GPIO_1 [5] ),
            .value ( mic      )
        );

        assign GPIO_1 [1] = 1'b0;  // GND
        assign GPIO_1 [3] = 1'b1;  // VCC

    `endif


    //------------------------------------------------------------------------

    `ifdef INSTANTIATE_SOUND_OUTPUT_INTERFACE_MODULE

        i2s_audio_out
        # (
            .clk_mhz ( clk_mhz   )
        )
        inst_audio_out
        (
            .clk     ( clk       ),
            .reset   ( rst       ),
            .data_in ( sound     ),
            .mclk    ( GPIO_1 [33] ),
            .bclk    ( GPIO_1 [31] ),
            .lrclk   ( GPIO_1 [27] ),
            .sdata   ( GPIO_1 [29] )
        );


    `endif

endmodule
