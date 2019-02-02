module cometSprite(input clock, start, reset,
input [7:0] X_initial,
input [6:0] Y_initial,
input [2:0] colour_background,
output [7:0] X_pos_bkg, 
output [6:0] Y_pos_bkg,
output [2:0] colourOUT);
//this module will draw one pixel each clock cycle at the specified location on the
//vga display
//each time you instantiate this module, an asteroid will be drawn
//and fly across the screen
wire [2:0] colourRAM;
wire [2:0] outColour;
//we take this from the cometspriteRAM part
//colourRAM connects to colourOUT, which is the output colour we see on the vga
//^^ these are the current position of the comet that we are drawing
wire [9:0] cometOutputAddress;
wire [7:0] outx;
wire [6:0] outy;
assign X_pos_bkg = outx;
assign Y_pos_bkg = outy;

wire doneDrawing;
wire i,j, go, resetLoc;
wire [1:0] alu_op;
assign cometOutputAddress=5*j+i;

cometSpriteRAM c
(.address(cometOutputAddress),.clock(clock),.data(9'b0),.wren(1'b0),
.q(colourRAM));

data_path d(.clock(clock),.reset(reset),.inputY(Y_initial),.inputX(X_initial),.alu_op(alu_op[1:0]),
.X_pos_bkg(outx),.Y_pos_bkg(outy),.colourRAM(colourRAM),.i(i),.j(j),
.resetCometLoc(resetLoc),.go(go),.colourComet(outColour),.colourBackground(colour_background));

control_path c1(.clock(clock),.start(start),.reset(reset),.go(go),
.endOfScreen(resetLoc),.alu_op(alu_op[1:0]));

assign colourOUT=outColour;
endmodule

module control_path(input clock, start, reset, go, endOfScreen, 
        output reg [1:0] alu_op);
//active high parameters
//start: signal to start moving left
//reset: signal to end game
//end of screen: we have moved the asteroid to the end of the screen
reg [4:0] current_state, next_state;
wire countDone;
wire counterDone;
localparam [4:0]  
    S_WAIT=5'd0,
    S_PLOT=5'd1,
    S_COUNTER=5'd2,
    S_ERASE=5'd3,
    S_MOVE=5'd4, 
    S_RESET_COMET_LOC=5'd5;
    
rate_divider r(.clock(clock),.enable(1'b1),.load(26'd12499999),
.reset(reset),.countDone(countDone));
assign counterDone=countDone; 
   
always @(*)begin
case(current_state)
S_WAIT: next_state=start?S_PLOT:S_WAIT;
S_PLOT: begin
    if(reset)
     next_state=S_WAIT;
    else
     next_state=go?S_COUNTER:S_PLOT;
  end
S_COUNTER: begin
  if(reset) 
   next_state=S_WAIT;
  else
   next_state=counterDone?S_ERASE:S_COUNTER;
   end
S_ERASE: begin 
   if(reset)
    next_state=S_WAIT;
   else
    next_state=go?S_MOVE:S_ERASE;
   end
S_MOVE: begin
   if(reset)
    next_state=S_WAIT;
   else
    next_state=endOfScreen?S_RESET_COMET_LOC:S_PLOT;
   end
S_RESET_COMET_LOC: begin
   if(reset)
    next_state=S_WAIT;
   else
    next_state=go?S_RESET_COMET_LOC:S_PLOT;
   end
default: next_state=S_WAIT;

endcase
end


always @(*)
begin
//default to 0
case(current_state)
S_PLOT: begin
alu_op=2'b01;
end
S_ERASE: begin
alu_op=2'b00;
end
S_MOVE: begin
alu_op=2'b10;
end
S_RESET_COMET_LOC: begin
alu_op=2'b11;
end
endcase

end

always @(posedge clock)begin
if(reset)
	current_state<=S_WAIT;
else 
	current_state<=next_state;
end

endmodule

module data_path(clock, reset, go, X_pos_bkg, Y_pos_bkg, inputY, inputX, colourComet, 
colourBackground, colourRAM, i, j, alu_op, resetCometLoc);


	input [2:0] colourBackground;
	input [1:0] alu_op;
	input [2:0] colourRAM;
	input clock, reset;
	input [6:0] inputY;
	input [7:0] inputX;
	
	output reg [7:0] X_pos_bkg;
	output reg [6:0] Y_pos_bkg;
	output reg [2:0] colourComet;
	output reg [9:0] i,j;
	output reg resetCometLoc;
	output reg go;
	
	reg doneDrawing;
	reg [9:0] X,Y;
	//X and Y is the top left pixel we want to draw on the spaceship as projected
	//on the background 
	localparam [3:0] maxAddressX=3'b100, maxAddressY=3'b100;
//this draws the individual comet pixel by pixel, i and j are parameters local 
//to the dimensions of the comet

	always @(posedge clock)
		begin
		 if(reset)begin
		  doneDrawing=0;
		  i<=9'b0;
		  j<=9'b0;
		 end
		 
		 else begin
		  if(i==maxAddressX && j!=maxAddressY && doneDrawing==0) begin
			i<=9'b0;
			j<=j+9'b0000000001;
			//move to next row, start incrementing the i
		  end
		  
		  else if(j==maxAddressY && i==maxAddressX)begin
			doneDrawing<=1'b1;
		  end
		  else
			i<=i+9'b0000000001;
			//increments the pixel on the row
		 end
		end

		//this will draw the comet, move it, erase it, find the next location, draw it again
		//then move it
		//ratedivider will be used to make this process happen every 0.25 seconds 
	always @(posedge clock)
		begin
		if(reset) begin
		 go<=1'b0;
		 resetCometLoc<=1'b0;
		 X_pos_bkg<=inputX;
		 Y_pos_bkg<=inputY;
		 colourComet<=colourBackground;
		end
		 
		case(alu_op)
		 
		 1: begin
		 X_pos_bkg<=X+i;
		 Y_pos_bkg<=Y+j;
		 //x and y position on background should equal to X and Y (where we want to move 
		 //the whole piece set by S_MOVe) plus the i and j position of individual pixels  
		 colourComet<=colourRAM;
		 go<=1'b1;
		 end
		 
		 0: begin
		 X_pos_bkg<=X+i;
		 Y_pos_bkg<=Y+j;
		 
		 colourComet<=colourBackground;
		 go<=1'b1;
		 //change this to match the colour of background
		 //***figure out how to erase the comet and replace it with the colour of the background
		 
		 end
		 
		 2: begin
		 //comet will only move in one direction: towards the left if we have not hit the end
		 
		 Y<=inputY;
		 //Y will be set to the position we input in our top level module 
		 
		 if(X>0) 
		 X<=X-9'b000000001;
		 
		 else if(X==0)begin
		 resetCometLoc<=1'b1;
		 //X is moved to the 160 position at the right end of the screen if we have hit 0
		 end
		 //this should happen every 0.25 seconds (as determined by the datapath
		 end
		 
		 3: begin
		 //reset comet to initial position
		 X<=inputX;
		 Y<=inputY;
		 go<=1'b1;
		 end
		 
		 default: begin
		 //default X to the end of screen
		//default Y to the user input value of Y
		 X<=inputX;
		 Y<=inputY;
		 go<=1'b0;
		 resetCometLoc<=1'b0;
		 //*****figure out where to put starting values
		 end
	endcase
end
endmodule


module rate_divider(clock, enable, load, reset, countDone);
input clock, enable, reset;
input [25:0] load;
reg [25:0] count;
output reg countDone;
	always @(posedge clock)begin
		if (reset)begin
			count<=load;
			countDone=1'b0;
	  end
	 else if (count==26'b0 &&enable==1'b1)begin
			count<=load;
			countDone=1'b1;
	  end
	 else if (enable==1'b1)
			count=count-1;
	 end
 
endmodule

