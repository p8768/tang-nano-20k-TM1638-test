
//hardware top level module
module sm_top
(
    input           clkIn,
    input           rst_n,
    input   [ 3:0 ] clkDevide,
    input           clkEnable,
    output          clk,
    input   [ 4:0 ] regAddr,
    output  [31:0 ] regData
);

//    localparam       rst_n     =  1'b1;
//    localparam       clkEnable =  1'b1;
//    localparam [3:0] clkDevide =  4'b0011;
//    localparam [4:0] regAddr   =  5'b00010;
    
    // Изменяем объявления проводов для соответствия размерам
    wire    [3:0] devide;
    wire          enable;
    wire    [4:0] addr;
    
    // Подключаем дебаунсеры с правильными размерами
(* keep *) sm_debouncer #(.SIZE(4)) f0(clkIn, clkDevide, devide);
(* keep *) sm_debouncer #(.SIZE(1)) f1(clkIn, clkEnable, enable);
(* keep *) sm_debouncer #(.SIZE(5)) f2(clkIn, regAddr, addr);

    //cores
    //clock devider
    sm_clk_divider sm_clk_divider
    (
        .clkIn      ( clkIn     ),
        .rst_n      ( rst_n     ),
        .devide     ( devide    ),
        .enable     ( enable    ),
        .clkOut     ( clk       )
    );

    //instruction memory
    wire    [31:0]  imAddr;
    wire    [31:0]  imData;
    sm_rom reset_rom(imAddr, imData);

    sm_cpu sm_cpu
    (
        .clk        ( clk       ),
        .rst_n      ( rst_n     ),
        .regAddr    ( addr      ),
        .regData    ( regData   ),
        .imAddr     ( imAddr    ),
        .imData     ( imData    )
    );

endmodule

//metastability input debouncer module
module sm_debouncer
#(
    parameter SIZE = 1
)
(
    input                      clk,
    input      [ SIZE - 1 : 0] d,
    output reg [ SIZE - 1 : 0] q
);
    reg        [ SIZE - 1 : 0] data;

    always @ (posedge clk) begin
        data <= d;
        q    <= data;
    end

endmodule

//tunable clock devider
module sm_clk_divider
#(
    parameter shift  = 16,
              bypass = 0
)
(
    input           clkIn,
    input           rst_n,
    input   [ 3:0 ] devide,
    input           enable,
    output          clkOut
);
    wire [31:0] cntr;
    wire [31:0] cntrNext = cntr + 1;
    sm_register_we r_cntr(clkIn, rst_n, enable, cntrNext, cntr);

    assign clkOut = bypass ? clkIn 
                           : cntr[shift + devide];
endmodule
