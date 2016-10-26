`define OVL_ASSERT_ON 1
`define OVL_INIT_MSG 1
`include "assert_never.vlib"
`include "assert_always.vlib"
module sstv_cal_tb;
    reg clk;
    reg reset;
    reg [11:0] freq;
    wire cal_active;
    wire cal_ok;

	reg test_fail;
    wire [6:0] vis_code;
    wire valid;

    localparam CLK_TICKS_10MS   = 32'd1_000;
    localparam CLK_TICKS_30MS   = 32'd3_000;
    localparam CLK_TICKS_300MS  = 32'd30_000;

    sstv_cal #(
        .simulate(1)
    ) SSTV_CAL (
        .clk(clk),
        .reset(reset),
        .freq(freq),
        .cal_active(cal_active),
        .cal_ok(cal_ok)
    );
    
    localparam  FREQ_MAX    = 12'hfff;
    localparam  FREQ_MIN    = 12'h000;
    localparam  FREQ_1900HZ = 12'd1900;
    localparam  FREQ_1300HZ = 12'd1300;
    localparam  FREQ_1200HZ = 12'd1200;
    localparam  FREQ_1100HZ = 12'd1100;

    // Run the clock
    always #100 clk = ~clk;

task sstv_cal_reset;
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

task sstv_cal_leader_detect;
    integer freq_val;
    localparam TESTNAME = "sstv_cal_leader_detect";
    begin
    $display ("[%s] Starting test @ %g", TESTNAME, $time);
    
    // Reset block
    sstv_cal_reset();

    // Sweep the frequency range and make sure that we only get a cal_active
    // when the leader tone of 1900Hz is detected.
    $display ("[%s] Sweeping frequency range", TESTNAME);
    for (freq_val = FREQ_MIN; freq_val <= FREQ_MAX; freq_val = freq_val + 1) begin
        freq = freq_val;
        @(posedge clk);
    end

    $display ("[%s] Finished @ %g", TESTNAME, $time);
    end

endtask

task sstv_cal_receive;
    integer freq_val;
    integer ticks;
    localparam TESTNAME = "sstv_cal_receive";
    begin
        $display ("[%s] Starting test @ %g", TESTNAME, $time);
        
        // Reset block
        sstv_cal_reset();

        if (cal_active || cal_ok) begin
            $display ("[%s] Block active after reset, cal_active: %d cal_ok: %d", TESTNAME, cal_active, cal_ok);
            test_fail = 1'b1;
        end

        $display ("[%s] Sending header tone", TESTNAME);
        freq = FREQ_1900HZ;
        ticks = 0;
        while (ticks < CLK_TICKS_300MS) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);

        if (!cal_active) begin
            $display ("[%s] Signal cal_active not being driven in response to leader tone", TESTNAME);
            test_fail = 1'b1;
        end

        @(posedge clk);
        freq = FREQ_1200HZ;
        ticks = 0;
        while (ticks < CLK_TICKS_10MS) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);
        
        if (!cal_active) begin
            $display ("[%s] Signal cal_active not being driven in response to leader tone", TESTNAME);
            test_fail = 1'b1;
        end

        @(posedge clk);
        freq = FREQ_1900HZ;
        ticks = 0;
        while (ticks < CLK_TICKS_300MS) begin
            @(posedge clk);
            ticks = ticks + 1;
        end
        @(posedge clk);
        
        freq = FREQ_MIN;
        @(posedge clk);

        if (cal_active && !cal_ok ) begin
            $display ("[%s] Signals incorrect after end of leader, cal_active: %d cal_ok: %d", TESTNAME, cal_active, cal_ok);
            test_fail = 1'b1;
        end

        #100;
    $display ("[%s] Finished @ %g", TESTNAME, $time);
    end

endtask


    initial begin
        // Drive all of our inputs to known states
        clk = 0;
        reset = 1;
		freq = 0;
        test_fail = 0;

        $dumpfile("sstv_cal.vcd");
        $dumpvars(0);

        @(posedge clk);
        sstv_cal_leader_detect();
        sstv_cal_receive();

        $dumpflush;
        #100 $finish;

    end

assert_never #(
    `OVL_ERROR,
    `OVL_ASSERT,
    "TEST FAIL!",
) sstv_cal_tb_mising_cal (
    .clk(clk),
    .reset_n(~reset),
    .test_expr(cal_active && (freq !=FREQ_1900HZ) && clk)
);

/*
assert_never #(
    `OVL_ERROR,
    `OVL_ASSERT,
    "TEST FAIL!",
) sstv_cal_tb_test_fail (
    .clk(clk),
    .reset_n(~reset),
    .test_expr(test_fail)
);

*/
endmodule
