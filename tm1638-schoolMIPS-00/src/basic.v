module basic(

    input              clkIn,
    input    [ 31:0 ]  regData_in,
    output  reg        tm_cs,        // Chip Select для TM1638
    output  wire       tm_clk,       // Тактовый сигнал для TM1638
    output  [  5:0 ]   LEDR,
    inout   wire       tm_dio        // Данные для TM1638
);


       //outputs
    assign LEDR[0]   = clkIn;
    assign LEDR[5:1] = regData_in[4:0];

    // Параметры состояния
    localparam HIGH = 1'b1;
    localparam LOW = 1'b0;
    localparam CLK_DIV = 19;  // Скорость сканирования (делитель тактовой частоты)

    // Команды TM1638
    localparam [7:0]
        C_READ  = 8'b01000010,  // Чтение клавиш
        C_WRITE = 8'b01000000,  // Запись данных
        C_ADDR  = 8'b11000000,  // Установка адреса
        C_DISP  = 8'b10001111;  // Включение дисплея (макс. яркость)

    // Регистры управления
    reg [5:0] instruction_step;
    reg [7:0] keys;
    reg [23:0] counter; // 25
   
    // Регистры для анимации "бегущего огня"
    reg [7:0] larson;  // Регистр для хранения состояния светодиодов
    reg larson_dir;    // Направление движения "бегущего огня"
    reg [CLK_DIV:0] blink_counter;  // Счетчик для управления скоростью анимации
 
    reg rst = HIGH;  // Регистр сброса

    // Интерфейс TM1638
    reg tm_rw;
    wire dio_in;
    wire dio_out;
    assign tm_dio = tm_rw ? dio_out : 1'bz;
    assign dio_in = tm_dio;
    
    reg tm_latch;
    wire busy;
    wire [7:0] tm_data, tm_in;
    reg [7:0] tm_out;
    
    assign tm_in = tm_data;  // Чтение данных с модуля
    assign tm_data = tm_rw ? tm_out : 8'hZZ;

    // Подключение модуля TM1638
    tm1638 u_tm1638 (
        .clk(clkIn),
        .rst(rst),
        .data_latch(tm_latch),
        .data(tm_data),
        .rw(tm_rw),
        .busy(busy),
        .sclk(tm_clk),
        .dio_in(dio_in),
        .dio_out(dio_out)
    );


    // ПЗУ для 7-сегментных кодов (0-9 и A-F для шестнадцатеричного отображения)
    reg [6:0] seg_rom [0:15];
    
    // Инициализация ПЗУ сегментов
    initial begin
        seg_rom[0] = 7'b0111111;  // 0 // g f e d c b a
        seg_rom[1] = 7'b0000110;  // 1
        seg_rom[2] = 7'b1011011;  // 2 //   --a--
        seg_rom[3] = 7'b1001111;  // 3 //  |     |
        seg_rom[4] = 7'b1100110;  // 4 //  f     b
        seg_rom[5] = 7'b1101101;  // 5 //  |     |
        seg_rom[6] = 7'b1111101;  // 6 //   --g--
        seg_rom[7] = 7'b0000111;  // 7 //  |     |
        seg_rom[8] = 7'b1111111;  // 8 //  e     c
        seg_rom[9] = 7'b1101111;  // 9 //  |     |
        seg_rom[10] = 7'b1110111; // A //   --d-- 
        seg_rom[11] = 7'b1111100; // b
        seg_rom[12] = 7'b0111001; // C
        seg_rom[13] = 7'b1011110; // d
        seg_rom[14] = 7'b1111001; // E
        seg_rom[15] = 7'b1110001; // F

    end


    // Задача для отображения цифры
    task display_digit;
        input [3:0] digit;
        begin
            tm_latch <= HIGH;
            tm_out <= {1'b0, seg_rom[digit]};
        end
    endtask

    // Задача для анимации светодиодов
    task display_led;
        input [2:0] dot;  // Номер светодиода

        begin
            tm_latch <= HIGH;  // Активировать защелку
            tm_out <= {7'b0, larson[dot]};  // Установить состояние светодиода
        end
    endtask

    // Основной автомат управления
    always @(posedge clkIn) begin

        // Сброс всех регистров
        if (rst) begin
            instruction_step <= 6'b0;
            tm_cs <= HIGH;
            tm_rw <= HIGH;
            rst <= LOW;
            counter <= 0;
            keys <= 8'b0;

            blink_counter <= 0;
            larson_dir <= 0;
            larson <= 8'b00010000;  // Инициализировать состояние светодиодов

       //     second_counter <= 0; // Инициализация счетчика секунд

        end
        else begin


            // Счетчик для замедления тактовой частоты
               counter <= counter + 1;

               blink_counter <= blink_counter + 1;


            if (counter[0] && ~busy) begin
                case (instruction_step)
                    // Чтение клавиш
                       // *** ЧТЕНИЕ КЛАВИШ ***
                    1:  {tm_cs, tm_rw}     <= {LOW, HIGH};  // Активировать выбор чипа и режим записи
                    2:  {tm_latch, tm_out} <= {HIGH, C_READ};  // Установить режим чтения
                    3:  {tm_latch, tm_rw}  <= {HIGH, LOW};  // Переключиться на режим чтения

                    
                    // Чтение состояния клавиш S1 - S8
                    4:  {keys[7], keys[3]} <= {tm_in[0], tm_in[4]};  // Чтение первой пары клавиш
                    5:  {tm_latch}         <= {HIGH};  // Активировать защелку
                    6:  {keys[6], keys[2]} <= {tm_in[0], tm_in[4]};  // Чтение второй пары клавиш
                    7:  {tm_latch}         <= {HIGH};  // Активировать защелку
                    8:  {keys[5], keys[1]} <= {tm_in[0], tm_in[4]};  // Чтение третьей пары клавиш
                    9:  {tm_latch}         <= {HIGH};  // Активировать защелку
                    10: {keys[4], keys[0]} <= {tm_in[0], tm_in[4]};  // Чтение четвертой пары клавиш
                    11: {tm_cs}            <= {HIGH};  // Деактивировать выбор чипа

                    
                    // *** ОТОБРАЖЕНИЕ НА ДИСПЛЕЕ ***
                    12: {tm_cs, tm_rw}     <= {LOW, HIGH};  // Активировать выбор чипа и режим записи
                    13: {tm_latch, tm_out} <= {HIGH, C_WRITE};  // Установить режим записи
                    14: {tm_cs}            <= {HIGH};  // Деактивировать выбор чипа

                    15: {tm_cs, tm_rw}     <= {LOW, HIGH};  // Активировать выбор чипа и режим записи
                    16: {tm_latch, tm_out} <= {HIGH, C_ADDR};  // Установить начальный адрес


                    // Отображение 32-битного числа (8 шестнадцатеричных цифр)
                    17: display_digit(regData_in[31:28]);  // Старший байт  3'd7,
                    18: display_led(3'd0);

                    19: display_digit(regData_in[27:24]);
                    20: display_led(3'd1);

                    21: display_digit(regData_in[23:20]);
                    22: display_led(3'd2);

                    23: display_digit(regData_in[19:16]);
                    24: display_led(3'd3);

                    25: display_digit(regData_in[15:12]);    
                    26: display_led(3'd4);

                    27: display_digit(regData_in[11:8]);    
                    28: display_led(3'd5);

                    29: display_digit(regData_in[7:4]);  
                    30: display_led(3'd6);

                    31: display_digit(regData_in[3:0]);  // Младший байт
                    32: display_led(3'd7);

                    33: {tm_cs}            <= {HIGH};

                    34: {tm_cs, tm_rw}     <= {LOW, HIGH};  // Активировать выбор чипа и режим записи
                    35: {tm_latch, tm_out} <= {HIGH, C_DISP};  // Включить дисплей с максимальной яркостью
                    36: {tm_cs, instruction_step} <= {HIGH, 6'b0};  // Деактивировать выбор чипа и сбросить шаг выполнения инструкции

                endcase

                instruction_step <= instruction_step + 6'd1;


            end else if (busy) begin
                tm_latch <= LOW;
            end

            if (&blink_counter) begin
                larson_dir <= larson[6] ? 0 : larson[1] ? 1 : larson_dir;

                if (larson_dir)
                    larson <= {larson[6:0], larson[7]};
                else
                    larson <= {larson[0], larson[7:1]};
            end

        end
    end
endmodule