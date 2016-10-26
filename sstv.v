// sstv.v - Top level block for SSTV Decoder logic
//
// Author: Jack Bradach
//
// This module contains the sub-modules for decoding
// SSTV state as well as the logic for extracting a
// frame.  It only decodes Robot-8 encoding (or as
// close to it as I could come up with from the
// various sources on the internet).  Input is
// the currently detected frequency.  From this,
// it'll output an address and data for a 160x120x2
// image ROM, which can be displayed through methods
// outside the scope of this module.  Could be VGA,
// could be black magic.  I'm not going to judge.
module sstv #(
    parameter simulate = 0
)   (
    input clk,
    input reset,

    input [11:0] freq,

    // Output data video ram
    output  reg vid_write,
    output  reg [14:0]  vid_addr,
    output  reg [1:0]   vid_pixel,
    
    // Outputs from VIS decoder
    output  [6:0]   vis_code,
    output  vis_valid
);

    // Outputs from calibration module
    wire cal_active;
    wire cal_ok;

    // State of the FSM
    reg [8:0]   sstv_state;
    reg [8:0]   next_sstv_state;

    // Timer counter
    reg [31:0]  delay_counter;

    // Row and column registers
    reg [6:0]   sstv_row;
    reg [7:0]   sstv_col;

    // Output from color decoder.
    wire [1:0]  pixel_data;

    // Frame decode active
    reg frame_active;

    // Time constants.
    localparam  CLK_TICKS_30MS  =   simulate ? 32'd3_000 : 32'd3_000_000;
    localparam  CLK_TICKS_5MS   =   simulate ? 32'd500   : 32'd500_000;
    localparam  CLK_TICKS_350US =   simulate ? 32'd35    : 32'd35_000;

    // Maximum resolution for the received frame
    // (hard-coded to 160x120)
    localparam  HORIZ_MAX = 8'd160;
    localparam  VERT_MAX  = 7'd120;

    // Important frequencies for decoding
    // the image being received.
    localparam  FREQ_HSYNC  = 12'd1200;
    localparam  FREQ_BLACK  = 12'd1500;
    localparam  FREQ_WHITE  = 12'd2300;

    // FSM states
    localparam  SSTV_IDLE   = 'b00000001;
    localparam  SSTV_CAL    = 'b00000010;
    localparam  SSTV_VIS    = 'b00000100;
    localparam  SSTV_FRAME  = 'b00001000;

    // Advance the state machine
    always @(posedge clk)
        if (reset)
            sstv_state <= SSTV_IDLE;
        else
            sstv_state <= next_sstv_state;
    
    // Combinatorial logic to figure out what
    // the next state of the FSM ought to be.
    always @(*)
        if(reset)
            next_sstv_state = SSTV_IDLE;
        else
            case (sstv_state)
                SSTV_IDLE: begin
                    if (cal_active)
                        next_sstv_state = SSTV_CAL;
                    else
                        next_sstv_state = SSTV_IDLE;
                end 
            
                SSTV_CAL: begin
                    if (!cal_active && cal_ok)
                        next_sstv_state = SSTV_VIS;
                    else if (cal_active)
                        next_sstv_state = SSTV_CAL;
                    else
                        next_sstv_state = SSTV_IDLE;
                end 

                SSTV_VIS: begin
                    if (vis_valid)
                        next_sstv_state = SSTV_FRAME;
                    else if (!cal_ok && !vis_valid)
                        next_sstv_state = SSTV_IDLE;
                    else
                        next_sstv_state = SSTV_VIS;
                end 

                SSTV_FRAME: begin
                    if (!cal_active && !cal_ok)
                        next_sstv_state = SSTV_IDLE;
                    else
                    if (sstv_row == VERT_MAX)
                        next_sstv_state = SSTV_IDLE;
                    else
                        next_sstv_state = SSTV_FRAME;
                end

                default:
                        next_sstv_state = SSTV_IDLE;


            endcase

    // Sequential logic for the FSM.
    always @(posedge clk)
        if(reset) begin
            sstv_row   <= 0;
            sstv_col   <= 0;
            vid_write  <= 0;
            vid_addr   <= 0;
            vid_pixel  <= 0;
            frame_active <= 0;
        end
        else
            case (sstv_state)
                // No data being received.
                SSTV_IDLE: begin
                    sstv_row    <= 0;
                    sstv_col    <= 0;
                    vid_write   <= 0;
                    vid_addr    <= 0;
                    frame_active <= 1'b0;
                    delay_counter <= 1;
                end 
            
                SSTV_CAL: begin
                    // Nothing to do (handled
                    // by the submodule)
                end 

                SSTV_VIS: begin
                    // Nothing to do (handled
                    // by the submodule)
                end 
                
                // Decode the image frame being received!
                SSTV_FRAME: begin
                    vid_addr <= (sstv_row * 8'd160) + sstv_col;
                    frame_active <= 1'b1;
                    // When we get an HYSNC, reset the column.
                    if (FREQ_HSYNC == freq) begin
                        sstv_col    <= 0;
                        delay_counter <= 1;
                    end
                    else
                    
                    // If there's valid data, start saving pixels.
                    if ((freq >= FREQ_BLACK) &&
                        (freq <= FREQ_WHITE)) begin
                            // Sample in the middle of the pixel time
                            if (delay_counter == (CLK_TICKS_350US / 2)) begin
                                delay_counter <= delay_counter + 1;
                                vid_pixel <= pixel_data;
                                vid_write <= 1;
                            end
                            else
                            if (delay_counter < CLK_TICKS_350US) begin
                                delay_counter <= delay_counter + 1'b1;
                                vid_write <= 0;
                            end
                            else begin
                                delay_counter <= 1;
                                vid_write <= 0;
                                if (sstv_col == 8'd159) begin
                                    sstv_col <= 0;
                                    sstv_row <= sstv_row + 1'b1;
                                end
                                else
                                    sstv_col <= sstv_col + 1'b1;
                            end
                        end
                end 
            endcase



    // Calibration signal detector
    sstv_cal #(
        .simulate(simulate)  
    ) CAL (
        .clk(clk),
        .reset(reset),
        .freq(freq),
        .frame_active(frame_active),
        .cal_active(cal_active),
        .cal_ok(cal_ok)
    );

    // Vertical Interval Signaling decoder
    sstv_vis #(
        .simulate(simulate)  
    ) VIS (
        .clk(clk),
        .reset(reset),
        .freq(freq),
        .cal_ok(cal_ok),
        .vis_code(vis_code),
        .valid(vis_valid)
    );

    // Returns the appropriate color pixel
    // for the frequency being received.
    sstv_pixel PIX (
        .reset(reset),
        .freq(freq),
        .color(pixel_data)
    );

    assert_never_unknown #(
        `OVL_ERROR,
        1,
        `OVL_ASSERT,
        "Unknown output vid_write!"
    ) sstv_no_unknown_vid_write (
        .clk(clk),
        .reset_n(~reset),
        .qualifier(clk),
        .test_expr(vid_write)
    );

    assert_never_unknown #(
        `OVL_ERROR,
        15,
        `OVL_ASSERT,
        "Unknown output vid_addr!"
    ) sstv_no_unknown_vid_addr (
        .clk(clk),
        .reset_n(~reset),
        .qualifier(clk),
        .test_expr(vid_addr)
    );

    assert_never_unknown #(
        `OVL_ERROR,
        2,
        `OVL_ASSERT,
        "Unknown output vid_pixel!"
    ) sstv_no_unknown_vid_pixel (
        .clk(clk),
        .reset_n(~reset),
        .qualifier(clk),
        .test_expr(vid_pixel)
    );

    assert_increment #(
        `OVL_ERROR,
        15,
        1,
        `OVL_ASSERT,
        "Output address incremented by more than 1!"
    ) sstv_increment_address (
        .clk(clk),
        .reset_n(~reset),
        .test_expr(vid_addr)
    );


    

endmodule
