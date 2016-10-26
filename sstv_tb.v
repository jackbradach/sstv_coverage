`define OVL_ASSERT_ON 1
`define OVL_INIT_MSG 1
`include "assert_never.vlib"
`include "assert_always.vlib"
`include "assert_increment.vlib"
module sstv_tb;
    reg clk;
    reg reset;
    reg [11:0] freq;

	reg test_fail;
    
    wire [14:0] vid_addr;
    wire [1:0] vid_pixel;

    wire [6:0] vis_code;
    wire vis_valid;

    localparam CLK_TICKS_10MS   = 32'd1_000;
    localparam CLK_TICKS_30MS   = 32'd3_000;
    localparam CLK_TICKS_300MS  = 32'd30_000;
    localparam CLK_TICKS_350US  = 32'd35;

    sstv #(
        .simulate(1)
    ) SSTV (
        .clk(clk),
        .reset(reset),
        .freq(freq),
        .vid_addr(vid_addr),
        .vid_pixel(vid_pixel),
        .vis_code(vis_code),
        .vis_valid(vis_valid)
    );
    
    localparam  FREQ_MAX    = 12'hfff;
    localparam  FREQ_MIN    = 12'h000;
    localparam  FREQ_1900HZ = 12'd1900;
    localparam  FREQ_1300HZ = 12'd1300;
    localparam  FREQ_1200HZ = 12'd1200;
    localparam  FREQ_1100HZ = 12'd1100;
    
    localparam  FREQ_BLACK  = 12'd1500;
    localparam  FREQ_WHITE  = 12'd2300;


    // Run the clock
    always #100 clk = ~clk;

task sstv_reset;
    integer ticks;
    begin
        ticks = 0;

        while (ticks < 10) begin
            @(posedge clk);
            reset = 1'b1;
            ticks = ticks + 1;
        end
        @(posedge clk);
        reset = 1'b0;
    end
endtask

task sstv_delay;
    integer ticks;
    begin
        ticks = 0;

        while (ticks < CLK_TICKS_30MS) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);
    end
endtask

task sstv_udelay;
    integer ticks;
    begin
        ticks = 0;

        while (ticks < CLK_TICKS_350US) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);
    end
endtask


task sstv_vis_sendbit;
	input bit;
	begin
		if (bit)
			freq = FREQ_1100HZ;
		else
			freq = FREQ_1300HZ;
		sstv_delay();
	end
endtask

task sstv_frame;
    integer freq_val;
    integer ticks;
    integer i;
    reg [7:0] vis_code; 
    localparam TESTNAME = "sstv_frame";
    begin

        $display ("[%s] Starting test @ %g", TESTNAME, $time);
        
        // Reset block
        sstv_reset();

        // Sending header
        $display ("[%s] Sending header tone", TESTNAME);
        freq = FREQ_1900HZ;
        ticks = 0;
        while (ticks < CLK_TICKS_300MS) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);
        
        @(posedge clk);
        freq = FREQ_1200HZ;
        ticks = 0;
        while (ticks < CLK_TICKS_10MS) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);

        @(posedge clk);
        freq = FREQ_1900HZ;
        ticks = 0;
        while (ticks < CLK_TICKS_300MS) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);
        
        freq = FREQ_1200HZ;
        sstv_delay();

        vis_code = 8'h88;
        for (i = 0; i < 8; i = i + 1) begin
			sstv_vis_sendbit(vis_code[i]);
        end

        freq = FREQ_1200HZ;
        sstv_delay();
        // Sending VIS

        for (i = 0; i < (160 * 120); i = i + 1) begin
            freq = $random % (FREQ_WHITE - FREQ_BLACK + 1) + FREQ_BLACK;
            sstv_udelay();
        end

    end


endtask



    initial begin
        // Drive all of our inputs to known states
        clk = 0;
        reset = 1;
		freq = 0;
        test_fail = 0;

        $dumpfile("sstv.vcd");
        $dumpvars(0);

        @(posedge clk);
        sstv_frame();

        $dumpflush;
        #100 $finish;

    end

assert_never #(
    `OVL_ERROR,
    `OVL_ASSERT,
    "TEST FAIL!",
) sstv_vis_tb_test_fail (
    .clk(clk),
    .reset_n(~reset),
    .test_expr(test_fail)
);


endmodule
