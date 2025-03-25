module top(
    input clk,          // Входной тактовый сигнал (12 МГц)
    output reg tm_cs,   // Chip Select для TM1638
    output tm_clk,      // Тактовый сигнал для TM1638
    inout tm_dio        // Данные для TM1638
);

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

    // ПЗУ для 7-сегментных кодов (0-9)
    reg [6:0] seg_rom [0:9];
    initial begin
        seg_rom[0] = 7'b0111111;  // 0
        seg_rom[1] = 7'b0000110;  // 1
        seg_rom[2] = 7'b1011011;  // 2
        seg_rom[3] = 7'b1001111;  // 3
        seg_rom[4] = 7'b1100110;  // 4
        seg_rom[5] = 7'b1101101;  // 5
        seg_rom[6] = 7'b1111101;  // 6
        seg_rom[7] = 7'b0000111;  // 7
        seg_rom[8] = 7'b1111111;  // 8
        seg_rom[9] = 7'b1101111;  // 9
    end

    // Регистры управления
    reg [5:0] instruction_step;
    reg [7:0] keys;
    reg [23:0] counter;

    reg [9:0] milliseconds;  // 10 бит (0-999)
    reg [5:0] seconds;
    reg [5:0] minutes;
    reg [4:0] hours;
    reg running;
    reg paused;


    // Регистры для управления состоянием
    reg rst = HIGH;  // Регистр сброса


    // Регистры для анимации "бегущего огня"
    reg [7:0] larson;  // Регистр для хранения состояния светодиодов
    reg larson_dir;    // Направление движения "бегущего огня"
    reg [CLK_DIV:0] blink_counter;  // Счетчик для управления скоростью анимации


    // Интерфейс TM1638
    reg tm_rw;
    wire dio_in;
    wire dio_out;
    // Управление тристабильным выводом
    assign tm_dio = tm_rw ? dio_out : 1'bz;  // Если tm_rw = 1, то вывод данных, иначе высокоимпедансное состояние
    assign dio_in = tm_dio;  // Чтение данных с вывода

    // Настройка модуля TM1638 с тристабильным выводом
    //   tm_in      - данные, прочитанные с модуля
    //   tm_out     - данные, записываемые в модуль
    //   tm_latch   - сигнал защелки для чтения/записи данных
    //   tm_rw      - выбор режима (чтение/запись)
    //   busy       - сигнал занятости модуля
    //   tm_clk     - тактовый сигнал данных
    //   dio_in     - данные, прочитанные с дисплея
    //   dio_out    - данные, отправляемые на дисплей
    //   tm_data    - тристабильный вывод данных к модулю
    reg tm_latch;  // Сигнал защелки
    wire busy;     // Сигнал занятости модуля
    wire [7:0] tm_data, tm_in;  // Данные для обмена с модулем
    reg [7:0] tm_out;  // Данные для отправки на модуль

    assign tm_in = tm_data;  // Чтение данных с модуля
    assign tm_data = tm_rw ? tm_out : 8'hZZ;  // Управление тристабильным выводом

    // Подключение модуля TM1638
    tm1638 u_tm1638 (
        .clk(clk),
        .rst(rst),
        .data_latch(tm_latch),
        .data(tm_data),
        .rw(tm_rw),
        .busy(busy),
        .sclk(tm_clk),
        .dio_in(dio_in),
        .dio_out(dio_out)
    );

    // Задачи для управления дисплеем
    task display_digit;
        input [2:0] pos;
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
    always @(posedge clk) begin
        // Сброс всех регистров
        if (rst) begin
            instruction_step <= 6'b0;
            tm_cs <= HIGH;
            tm_rw <= HIGH;
               rst <= LOW;  // Сбросить сигнал сброса
 //           tm_latch <= LOW;
            counter <= 0;
            keys <= 8'b0;
            milliseconds <= 0;
            seconds <= 0;
            minutes <= 0;
            hours <= 0;
            running <= 0;
            paused <= 0;
            blink_counter <= 0;
//            blink_state <= 0;

           larson <= 8'b00010000;  // Инициализировать состояние светодиодов

        end
        else begin


            // Счетчик для замедления тактовой частоты
            counter <= counter + 1;

            // Увеличиваем счетчик анимации
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

                    
                    // Отображение цифр и светодиодов
                    17: display_digit(3'd7, hours / 10);
                    18: display_led(3'd0);

                    19: display_digit(3'd6, hours % 10);
                    20: display_led(3'd1);

                     // Отображение времени в формате MM:SS:mmm
                    21: display_digit(3'd5, minutes / 10);    // Десятки минут
                    22: display_led(3'd2);

                    23: display_digit(3'd4, minutes % 10);    // Единицы минут
                    24: display_led(3'd3);

                    25: display_digit(3'd3, seconds / 10);    // Десятки секунд
                    26: display_led(3'd4);

                    27: display_digit(3'd2, seconds % 10);    // Единицы секунд
                    28: display_led(3'd5);

                    29: display_digit(3'd1, milliseconds / 100);  // Сотни миллисекунд
                    30: display_led(3'd6);

                    31: display_digit(3'd0, (milliseconds % 100) / 10);  // Десятки миллисекунд
                    32: display_led(3'd7);
                    
                    33: {tm_cs}            <= {HIGH};  // Деактивировать выбор чипа

                    34: {tm_cs, tm_rw}     <= {LOW, HIGH};  // Активировать выбор чипа и режим записи
                    35: {tm_latch, tm_out} <= {HIGH, C_DISP};  // Включить дисплей с максимальной яркостью
                    36: {tm_cs, instruction_step} <= {HIGH, 6'b0};  // Деактивировать выбор чипа и сбросить шаг выполнения инструкции

                endcase

                instruction_step <= instruction_step + 6'd1;  // Переход к следующему шагу

            end else if (busy) begin
                tm_latch <= LOW;
            end

            // Логика управления секундомером
            if (keys[0] && !running && !paused) begin
                running <= 1;
            end else if (keys[1] && running) begin
                running <= 0;
                paused <= 1;
            end else if (keys[2]) begin
                running <= 0;
                paused <= 0;
                {hours, minutes, seconds, milliseconds} <= 0;
            end else if (keys[3]) begin
                running <= 0;
                paused <= 0;
                {hours, minutes, seconds, milliseconds} <= 0;
            end


// Счетчик времени (12 МГц)
if (running) begin
    if (counter == 12_000 - 1) begin  // 1 мс при 12 МГц
        counter <= 0;
        if (milliseconds == 999) begin
            milliseconds <= 0;
            if (seconds == 59) begin
                seconds <= 0;
                if (minutes == 59) begin
                    minutes <= 0;
                    hours <= (hours == 23) ? 0 : hours + 1;
                end else begin
                    minutes <= minutes + 1;
                end
            end else begin
                seconds <= seconds + 1;
            end
        end else begin
            milliseconds <= milliseconds + 1;
        end
    end else begin
        counter <= counter + 1;
    end
end
             // Мигание светодиодов
            if (&blink_counter) begin  // Если счетчик достиг максимума
                larson_dir <= larson[6] ? 0 : larson[1] ? 1 : larson_dir;  // Изменить направление анимации

                if (larson_dir)
                    larson <= {larson[6:0], larson[7]};  // Сдвиг вправо
                else
                    larson <= {larson[0], larson[7:1]};  // Сдвиг влево
            end

        end
    end
endmodule