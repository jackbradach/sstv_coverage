`define OVL_ASSERT_ON 1
`define OVL_INIT_MSG 1
`include "assert_never.vlib"
`include "assert_always.vlib"
module sstv_vis_tb;
    reg clk;
    reg reset;
    reg [11:0] freq;
    reg cal_ok;

	reg test_fail;
    wire [6:0] vis_code;
    wire valid;

    localparam CLK_TICKS_30MS   = 32'd3_000;

    sstv_vis #(
        .simulate(1)
    ) SSTV_VIS (
        .clk(clk),
        .reset(reset),
        .freq(freq),
        .cal_ok(cal_ok),
        .vis_code(vis_code),
        .valid(valid)
    );
    
    localparam  FREQ_MAX    = 12'hfff;
    localparam  FREQ_MIN    = 12'h000;
    localparam  FREQ_1900HZ = 12'd1900;
    localparam  FREQ_1300HZ = 12'd1300;
    localparam  FREQ_1200HZ = 12'd1200;
    localparam  FREQ_1100HZ = 12'd1100;

    // Run the clock
    always #100 clk = ~clk;

task sstv_vis_reset;
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

task sstv_vis_calok;
    integer freq_val;
    localparam TESTNAME = "sstv_vis_calok";
    begin
    $display ("[%s] Starting test @ %g", TESTNAME, $time);
    
    // Reset block
    sstv_vis_reset();

    // Sweep the frequency range with cal_ok driven low to ensure
    // we don't "jump" out of it.
    $display ("[%s] Sweeping frequency range", TESTNAME);
    cal_ok = 1'b0;
    for (freq_val = FREQ_MIN; freq_val <= FREQ_MAX; freq_val = freq_val + 1) begin
        @(posedge clk);
    end

    // Drive a sync tone for 30ms, then clock in a couple bits.
    // While it's driving the for the other VIS bits, drop
    // cal_ok to make sure (via the assert) that we go back
    // to SSTV_VIS_IDLE.
    $display ("[%s] Forcing cal_ok while driving valid frequency", TESTNAME);
    freq = FREQ_1200HZ;
    cal_ok = 1'b1;
    sstv_delay();
    freq = FREQ_1100HZ;
    sstv_delay();
    freq = FREQ_1300HZ;
    sstv_delay();
    cal_ok = 1'b0;
    sstv_delay();

    $display ("[%s] Finished @ %g", TESTNAME, $time);
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

task sstv_vis_parity;
    reg [8:0] driven_vis;
    integer i;
    localparam TESTNAME = "sstv_vis_parity";
    begin
    $display ("[%s] Starting test @ %g", TESTNAME, $time);
    
    // Reset block
    sstv_vis_reset();

    // Drive a sync tone for 30ms, then clock in a couple bits.
    // While it's driving the for the other VIS bits, drop
    // cal_ok to make sure (via the assert) that we go back
    // to SSTV_VIS_IDLE.
    $display ("[%s] Forcing cal_ok while driving bits", TESTNAME);
    for (driven_vis = 0; driven_vis <= 9'hFF; driven_vis = driven_vis + 1) begin
        // Kick us into the VIS receiver mode.
        freq = FREQ_1200HZ;
        cal_ok = 1'b1;
        sstv_delay();
        
        for (i = 0; i < 8; i = i + 1) begin
			sstv_vis_sendbit(driven_vis[i]);
        end

		// Final sync pulse to end the frame and get parity to be driven.
		// Wait 30ms * 2 to get the block to accept the last bit and drive
		// out whether or not the parity was valid.  It really only needs
		// an additional clock tick to go to the next state, but this 
		// looks cleaner.
        freq = FREQ_1200HZ;
		sstv_delay();
		sstv_delay();
		$display("[%s] driven_vis: 0x%02x - Valid = %d", TESTNAME, driven_vis[7:0], valid);
		test_fail = ~((^driven_vis[6:0] == driven_vis[7]) == valid);
		cal_ok = 0;
		sstv_delay();

    end
    $display ("[%s] Finished @ %g", TESTNAME, $time);
    end

endtask

task sstv_vis_decode_reset;
    reg [8:0] driven_vis;
    integer i;
    localparam TESTNAME = "sstv_vis_decode_reset";
    begin
    $display ("[%s] Starting test @ %g", TESTNAME, $time);
    
    // Reset block
    sstv_vis_reset();

    // Drive a sync tone for 30ms, then clock in a couple bits.
    // While it's driving the for the other VIS bits, drop
    // cal_ok to make sure (via the assert) that we go back
    // to SSTV_VIS_IDLE.
    $display ("[%s] Forcing cal_ok while driving bits", TESTNAME);
    for (driven_vis = 0; driven_vis <= 9'hFF; driven_vis = driven_vis + 1) begin
        // Kick us into the VIS receiver mode.
        freq = FREQ_1200HZ;
        cal_ok = 1'b1;
        sstv_delay();
       
        for (i = 0; i < 8; i = i + 1) begin
            if (($random % 20) == 0) begin
                sstv_vis_reset();
                $display ("[%s] Resetting VIS decoder at bit %1d", TESTNAME, i);
                i = 9;
            end
            else
			    sstv_vis_sendbit(driven_vis[i]);
        end

        // If a reset didn't occur on this round, verify the result.
        // Otherwise, ensure that valid was not driven
        if (8 == i) begin
            // Final sync pulse to end the frame and get parity to be driven.
            // Wait 30ms * 2 to get the block to accept the last bit and drive
            // out whether or not the parity was valid.  It really only needs
            // an additional clock tick to go to the next state, but this 
            // looks cleaner.
            freq = FREQ_1200HZ;
            sstv_delay();
            sstv_delay();
            $display("[%s] driven_vis: 0x%02x - Valid = %1d", TESTNAME, driven_vis[7:0], valid);
            test_fail = ~((^driven_vis[6:0] == driven_vis[7]) == valid);
            cal_ok = 0;
            sstv_delay();
        end
        else begin
            cal_ok = 0;
            test_fail = valid;
            sstv_delay();
        end

    end
    $display ("[%s] Finished @ %g", TESTNAME, $time);
    end

endtask

    initial begin
        // Drive all of our inputs to known states
        clk = 0;
        reset = 1;
		freq = 0;
        cal_ok = 0;
        test_fail = 0;

        $dumpfile("sstv_vis.vcd");
        $dumpvars(0);

        @(posedge clk);
        sstv_vis_calok();
        sstv_vis_parity();
        sstv_vis_decode_reset();

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
