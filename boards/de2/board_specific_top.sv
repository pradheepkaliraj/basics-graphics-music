`include "config.svh"
`include "lab_specific_board_config.svh"

module board_specific_top
# (
    parameter clk_mhz = 50,
              w_key   = 4,
              w_sw    = 18,         // One onboard SW is used as a reset
              w_led   = 26,
              w_digit = 8,
              w_gpio  = 72,         // GPIO[5:0] reserved for mic
              vga_clock = 25        // Pixel clock of VGA in MHz, recommend be equal with VGA_CLOCK from labs/common/vga.sv
)
(
    input                CLOCK_50,

    input  [w_key  - 1:0] KEY,
    input  [w_sw   - 1:0] SW,

    input                 UART_RXD,
    output                UART_TXD,

    output [        17:0] LEDR,     // The last 8 LEDR are used like a 7SEG dp
    output [         7:0] LEDG,

    output logic [     6:0] HEX0,    // HEX[7] aka dp doesn't connected to FPGA at DE2 board
    output logic [     6:0] HEX1,
    output logic [     6:0] HEX2,
    output logic [     6:0] HEX3,
    output logic [     6:0] HEX4,
    output logic [     6:0] HEX5,
    output logic [     6:0] HEX6,
    output logic [     6:0] HEX7,

    output                  VGA_CLK, // VGA DAC input triggers CLK
    output                  VGA_HS,
    output                  VGA_VS,
    output [           9:0] VGA_R,
    output [           9:0] VGA_G,
    output [           9:0] VGA_B,
    output                  VGA_BLANK,
    output                  VGA_SYNC,

    inout  [        35:0] GPIO_0,
    inout  [        35:0] GPIO_1
);

    //------------------------------------------------------------------------

    localparam w_lab_sw = w_sw - 1;  // One onboard SW is used as a reset

    wire                  clk = CLOCK_50;

    wire                  rst    = SW [w_lab_sw];
    wire [w_lab_sw - 1:0] lab_sw = SW [w_lab_sw - 1:0];
    wire [w_key    - 1:0] lab_key = ~ KEY;

    //------------------------------------------------------------------------
    wire [ w_led - w_digit - 1:0] lab_led;

    wire [                   7:0] abcdefgh;
    wire [         w_digit - 1:0] digit;

    wire  [                  3:0] vga_red_4b,vga_green_4b,vga_blue_4b;

    wire [                  23:0] mic;
    wire [                  15:0] sound;

    //------------------------------------------------------------------------

    wire slow_clk;

    slow_clk_gen # (.fast_clk_mhz (clk_mhz), .slow_clk_hz (1))
    i_slow_clk_gen (.slow_clk (slow_clk), .*);

    //------------------------------------------------------------------------

    lab_top
    # (
        .clk_mhz  ( clk_mhz         ),
        .w_key    ( w_key           ),
        .w_sw     ( w_lab_sw        ),
        .w_led    ( w_led - w_digit ),              // The last 8 LEDR are used like a 7SEG dp
        .w_digit  ( w_digit         ),
        .w_gpio   ( w_gpio          )               // GPIO[5:0] reserved for mic
    )
    i_lab_top
    (
        .clk      (   clk                  ),
        .slow_clk (   slow_clk             ),
        .rst      (   rst                  ),

        .key      (   lab_key              ),
        .sw       (   lab_sw               ),

        .led      (   lab_led              ),

        .abcdefgh (   abcdefgh             ),
        .digit    (   digit                ),

        .vsync    (   VGA_VS               ),
        .hsync    (   VGA_HS               ),

        .red      (   vga_red_4b           ),
        .green    (   vga_green_4b         ),
        .blue     (   vga_blue_4b          ),

        .uart_rx  (   UART_RXD             ),
        .uart_tx  (   UART_TXD             ),

        .mic      (   mic                  ),
        .sound    (   sound                ),

        .gpio     (   { GPIO_0, GPIO_1 }   )
    );

    //------------------------------------------------------------------------

    assign { LEDR [$left(LEDR) - w_digit:0], LEDG } = lab_led; // Last 8 LEDR are used like a 7SEG dp

    assign VGA_R   = { vga_red_4b,   4'd0 };
    assign VGA_G   = { vga_green_4b, 4'd0 };
    assign VGA_B   = { vga_blue_4b,  4'd0 };

    assign VGA_BLANK = 1'b1;
    assign VGA_SYNC  = 0;

    // Divide VGA DAC clock from clk_mhz to vga_clock
    localparam CLK_DIV = $clog2 (clk_mhz / vga_clock) - 1;

    logic [CLK_DIV:0] clk_en_cnt;
    logic clk_en;

    always_ff @ (posedge clk or posedge rst)
    begin
        if (rst)
        begin
            clk_en_cnt <= 'b0;
            clk_en     <= 'b0;
        end
        else
        begin
            if (clk_en_cnt == (clk_mhz / vga_clock) - 1)
            begin
                clk_en_cnt <= 'b0;
                clk_en     <= 'b1;
            end
            else
            begin
                clk_en_cnt <= clk_en_cnt + 1;
                clk_en     <= 'b0;
            end
        end
    end

    assign VGA_CLK = clk_en;

    //------------------------------------------------------------------------

    wire  [$left (abcdefgh):0] hgfedcba;
    logic [$left    (digit):0] dp;

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

        assign HEX0 = digit [0] ? ~ hgfedcba [$left (HEX0):0] : '1;
        assign HEX1 = digit [1] ? ~ hgfedcba [$left (HEX1):0] : '1;
        assign HEX2 = digit [2] ? ~ hgfedcba [$left (HEX2):0] : '1;
        assign HEX3 = digit [3] ? ~ hgfedcba [$left (HEX3):0] : '1;
        assign HEX4 = digit [4] ? ~ hgfedcba [$left (HEX4):0] : '1;
        assign HEX5 = digit [5] ? ~ hgfedcba [$left (HEX5):0] : '1;
        assign HEX6 = digit [6] ? ~ hgfedcba [$left (HEX6):0] : '1;
        assign HEX7 = digit [7] ? ~ hgfedcba [$left (HEX7):0] : '1;

        // positive logic

        assign LEDR [    w_led - w_digit] = digit [0] ? hgfedcba [$left (HEX0) + 1] : '0;
        assign LEDR [w_led - w_digit + 1] = digit [1] ? hgfedcba [$left (HEX1) + 1] : '0;
        assign LEDR [w_led - w_digit + 2] = digit [2] ? hgfedcba [$left (HEX2) + 1] : '0;
        assign LEDR [w_led - w_digit + 3] = digit [3] ? hgfedcba [$left (HEX3) + 1] : '0;
        assign LEDR [w_led - w_digit + 4] = digit [4] ? hgfedcba [$left (HEX4) + 1] : '0;
        assign LEDR [w_led - w_digit + 5] = digit [5] ? hgfedcba [$left (HEX5) + 1] : '0;
        assign LEDR [w_led - w_digit + 6] = digit [6] ? hgfedcba [$left (HEX6) + 1] : '0;
        assign LEDR [w_led - w_digit + 7] = digit [7] ? hgfedcba [$left (HEX7) + 1] : '0;

    `else

        always_ff @ (posedge clk or posedge rst)
        begin
            if (rst)
            begin
                { HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7 } <= '1;
                dp <= '0;
            end
            else
            begin
                if (digit [0]) HEX0 <= ~ hgfedcba [$left (HEX0):0];
                if (digit [1]) HEX1 <= ~ hgfedcba [$left (HEX1):0];
                if (digit [2]) HEX2 <= ~ hgfedcba [$left (HEX2):0];
                if (digit [3]) HEX3 <= ~ hgfedcba [$left (HEX3):0];
                if (digit [4]) HEX4 <= ~ hgfedcba [$left (HEX4):0];
                if (digit [5]) HEX5 <= ~ hgfedcba [$left (HEX5):0];
                if (digit [6]) HEX6 <= ~ hgfedcba [$left (HEX6):0];
                if (digit [7]) HEX7 <= ~ hgfedcba [$left (HEX7):0];

                if (digit [0]) dp[0] <=  hgfedcba [$left (HEX0) + 1];
                if (digit [1]) dp[1] <=  hgfedcba [$left (HEX1) + 1];
                if (digit [2]) dp[2] <=  hgfedcba [$left (HEX2) + 1];
                if (digit [3]) dp[3] <=  hgfedcba [$left (HEX3) + 1];
                if (digit [4]) dp[4] <=  hgfedcba [$left (HEX4) + 1];
                if (digit [5]) dp[5] <=  hgfedcba [$left (HEX5) + 1];
                if (digit [6]) dp[6] <=  hgfedcba [$left (HEX6) + 1];
                if (digit [7]) dp[7] <=  hgfedcba [$left (HEX7) + 1];
            end
        end

        assign LEDR [$left(LEDR):$left(LEDR) - w_digit + 1] = dp;  // The last 4 LEDR are used like a 7SEG dp

    `endif

    //------------------------------------------------------------------------

    inmp441_mic_i2s_receiver i_microphone
    (
        .clk   (   clk          ),
        .rst   (   rst          ),
        .lr    (   GPIO_1 [0]   ), // JP2 pin 1
        .ws    (   GPIO_1 [2]   ), // JP2 pin 3
        .sck   (   GPIO_1 [4]   ), // JP2 pin 5
        .sd    (   GPIO_1 [5]   ), // JP2 pin 6
        .value (   mic          )
    );

    assign GPIO_1 [1] = 1'b0;      // GND - JP2 pin 2
    assign GPIO_1 [3] = 1'b1;      // VCC - JP2 pin 4

    //------------------------------------------------------------------------

    i2s_audio_out
    # (
        .clk_mhz ( clk_mhz      )
    )
    inst_audio_out
    (
        .clk     ( clk          ),
        .reset   ( rst          ),
        .data_in ( sound        ),
        .mclk    ( GPIO_1 [29]  ), // JP2 pin 38
        .bclk    ( GPIO_1 [27]  ), // JP2 pin 36
        .lrclk   ( GPIO_1 [23]  ), // JP2 pin 32
        .sdata   ( GPIO_1 [25]  )  // JP2 pin 34
    );                             // JP2 pin 30 - GND, pin 29 - VCC 3.3V (30-45 mA)

endmodule
