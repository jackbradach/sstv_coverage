`define OVL_ASSERT_ON 1
`define OVL_INIT_MSG 1
`include "assert_never.vlib"
`include "assert_always.vlib"
module sstv_pixel_tb;
    reg clk;
    reg reset;
    reg  [11:0] freq;
    wire [1:0] color;
    reg  [1:0] color_check;

	reg test_fail;
    wire [6:0] vis_code;
    wire valid;

    localparam CLK_TICKS_30MS   = 32'd3_000;

    sstv_pixel SSTV_PIXEL (
        .reset(reset),
        .freq(freq),
        .color(color)
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

    localparam  FREQ_MAX    = 12'hfff;
    localparam  FREQ_MIN    = 12'h000;
    localparam  FREQ_1900HZ = 12'd1900;
    localparam  FREQ_1300HZ = 12'd1300;
    localparam  FREQ_1200HZ = 12'd1200;
    localparam  FREQ_1100HZ = 12'd1100;

    // Run the clock
    always #100 clk = ~clk;

    initial begin
        // Drive all of our inputs to known states
        clk = 0;
        reset = 1;
		freq = 0;
        test_fail = 0;

        $dumpfile("sstv_pixel.vcd");
        $dumpvars(0);

        @(posedge clk);
        sstv_pixel_decode();

        $dumpflush;
        #100 $finish;

    end

task sstv_pixel_reset;
    integer ticks;
    begin
        ticks = 0;
    
        $display("Starting RESET");
        while (ticks < 10) begin
            @(posedge clk);
            reset = 1'b1;
            ticks = ticks + 1;
        end
        $display("Ending RESET");
        @(posedge clk);
        reset = 1'b0;
    end
endtask

function [1:0] sstv_pixel_colormap;
    input [11:0] freq;
    begin
        // White
        if ((freq > FREQ_WHITE_LOWER) && 
            (freq <= FREQ_WHITE_UPPER))
                sstv_pixel_colormap = PIXEL_WHITE;
        else
        // Light Gray
        if ((freq > FREQ_GRAY_MIDDLE) && 
            (freq <= FREQ_WHITE_LOWER))
                sstv_pixel_colormap = PIXEL_LIGHTGRAY;
        else
        // Dark Gray
        if ((freq > FREQ_BLACK_UPPER) && 
            (freq <= FREQ_GRAY_MIDDLE))
                sstv_pixel_colormap = PIXEL_DARKGRAY;
        else
        // Black
            sstv_pixel_colormap = PIXEL_BLACK;
    end

endfunction

task sstv_pixel_decode;
    integer driven_freq;
    localparam TESTNAME = "sstv_pixel_decode";
    begin
        // Reset block
        sstv_pixel_reset();
        
        $display ("[%s] Starting test @ %g", TESTNAME, $time);

        // Spin through the possible frequencies and verify that the output
        // color is correct.
        for (driven_freq = FREQ_MIN; driven_freq <= FREQ_MAX; driven_freq = driven_freq + 1) begin
            $display ("[%s] Checking color decode for freq = %04d Hz", TESTNAME, driven_freq);
            freq = driven_freq;
            @(posedge clk);
            assign color_check = sstv_pixel_colormap(freq);
            if (color != color_check) begin
                $display("freq: %d Color: %d should be: %d", freq, color, color_check);
                test_fail = 1'b1;
            end
        end


    end
endtask

assert_never #(
    `OVL_ERROR,
    `OVL_ASSERT,
    "TEST FAIL!",
) sstv_pixel_tb_test_fail (
    .clk(clk),
    .reset_n(~reset),
    .test_expr(test_fail)
);


endmodule
