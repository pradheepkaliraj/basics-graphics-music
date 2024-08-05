`include "config.svh"

module lab_top
# (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,

               screen_width  = 640,
               screen_height = 480,

               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,

               w_x           = $clog2 ( screen_width  ),
               w_y           = $clog2 ( screen_height )
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,

    // Keys, switches, LEDs

    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,

    // A dynamic seven-segment display

    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,

    // Graphics

    input        [w_x     - 1:0] x,
    input        [w_y     - 1:0] y,

    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,

    // Microphone, sound output and UART

    input        [         23:0] mic,
    output       [         15:0] sound,

    input                        uart_rx,
    output                       uart_tx,

    // General-purpose Input/Output

    inout        [w_gpio  - 1:0] gpio
);

    //------------------------------------------------------------------------

    // assign led        = '0;
    // assign abcdefgh   = '0;
    // assign digit      = '0;
       assign red        = '0;
       assign green      = '0;
       assign blue       = '0;
    // assign sound      = '0;
       assign uart_tx    = '1;

    //------------------------------------------------------------------------

    wire            [2:0] octave = 3'b0;
    wire  [w_key   - 1:0] note   = key;

    assign led  = note;

    //------------------------------------------------------------------------

    tone_sel
    # (
        .clk_mhz    (clk_mhz),
        .note_width (w_key)
    )
    wave_gen
    (
        .clk       ( clk       ),
        .reset     ( rst       ),
        .octave    ( octave    ),
        .note      ( note      ),
        .y         ( sound     )
    );

    //------------------------------------------------------------------------

    assign digit = { {(w_digit - 1){1'b0}}, 1'b1};

    always_ff @ (posedge clk or posedge rst)
        if (rst)
            abcdefgh <= 'b00000000;
        else
            case (note)
            'd0:    abcdefgh <= 'b10011100;  // C   // abcdefgh
            'd1:    abcdefgh <= 'b10011101;  // C#
            'd2:    abcdefgh <= 'b01111010;  // D   //   --a--
            'd3:    abcdefgh <= 'b01111011;  // D#  //  |     |
            'd4:    abcdefgh <= 'b10011110;  // E   //  f     b
            'd5:    abcdefgh <= 'b10001110;  // F   //  |     |
            'd6:    abcdefgh <= 'b10001111;  // F#  //   --g--
            'd7:    abcdefgh <= 'b10111100;  // G   //  |     |
            'd8:    abcdefgh <= 'b10111101;  // G#  //  e     c
            'd9:    abcdefgh <= 'b11101110;  // A   //  |     |
            'd10:   abcdefgh <= 'b11101111;  // A#  //   --d--  h
            'd11:   abcdefgh <= 'b00111110;  // B
            default: abcdefgh <= 'b00000000;
            endcase

endmodule
