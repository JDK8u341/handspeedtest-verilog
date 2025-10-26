module speedtest(
    input sys_clk,          // 27MHz时钟输入
    input s1,        //button_state 1
    input s2,       //button_state 2   
    output reg [5:0] led = 6'b110011 // 6位LED输出
);

reg [2:0] state = 3'b000;   //状态

//定义状态
parameter INIT = 3'd0;    //初始化（动画）    
parameter HOME = 3'd1;    //主界面（好吧压根没有界面）
parameter START_GAME = 3'd2;  //游戏开始
parameter RANDOM_LED_ING_DISPLAY = 3'd3;    //随机抽取位置时的动画
parameter GAME_BUTTON_WAIT = 3'd4;   //LOOP等待按键按下
parameter GAMEOVER = 3'd5;  //游戏结束
parameter SEED = 16'd11451; //种子

//时间单位定义
parameter ONE_SEC = 27'd2700_0000; // 27MHz * 1s = 27,000,000
parameter HALF_SEC = 27'd1350_0000;
parameter H4_1_SEC = 27'd675_0000;
parameter H8_1_SEC = 27'd337_5000;
parameter H16_1_SEC = 27'd168_7500;

parameter TIME_OUT_SEC = 3; //超时时间

reg [26:0] time_counter = 27'b0;    //时间计数器
reg [3:0] counter = 4'b0;   //公用计数器
reg [7:0] score_counter = 8'b0; //得分计数器，最大255

reg [5:0] tmp_led = 6'b111111; //LED位置预存


parameter BUTTON_DELAY_START = 3'b000; //消抖计数器初始
parameter BUTTON_DELAY_STEP = 3'b001;  //消抖计数器步长
parameter BUTTON_DELAY_FULL = 3'b111;   //消抖计数器满值
reg [2:0] s1_delay = BUTTON_DELAY_START;    //按键s1的计数器
reg [2:0] s2_delay = BUTTON_DELAY_START;    //s2的

parameter NO_BUTTON = 2'd2;     //状态：没有按键按下
parameter BUTTON1 = 2'd1;       //按键1按下
parameter BUTTON2 = 2'd0;       //按键2按下

reg [1:0] last_button_state = NO_BUTTON;  //上次按键状态
reg [1:0] button_state = NO_BUTTON;     //按键状态寄存器，初始为无按下

reg [15:0] lfsr_reg = SEED;  //计算用
reg [6:0] random_out;   //onehot随机数
reg pleace;  //临时存储

//等级划分(单位：分)
parameter LEVEL_1 = 5;
parameter LEVEL_2 = 10;
parameter LEVEL_3 = 40;
parameter LEVEL_4 = 80;
parameter LEVEL_5 = 150;

parameter AT_LEFT = 0;
parameter AT_RIGHT = 1;

reg [2:0] to_counter;

//伪随机数
wire feedback = lfsr_reg[15] ^ lfsr_reg[14] ^ lfsr_reg[12] ^ lfsr_reg[3];


always @(posedge sys_clk) begin
   lfsr_reg <= {lfsr_reg[14:0], feedback};
   case (lfsr_reg[15:13] % 3'd6)     //case转one-hot
        3'd0: random_out <= 7'b111110_1;  //PS:最后一位是判断位，用于判断在左（0）或者右（1）
        3'd1: random_out <= 7'b111101_1;
        3'd2: random_out <= 7'b111011_1;
        3'd3: random_out <= 7'b110111_0;
        3'd4: random_out <= 7'b101111_0;
        3'd5: random_out <= 7'b011111_0;      
        3'd6: random_out <= 7'b111011_1;
        default: random_out <= 7'b110111_0;
   endcase
end

//按键处理部分
always @(posedge sys_clk) begin 
    last_button_state <= button_state;
    if (!s1) begin  //检测button1
        if (s1_delay == BUTTON_DELAY_FULL) begin  //检查消抖 
            button_state <= BUTTON1;    //更改状态
            //重置消抖计数器
            s1_delay <= BUTTON_DELAY_START;
            s2_delay <= BUTTON_DELAY_START;
        end
        else begin
            s1_delay <= s1_delay + BUTTON_DELAY_STEP;
        end
    end
    else if (!s2) begin  //检测button2
        if (s2_delay == BUTTON_DELAY_FULL) begin //检查消抖 
            button_state <= BUTTON2;
            s1_delay <= BUTTON_DELAY_START;
            s2_delay <= BUTTON_DELAY_START;
        end
        else begin
            s2_delay <= s2_delay + BUTTON_DELAY_STEP;
        end
    end
    else  begin  
        button_state <= NO_BUTTON;
        s1_delay <= BUTTON_DELAY_START;
        s2_delay <= BUTTON_DELAY_START;
    end
end

//主逻辑部分
always @(posedge sys_clk) begin
   //时间计数器处理
   if (time_counter >= ONE_SEC) begin   //一秒以上重置
        time_counter <= 27'b0;  
   end else begin
        time_counter <= time_counter + 27'b1;   //否则增加
   end
   case (state)     //主逻辑
   INIT: begin
        if(counter < 3) begin
            if(time_counter >= ONE_SEC) begin
                led <= {led[2:0],led[5:3]};     //LED的动画
                counter <= counter + 4'b1;
            end
        end
        else begin
       //     转移状态
            counter <= 0;   //重置计数器
            state <= HOME;   //跳到HOME
            led <= 6'b000000;   //重置LED
            time_counter <= 27'b0;
        end
    end
    HOME: begin
       // 动画
        if (counter < 4) begin
            if (time_counter == H8_1_SEC) begin
                led <= ~led;        //动画
                counter <= counter + 4'b1;
            end    
        end
        else if (counter == 4) begin
            led <= 6'b101101;
            counter <= counter + 4'b1;
        end
        else if(button_state == BUTTON1) begin  //如果按键1按下
            counter <= 4'b0;   //重置计数器
            state <= START_GAME;    //转移到开始游戏
            led <= 6'b111111;
            time_counter <= 27'b0;
        end
    end
    START_GAME: begin
        if (counter < 6) begin
            if (time_counter == H4_1_SEC) begin
                led[counter] <= 0;      //模拟进度条
                counter <= counter + 4'b1;
            end
        end
        else begin 
            counter <= 4'b0;
            state <= RANDOM_LED_ING_DISPLAY;
            led <= 6'b111111;
            time_counter <= 27'b0;
            tmp_led <= random_out[6:1];
            pleace <= random_out[0]; //位置的值(首次使用)
        end
    end
    RANDOM_LED_ING_DISPLAY: begin
        if (counter == 4'b0) begin 
                led <= tmp_led;  //写入
                //不能在这里更新，不然下一个state是在下一个clk进行的！
                counter <= counter + 4'b1;
        end
        else if (time_counter >= HALF_SEC)begin
            counter <= 4'b0;
            state <= GAME_BUTTON_WAIT;  //转移到等待按键
            time_counter <= 27'b0;
        end
    end
   GAME_BUTTON_WAIT: begin
        if (button_state != NO_BUTTON) begin   //赢了继续
            if (pleace == button_state[0]) begin
                counter <= 4'b0;
                led <= 6'b000000;
                state <= RANDOM_LED_ING_DISPLAY;    //转移回到LED随机
                score_counter <= score_counter + 8'b1;
                time_counter <= 27'b0;
                pleace <= random_out[0]; //位置的值（这里早一个clk！）
                tmp_led <= random_out[6:1];     //更新存贮（同理！）
            end
            else begin
                counter <= 4'b0;
                led <= 6'b111111;
                state <= GAMEOVER;  //输了结束
                time_counter <= 27'b0;
            end
        end
        else if(time_counter >= ONE_SEC) begin    
            if (counter >= TIME_OUT_SEC) begin
                counter <= 4'b0;
                led <= 6'b111111;
                state <= GAMEOVER;  //输了结束
                time_counter <= 27'b0;
            end
            else begin 
                counter <= counter + 4'b1;   //记上！
            end
        end    
    end
    GAMEOVER: begin     //结算
        //评级
        if (score_counter < LEVEL_1) begin
            to_counter <= 3'd1;
        end
        else if (score_counter < LEVEL_2) begin
            to_counter <= 3'd2;
        end
        else if (score_counter < LEVEL_3) begin
            to_counter <= 3'd3;
        end
        else if (score_counter < LEVEL_4) begin
            to_counter <= 3'd4;
        end
        else if (score_counter < LEVEL_5) begin
            to_counter <= 3'd5;
        end
        else begin
            to_counter <= 3'd6;
        end
        if (counter < to_counter) begin
            if (time_counter == HALF_SEC) begin
                led[counter] <= 0;      //模拟进度条
                counter <= counter + 4'b1;
            end
        end
        else if (button_state!=NO_BUTTON) begin
             counter <= 4'b0;
            led <= 6'b111111;
            state <= INIT;  //重开
            score_counter <= 8'b0;
            time_counter <= 27'b0;
        end
    end
endcase
           
end

endmodule