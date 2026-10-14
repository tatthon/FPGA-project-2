`timescale 1ns / 1ps

module debouncer(
    input  wire clk,
    input  wire reset,
    input  wire PB,          // active-low input

    output reg  PB_state,
    output wire PB_down,
    output wire PB_up
);

    // =========================================================
    // Synchronizer
    // =========================================================

    reg PB_sync_0;
    reg PB_sync_1;

    // =========================================================
    // Debounce counter
    // =========================================================

    reg [15:0] PB_cnt;

    wire PB_idle;
    wire PB_cnt_max;

    assign PB_idle    = (PB_state == PB_sync_1);
    assign PB_cnt_max = &PB_cnt;


    // =========================================================
    // Synchronize button input
    //
    // PB is active-low:
    // PB = 1 -> not pressed
    // PB = 0 -> pressed
    //
    // Convert to active-high internally.
    // =========================================================

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PB_sync_0 <= 1'b0;
            PB_sync_1 <= 1'b0;
        end
        else begin
            PB_sync_0 <= ~PB;
            PB_sync_1 <= PB_sync_0;
        end
    end


    // =========================================================
    // Debounce logic
    // =========================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            PB_cnt   <= 16'd0;
            PB_state <= 1'b0;

        end
        else begin

            if (PB_idle) begin

                // Button state is stable
                PB_cnt <= 16'd0;

            end
            else begin

                // Possible button state change
                PB_cnt <= PB_cnt + 16'd1;

                // Accept new state after counter reaches max
                if (PB_cnt_max)
                    PB_state <= ~PB_state;

            end

        end
    end


    // =========================================================
    // One-clock pulses
    // =========================================================

    // Button has just been pressed
    assign PB_down =
        ~PB_idle &
        PB_cnt_max &
        ~PB_state;

    // Button has just been released
    assign PB_up =
        ~PB_idle &
        PB_cnt_max &
        PB_state;

endmodule