// sstv_pixel.v
//
// Author: Jack Bradach
//
// Simple combinatorial logic block that maps the
// incoming frequency (between 1500Hz and 2300Hz)
// to one of four colors (Black, white, and two
// shades of gray).  If a frequency out of range
// is detected, the color is forced to black. 
module sstv_pixel (
    input   reset,
    input   [11:0]  freq,
    output  reg [1:0] color
);


    localparam PIXEL_BLACK     = 2'b00;
    localparam PIXEL_DARKGRAY  = 2'b01;
    localparam PIXEL_LIGHTGRAY = 2'b10;
    localparam PIXEL_WHITE     = 2'b11;

    localparam FREQ_BLACK_LOWER = 12'd1500;
    localparam FREQ_BLACK_UPPER = 12'd1700;
    localparam FREQ_GRAY_MIDDLE = 12'd1900;
    localparam FREQ_WHITE_LOWER = 12'd2100;
    localparam FREQ_WHITE_UPPER = 12'd2300;

    // Simple combinatorial logic to map the 
    // received frequencies into one of four
    // "color bins."
    always @(*)
        if (reset)
            color = 0;
        else begin
            // White
            if ((freq > FREQ_WHITE_LOWER) && 
                (freq <= FREQ_WHITE_UPPER))
                    color = PIXEL_WHITE;
            else
            // Light Gray
            if ((freq > FREQ_GRAY_MIDDLE) && 
                (freq <= FREQ_WHITE_LOWER))
                    color = PIXEL_LIGHTGRAY;
            else
            // Dark Gray
            if ((freq > FREQ_BLACK_UPPER) && 
                (freq <= FREQ_GRAY_MIDDLE))
                    color = PIXEL_DARKGRAY;
            else
            // Black
                color = PIXEL_BLACK;
        end

endmodule
