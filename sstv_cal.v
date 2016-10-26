// sstv_cal.v
//
// Author: Jack Bradach
//
// Recognizes a slow-scan television (SSTV) calibration header,
// which consists of a 1900Hz tone for 300ms, a 1200Hz tone
// for 10ms, and another 1900Hz tone for 300ms.  Takes the
// a 12-bit input frequency (in Hz) and will drive out
// cal_active when the detection logic has seen an initial
// leader tone (and is trying to detect) and drives cal_ok
// when a valid calibration sequence has been seen.
module sstv_cal #(
    parameter simulate = 0
)   (
    input   clk,
    input   reset,
    input   frame_active,
    input   [11:0] freq,

    // Indicates when a calibration signal is being
    // received and (when done) if it was valid.
    output  reg cal_active,
    output  reg cal_ok
);

    reg [31:0] cal_counter;
    reg [3:0] cal_state;
    reg [3:0] next_cal_state;

    localparam  CLK_TICKS_10MS  = simulate ? 32'd1_000  : 32'd1_000_000;
    localparam  CLK_TICKS_300MS = simulate ? 32'd30_000 : 32'd30_000_000;

    localparam  FREQ_1900HZ = 12'd1900;
    localparam  FREQ_1200HZ = 12'd1200;

    // State definitions for calibration signal detector
    localparam SSTV_CAL_IDLE        = 4'b0001;
    localparam SSTV_CAL_LEADER_A    = 4'b0010;
    localparam SSTV_CAL_BREAK       = 4'b0100;
    localparam SSTV_CAL_LEADER_B    = 4'b1000;

    // Advance the state machine on the
    // rising edge of the clock.
    always @(posedge clk)
        if (reset)
            cal_state <= SSTV_CAL_IDLE;
        else
            cal_state <= next_cal_state;
     
    // Combinatorial logic to figure out the next state
    always @(*) begin
        next_cal_state = SSTV_CAL_IDLE;
        case(cal_state)
            
            // When we 'hear' 1900HZ, switch to the
            // first leader detection state
            SSTV_CAL_IDLE: begin
                if ((FREQ_1900HZ == freq) &&
                    !frame_active)
                    next_cal_state = SSTV_CAL_LEADER_A;
                else
                    next_cal_state = SSTV_CAL_IDLE;
            end

            // The leader tone needs to be 300ms long.
            // I'm saying that going longer is ok, but
            // shorter isn't.  May need to add some tolerance
            // to the timer, since I'm not sure how spot-on
            // the actual transmission is going to be.
            SSTV_CAL_LEADER_A: begin
                if (FREQ_1900HZ == freq)
                    next_cal_state = SSTV_CAL_LEADER_A;
                else if (FREQ_1200HZ == freq) 
                    // If we didn't get at least 300ms of
                    // leader, abort and go back to idle.
                    if (cal_counter >= CLK_TICKS_300MS) 
                        next_cal_state = SSTV_CAL_BREAK;
                    else
                        next_cal_state = SSTV_CAL_IDLE;
                else
                    next_cal_state = SSTV_CAL_IDLE;     
            end

            // Break is 10ms long. 
            SSTV_CAL_BREAK: begin
                if (FREQ_1200HZ == freq)
                    next_cal_state = SSTV_CAL_BREAK;
                else if (FREQ_1900HZ == freq)
                    // If we didn't get at least 10ms of
                    // break, abort and go back to idle.
                    if (cal_counter >= CLK_TICKS_10MS) 
                        next_cal_state = SSTV_CAL_LEADER_B;
                    else
                        next_cal_state = SSTV_CAL_IDLE;
                else
                    next_cal_state = SSTV_CAL_IDLE;
            end

            // This one is simpler than A, since the other block
            // is determining whether we waited long enough to
            // count this as a valid calibration header. 
            SSTV_CAL_LEADER_B: begin
                if (FREQ_1900HZ == freq)
                    next_cal_state = SSTV_CAL_LEADER_B;
                else
                    next_cal_state = SSTV_CAL_IDLE;
            end

            // Whoa, how'd we get here?
            default:
                next_cal_state = SSTV_CAL_IDLE;
        endcase
    end

    // Sequential logic to drive the calibration
    // detection logic signals.
    always @(posedge clk)
        if (reset) begin
            cal_active   <= 0; 
            cal_ok       <= 0; 
        end
        else
            case (cal_state)

                // Waiting for something to happen
                SSTV_CAL_IDLE: begin
                    cal_active  <= 0;  
                    cal_counter <= 32'd1;
                end

                // We've received a 1900Hz tone, begin counting
                SSTV_CAL_LEADER_A: begin
                    cal_active  <= 1;  
                    cal_ok      <= 0;
                    
                    // Count up each cycle we're on this frequency.
                    // Reset when we change.
                    if (FREQ_1900HZ == freq)
                        cal_counter <= cal_counter + 32'd1;
                    else
                        cal_counter <= 32'd1;
                end

                // Wait for 1200 Hz done to end
                SSTV_CAL_BREAK: begin
                    // Same kind of counting as before, but for
                    // the break frequency this time.
                    if (FREQ_1200HZ == freq)
                        cal_counter <= cal_counter + 32'd1;
                    else
                        cal_counter <= 32'd1;
                end

                // Set Calibration OK when the frequency changes
                // from 1900 Hz.  This should be the end of the
                // calibration cycle.
                SSTV_CAL_LEADER_B: begin
                    // Don't need to reset the counter this
                    // time since the idle state does it.
                    if (FREQ_1900HZ == freq)
                        cal_counter <= cal_counter + 32'd1;
                    else begin
                        if (cal_counter >= CLK_TICKS_300MS)
                            cal_ok <= 1;
                        else
                            cal_ok <= 0;
                    end
                end

            endcase

    

endmodule
