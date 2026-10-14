`timescale 1ns / 1ps

module text_screen_gen(
    input  wire        clk,
    input  wire        reset,
    input  wire        video_off,

    // ACTIVE-HIGH gamepad
    // [11] B
    // [10] Y
    // [9]  Select
    // [8]  Start
    // [7]  Up
    // [6]  Down
    // [5]  Left
    // [4]  Right
    // [3]  A
    // [2]  X
    // [1]  L
    // [0]  R
    input  wire [11:0] gamepad_in,

    input  wire [9:0] x,
    input  wire [9:0] y,

    output reg  [5:0] rgb
);


    // =========================================================
    // GAME STATE
    // =========================================================

    // 0 = APPLE
    // 1 = HOUSE
    // 2 = TIGER
    reg [1:0] word_id;

    // 0 = A, 1 = B, ..., 25 = Z
    reg [4:0] selected_letter;

    // 3 -> 2 -> 1 -> 0
    reg [2:0] lives;

    // guessed[0]  = A
    // guessed[1]  = B
    // ...
    // guessed[25] = Z
    reg [25:0] guessed;

    reg game_over;
    reg game_win;

    // 1 = player tried to guess a character
    //     that had already been guessed
    reg already_guessed;


    // =========================================================
    // RANDOM COUNTER
    // =========================================================

    reg [15:0] random_counter;

    always @(posedge clk or posedge reset) begin
        if (reset)
            random_counter <= 16'd0;
        else
            random_counter <= random_counter + 1'b1;
    end


    // =========================================================
    // BUTTON TICKS
    // =========================================================

    wire up_tick;
    wire down_tick;
    wire y_tick;
    wire start_tick;


    // =========================================================
    // UP
    // =========================================================

    debouncer db_up(
        .clk(clk),
        .reset(reset),
        .PB(~gamepad_in[7]),
        .PB_state(),
        .PB_down(up_tick),
        .PB_up()
    );


    // =========================================================
    // DOWN
    // =========================================================

    debouncer db_down(
        .clk(clk),
        .reset(reset),
        .PB(~gamepad_in[6]),
        .PB_state(),
        .PB_down(down_tick),
        .PB_up()
    );


    // =========================================================
    // Y = GUESS
    // =========================================================

    debouncer db_y(
        .clk(clk),
        .reset(reset),
        .PB(~gamepad_in[10]),
        .PB_state(),
        .PB_down(y_tick),
        .PB_up()
    );


    // =========================================================
    // START
    // =========================================================

    debouncer db_start(
        .clk(clk),
        .reset(reset),
        .PB(~gamepad_in[8]),
        .PB_state(),
        .PB_down(start_tick),
        .PB_up()
    );


    // =========================================================
    // WORD ROM
    //
    // ทุกคำยาว 5 ตัว
    // =========================================================

    function [6:0] get_word_char;

        input [1:0] word;
        input [2:0] pos;

        begin

            get_word_char = 7'h20;

            case (word)

                // -------------------------------------------------
                // APPLE
                // -------------------------------------------------

                2'd0: begin
                    case (pos)
                        3'd0: get_word_char = "A";
                        3'd1: get_word_char = "P";
                        3'd2: get_word_char = "P";
                        3'd3: get_word_char = "L";
                        3'd4: get_word_char = "E";

                        default:
                            get_word_char = 7'h20;
                    endcase
                end


                // -------------------------------------------------
                // HOUSE
                // -------------------------------------------------

                2'd1: begin
                    case (pos)
                        3'd0: get_word_char = "H";
                        3'd1: get_word_char = "O";
                        3'd2: get_word_char = "U";
                        3'd3: get_word_char = "S";
                        3'd4: get_word_char = "E";

                        default:
                            get_word_char = 7'h20;
                    endcase
                end


                // -------------------------------------------------
                // TIGER
                // -------------------------------------------------

                2'd2: begin
                    case (pos)
                        3'd0: get_word_char = "T";
                        3'd1: get_word_char = "I";
                        3'd2: get_word_char = "G";
                        3'd3: get_word_char = "E";
                        3'd4: get_word_char = "R";

                        default:
                            get_word_char = 7'h20;
                    endcase
                end


                default:
                    get_word_char = 7'h20;

            endcase

        end

    endfunction


    // =========================================================
    // CHECK WHETHER LETTER EXISTS IN WORD
    // =========================================================

    function letter_exists;

        input [1:0] word;
        input [4:0] letter;

        integer i;
        reg [6:0] target;

        begin

            target = 7'h41 + letter;

            letter_exists = 1'b0;

            for (i = 0; i < 5; i = i + 1) begin

                if (get_word_char(word, i) == target)
                    letter_exists = 1'b1;

            end

        end

    endfunction


    // =========================================================
    // CHECK WIN
    // =========================================================

    function all_letters_guessed;

        input [1:0] word;
        input [25:0] guessed_bits;

        integer i;
        reg [6:0] c;

        begin

            all_letters_guessed = 1'b1;

            for (i = 0; i < 5; i = i + 1) begin

                c = get_word_char(word, i);

                if (!guessed_bits[c - 7'h41])
                    all_letters_guessed = 1'b0;

            end

        end

    endfunction


    // =========================================================
    // GAME LOGIC
    // =========================================================

    reg [25:0] guessed_after;


    always @(posedge clk or posedge reset) begin

        if (reset) begin

            word_id         <= 2'd0;
            selected_letter <= 5'd0;
            lives           <= 3;
            guessed         <= 26'd0;

            game_over       <= 1'b0;
            game_win        <= 1'b0;
            already_guessed <= 1'b0;

        end

        else begin

            // =================================================
            // START = NEW GAME
            // =================================================

            if (start_tick) begin

                case (random_counter[1:0])

                    2'd0:
                        word_id <= 2'd0;

                    2'd1:
                        word_id <= 2'd1;

                    2'd2:
                        word_id <= 2'd2;

                    default:
                        word_id <= 2'd0;

                endcase


                selected_letter <= 5'd0;
                lives           <= 3;
                guessed         <= 26'd0;

                game_over       <= 1'b0;
                game_win        <= 1'b0;
                already_guessed <= 1'b0;

            end


            // =================================================
            // GAME ACTIVE
            // =================================================

            else if (!game_over && !game_win) begin


                // =================================================
                // UP = NEXT CHARACTER
                //
                // คง behavior เดิม:
                // ถ้าอยู่ Z แล้วกด UP จะยังเป็น Z
                // =================================================

                if (up_tick) begin

                    already_guessed <= 1'b0;

                    if (selected_letter == 5'd25)
                        selected_letter <= 5'd0;
                    else
                        selected_letter <= selected_letter + 1'b1;

                end


                // =================================================
                // DOWN = PREVIOUS CHARACTER
                //
                // คง behavior เดิม:
                // ถ้าอยู่ A แล้วกด DOWN จะยังเป็น A
                // =================================================

                else if (down_tick) begin

                    already_guessed <= 1'b0;

                    if (selected_letter == 5'd0)
                        selected_letter <= 5'd25;
                    else
                        selected_letter <= selected_letter - 1'b1;

                end


                // =================================================
                // Y = GUESS
                // =================================================

                if (y_tick) begin


                    // =============================================
                    // THIS CHARACTER WAS ALREADY GUESSED
                    // =============================================

                    if (guessed[selected_letter]) begin

                        already_guessed <= 1'b1;

                    end


                    // =============================================
                    // NEW CHARACTER
                    // =============================================

                    else begin

                        already_guessed <= 1'b0;


                        // Create next guessed state
                        guessed_after = guessed;

                        guessed_after[selected_letter] = 1'b1;


                        // Remember this character
                        guessed[selected_letter] <= 1'b1;


                        // =========================================
                        // WRONG GUESS
                        // =========================================

                        if (!letter_exists(
                            word_id,
                            selected_letter
                        )) begin


                            if (lives > 1) begin

                                lives <= lives - 1'b1;

                            end

                            else begin

                                lives     <= 0;
                                game_over <= 1'b1;

                            end

                        end


                        // =========================================
                        // CORRECT GUESS
                        // =========================================

                        else begin

                            if (all_letters_guessed(
                                word_id,
                                guessed_after
                            )) begin

                                game_win <= 1'b1;

                            end

                        end

                    end

                end

            end

        end

    end


    // =========================================================
    // VGA CHARACTER POSITION
    //
    // Each character = 8 x 16 pixels
    // =========================================================

    wire [6:0] screen_x;
    wire [4:0] screen_y;

    assign screen_x = x[9:3];
    assign screen_y = y[8:4];


    // =========================================================
    // CHARACTER TO DISPLAY
    // =========================================================

    reg [6:0] display_char;

    reg [2:0] word_pos;
    reg [6:0] real_char;


    // =========================================================
    // BUILD SCREEN
    // =========================================================

    always @(*) begin

        // default = space
        display_char = 7'h20;

        word_pos = 0;
        real_char = 7'h20;


        // =====================================================
        // HANGMAN
        // =====================================================

        if (screen_y == 3) begin

            case (screen_x)

                36: display_char = "H";
                37: display_char = "A";
                38: display_char = "N";
                39: display_char = "G";
                40: display_char = "M";
                41: display_char = "A";
                42: display_char = "N";

                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // HEART x 3
        // =====================================================

        else if (screen_y == 7) begin

            case (screen_x)

                34: display_char = "H";
                35: display_char = "E";
                36: display_char = "A";
                37: display_char = "R";
                38: display_char = "T";

                40: display_char = "x";

                42: begin

                    case (lives)

                        3:
                            display_char = "3";

                        2:
                            display_char = "2";

                        1:
                            display_char = "1";

                        default:
                            display_char = "0";

                    endcase

                end

                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // WORD
        //
        //        _ _ _ _ _
        // =====================================================

        else if (screen_y == 12) begin

            case (screen_x)


                // -------------------------------------------------
                // CHARACTER 0
                // -------------------------------------------------

                34: begin

                    word_pos = 0;

                    real_char =
                        get_word_char(word_id, word_pos);

                    if (guessed[real_char - 7'h41])
                        display_char = real_char;
                    else
                        display_char = "_";

                end


                // -------------------------------------------------
                // CHARACTER 1
                // -------------------------------------------------

                36: begin

                    word_pos = 1;

                    real_char =
                        get_word_char(word_id, word_pos);

                    if (guessed[real_char - 7'h41])
                        display_char = real_char;
                    else
                        display_char = "_";

                end


                // -------------------------------------------------
                // CHARACTER 2
                // -------------------------------------------------

                38: begin

                    word_pos = 2;

                    real_char =
                        get_word_char(word_id, word_pos);

                    if (guessed[real_char - 7'h41])
                        display_char = real_char;
                    else
                        display_char = "_";

                end


                // -------------------------------------------------
                // CHARACTER 3
                // -------------------------------------------------

                40: begin

                    word_pos = 3;

                    real_char =
                        get_word_char(word_id, word_pos);

                    if (guessed[real_char - 7'h41])
                        display_char = real_char;
                    else
                        display_char = "_";

                end


                // -------------------------------------------------
                // CHARACTER 4
                // -------------------------------------------------

                42: begin

                    word_pos = 4;

                    real_char =
                        get_word_char(word_id, word_pos);

                    if (guessed[real_char - 7'h41])
                        display_char = real_char;
                    else
                        display_char = "_";

                end


                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // SELECTED CHARACTER
        //
        //             [ A ]
        // =====================================================

        else if (screen_y == 17) begin

            case (screen_x)

                37:
                    display_char = "[";

                39:
                    display_char = 7'h41 + selected_letter;

                41:
                    display_char = "]";

                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // UP/DOWN = CHARACTER
        // =====================================================

        else if (screen_y == 21) begin

            case (screen_x)

                30: display_char = "U";
                31: display_char = "P";

                32: display_char = "/";

                33: display_char = "D";
                34: display_char = "O";
                35: display_char = "W";
                36: display_char = "N";

                38: display_char = "=";

                40: display_char = "C";
                41: display_char = "H";
                42: display_char = "A";
                43: display_char = "R";
                44: display_char = "A";
                45: display_char = "C";
                46: display_char = "T";
                47: display_char = "E";
                48: display_char = "R";

                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // Y = GUESS
        // =====================================================

        else if (screen_y == 23) begin

            case (screen_x)

                34: display_char = "Y";

                36: display_char = "=";

                38: display_char = "G";
                39: display_char = "U";
                40: display_char = "E";
                41: display_char = "S";
                42: display_char = "S";

                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // YOU ALREADY GUESSED THIS CHAR
        // =====================================================

        else if (
            screen_y == 25 &&
            already_guessed &&
            !game_over &&
            !game_win
        ) begin

            case (screen_x)

                // YOU
                26: display_char = "Y";
                27: display_char = "O";
                28: display_char = "U";

                // ALREADY
                30: display_char = "A";
                31: display_char = "L";
                32: display_char = "R";
                33: display_char = "E";
                34: display_char = "A";
                35: display_char = "D";
                36: display_char = "Y";

                // GUESSED
                38: display_char = "G";
                39: display_char = "U";
                40: display_char = "E";
                41: display_char = "S";
                42: display_char = "S";
                43: display_char = "E";
                44: display_char = "D";

                // THIS
                46: display_char = "T";
                47: display_char = "H";
                48: display_char = "I";
                49: display_char = "S";

                // CHAR
                51: display_char = "C";
                52: display_char = "H";
                53: display_char = "A";
                54: display_char = "R";

                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // GAME OVER
        // =====================================================

        else if (screen_y == 26 && game_over) begin

            case (screen_x)

                35: display_char = "G";
                36: display_char = "A";
                37: display_char = "M";
                38: display_char = "E";

                40: display_char = "O";
                41: display_char = "V";
                42: display_char = "E";
                43: display_char = "R";

                default:
                    display_char = " ";

            endcase

        end


        // =====================================================
        // YOU WIN
        // =====================================================

        else if (screen_y == 26 && game_win) begin

            case (screen_x)

                36: display_char = "Y";
                37: display_char = "O";
                38: display_char = "U";

                40: display_char = "W";
                41: display_char = "I";
                42: display_char = "N";

                default:
                    display_char = " ";

            endcase

        end

    end


    // =========================================================
    // ASCII FONT ROM
    // =========================================================

    wire [10:0] rom_addr;
    wire [3:0]  row_addr;

    wire [7:0] font_word;

    wire [2:0] bit_addr;
    wire       ascii_bit;


    assign row_addr = y[3:0];

    assign rom_addr = {
        display_char,
        row_addr
    };


    ascii_rom a_rom(
        .clk(clk),
        .addr(rom_addr),
        .data(font_word)
    );


    // =========================================================
    // VGA DELAY
    // =========================================================

    reg [9:0] pix_x1_reg;
    reg [9:0] pix_x2_reg;


    always @(posedge clk or posedge reset) begin

        if (reset) begin

            pix_x1_reg <= 0;
            pix_x2_reg <= 0;

        end

        else begin

            pix_x1_reg <= x;
            pix_x2_reg <= pix_x1_reg;

        end

    end


    // =========================================================
    // SELECT PIXEL INSIDE FONT
    // =========================================================

    assign bit_addr = pix_x2_reg[2:0];

    assign ascii_bit =
        font_word[~bit_addr];


    // =========================================================
    // COLOR
    // =========================================================

    wire [5:0] text_rgb;

    assign text_rgb =
        ascii_bit
            ? 6'b001100
            : 6'b000000;


    // =========================================================
    // FINAL VGA OUTPUT
    // =========================================================

    always @(*) begin

        if (video_off)
            rgb = 6'b000000;
        else
            rgb = text_rgb;

    end


endmodule
