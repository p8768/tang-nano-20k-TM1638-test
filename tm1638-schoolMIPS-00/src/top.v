module top (
    // Внешние контакты (физические пины)
    input   wire       clk_pin,
    output  wire       tm_cs,        // Chip Select для TM1638
    output  wire       tm_clk,      // Тактовый сигнал для TM1638
    output  [  5:0 ]   LEDR,
    inout   wire       tm_dio        // Данные для TM1638

);

    // Внутренние сигналы (не привязаны к пинам!)
   wire                clk;
   wire                clkIn     =  clk_pin;
   parameter           rst_n     =  1'b1;  // Добавлено: фиксированное значение для сброса
   parameter           clkEnable =  1'b1;  // Добавлено: фиксированное значение для разрешения тактирования
   parameter  [  3:0 ] clkDevide =  4'b0011;
   parameter  [  4:0 ] regAddr   =  5'b00010;
   wire       [ 31:0 ] regData;


//   <имя_модуля> <имя_экземпляра> (
//      .<порт_подключаемого_модуля>(<сигнал_текущего_модуля>),
//      ...
//   );
  basic u_basic  (
     .clkIn (clkIn),
     .LEDR  (LEDR),
     .tm_clk(tm_clk),
     .tm_cs (tm_cs),
     .tm_dio(tm_dio),
     .regData_in(regData)
);


    //cores
    sm_top sm_top
    (
        .clkIn      ( clkIn     ),
        .rst_n      ( rst_n     ),
        .clkDevide  ( clkDevide ),
        .clkEnable  ( clkEnable ),
        .clk        ( clk       ),
        .regAddr    ( regAddr   ),
        .regData    ( regData   )
    );

    
endmodule