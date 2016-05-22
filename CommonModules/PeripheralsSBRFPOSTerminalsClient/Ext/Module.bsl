
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	// Required output
	Output_Parameters = New Array();

	// Check set parameters.
	SlipReceiptWidth             = Undefined;
	PartialCuttingSymbolCode = Undefined;

	Parameters.Property("SlipReceiptWidth"            , SlipReceiptWidth);
	Parameters.Property("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	
	If SlipReceiptWidth             = Undefined
	 Or PartialCuttingSymbolCode = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.'"));

		Result = False;
	EndIf;
	// End: Check set parameters.

	If Result Then
		DriverObject.SlipReceiptWidth = Number(Parameters.SlipReceiptWidth);
		ConnectionParameters.Insert("LastCardType", Undefined);
	EndIf;

	Return Result;

EndFunction

// Function disconnects a device.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	// Required output
	Output_Parameters = New Array();

	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Payment by a payment card
	If Command = "AuthorizeSales" Then
		Amount      = InputParameters[0];
		CardNumber = InputParameters[1];
		Result = PayByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                    Amount, CardNumber, Output_Parameters);

	// Payment return
	ElsIf Command = "AuthorizeRefund" Then
		Amount      = InputParameters[0];
		CardNumber = InputParameters[1];
		Result = ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                          Amount, CardNumber, Output_Parameters);

	// Cancel payment
	ElsIf Command = "AuthorizeVoid" Then
		Amount          = InputParameters[0];
		RefNo = InputParameters[1];
		ReceiptNumber      = ?(InputParameters.Count() > 2, InputParameters[2], "");
		Result = CancelPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                           Amount, RefNo, ReceiptNumber, Output_Parameters);

	// Emergency payment cancellation
	ElsIf Command = "EmergencyVoid" Then
		Amount          = InputParameters[0];
		RefNo = InputParameters[1];
		ReceiptNumber      = ?(InputParameters.Count() > 2, InputParameters[2], "");
		Result = EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
		                                    Amount, RefNo, ReceiptNumber, Output_Parameters);

	// Totals Revision by Cards
	ElsIf Command = "Settlement" Then
		Result = DayTotalsByCards(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive the slip receipt of the last operation.
	ElsIf Command = "GetSlipReceiptLines" Then
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, Undefined, Output_Parameters);
		
		// Function returns if slip receipt is printed on the terminal.
	ElsIf Command = "PrintSlipOnTerminal" OR Command = "ReceiptsPrintOnTerminal" Then
		Result = ReceiptsPrintOnTerminal(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);
		Result = False;

	EndIf;

	Return Result;

EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Function authorizes (payment) by card.
//
Function PayByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                Amount, CardNumber, Output_Parameters) Export

	Result = True;
	tempAmount = Undefined;
	
	CardCode       = Undefined;
	RefNo = Undefined;
	ReceiptNumber      = Undefined;

	DriverObject.CardType = 0;// ConnectionParameters.CardLastType;?????????????????
	tempAmount = Amount*100;

	Response = DriverObject.PayByPaymentCard(tempAmount, RefNo, ReceiptNumber);
	If Not Response Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add("****************");
			Output_Parameters.Add(RefNo);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);    
			Output_Parameters.Add("");
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        tempAmount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function carries out a chargeback by a card.
//
Function ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                      Amount, CardNumber, Output_Parameters) Export

	Result = True;
	tempAmount = Undefined;
	
	CardCode       = Undefined;
	RefNo = Undefined;
	ReceiptNumber      = Undefined;

	DriverObject.CardType = 0;// ConnectionParameters.CardLastType;?????????????????
	tempAmount = Amount*100;

	Response = DriverObject.ReturnPaymentByPaymentCard(tempAmount, RefNo, ReceiptNumber);
	If Not Response Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add("****************");
			Output_Parameters.Add(RefNo);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);
			Output_Parameters.Add("");
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        tempAmount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function cancels payment by card.
//
Function CancelPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                       Amount, RefNo, ReceiptNumber, Output_Parameters) Export

	Result = True;
	tempAmount = Undefined;
	
	DriverObject.CardType = 0;// ConnectionParameters.CardLastType;?????????????????
	tempAmount = Amount*100;

	Response = DriverObject.CancelPaymentByPaymentCard(tempAmount, RefNo);
	If Not Response Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        tempAmount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function carries out an emergency cancellation of the card operation.
//
Function EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
                                Amount, RefNo, ReceiptNumber, Output_Parameters) Export

	Result = True;

	Output_Parameters.Add(Undefined);

	tempAmount = Amount * 100;
	DriverObject.CardType = 0;

	Response = DriverObject.CancelPaymentByPaymentCard(tempAmount, RefNo);
	If Not Response Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// Function verifies totals by cards.
//
Function DayTotalsByCards(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Response = DriverObject.DayTotalsByCards();
	If Not Response Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Fills the array with slip receipt rows to print in FR.
//
Function GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);

	Result = True;
	SlipReceipt   = "";

	For IndexOf = 1 To DriverObject.LineCountSlipCheck Do
		RowOfCheque = "";

		ResultFunction = DriverObject.GetLineSlipCheque(IndexOf, RowOfCheque);
		If ResultFunction Then
			SlipReceipt = SlipReceipt + RowOfCheque + ?(IndexOf = DriverObject.LineCountSlipCheck, "", Char(13) + Char(10));
		Else
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Error while receiving receipt details.'"));

			Result = False;
		EndIf;
	EndDo;

	If Result Then
		ChequeSlipCopies = "";
		For IndexOf = 1 To DriverObject.SlipReceiptCopiesCount Do
			ChequeSlipCopies = ChequeSlipCopies + SlipReceipt + ?(IndexOf = DriverObject.SlipReceiptCopies,
			                                            "",
			                                            Chars.LF + Char(Parameters.PartialCuttingSymbolCode) + Chars.LF);
		EndDo;
		SlipReceipt = ChequeSlipCopies;
	EndIf;
	
	Return Result;

EndFunction

// Function returns if slip receipt is printed on the terminal.
//
Function ReceiptsPrintOnTerminal(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	Output_Parameters.Clear();  
	Output_Parameters.Add(False);
	Return Result;
	
EndFunction

#EndRegion