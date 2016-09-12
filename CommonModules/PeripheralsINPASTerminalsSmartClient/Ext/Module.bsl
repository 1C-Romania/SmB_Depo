                                      
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Output_Parameters = New Array();
	
	TerminalID = Undefined;
	Port        = Undefined;
	Speed    = Undefined;
	DataBits  = Undefined;
	Parity    = Undefined;
	StopBits    = Undefined;
	FlowControl    = Undefined;
	SlipReceiptWidth       = Undefined;
	CopiesCount      = Undefined;
	HeaderText = Undefined;
	FooterText = Undefined;
	SlipReceiptTemplateData = Undefined;
	
	Parameters.Property("TerminalID", TerminalID);
	Parameters.Property("Port", Port);
	Parameters.Property("Speed", Speed);
	Parameters.Property("DataBits", DataBits);
	Parameters.Property("Parity", Parity);
	Parameters.Property("StopBits", StopBits);
	Parameters.Property("FlowControl", FlowControl);
	Parameters.Property("SlipReceiptWidth", SlipReceiptWidth);
	Parameters.Property("CopiesCount", CopiesCount);
	Parameters.Property("HeaderText", HeaderText);
	Parameters.Property("FooterText", FooterText);
	Parameters.Property("SlipReceiptTemplateData", SlipReceiptTemplateData);
	
	If Not Parameters.Property("TerminalID")
	 Or Parameters.TerminalID  = Undefined
	 Or Parameters.Port         = Undefined
	 Or Parameters.Speed     = Undefined 
	 Or Parameters.DataBits   = Undefined
	 Or Parameters.Parity     = Undefined
	 Or Parameters.StopBits     = Undefined
	 Or Parameters.FlowControl = Undefined
	 Or Parameters.SlipReceiptWidth    = Undefined
	 Or Parameters.CopiesCount   = Undefined
	 Or Parameters.HeaderText   = Undefined
	 Or Parameters.FooterText   = Undefined
	 Or Parameters.SlipReceiptTemplateData = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set."
"For the correct work of the device it is necessary to specify the parameters of its work."
"You can do it using the Parameters setting"
"form of the peripheral model in the Connection and equipment setting form.';ru='Не настроены параметры устройства."
"Для корректной работы устройства необходимо задать параметры его работы."
"Сделать это можно при помощи формы"
"""Настройка параметров"" модели подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));
		Return False;
	EndIf;
	
	Result = DriverObject.Connect(Parameters);
	If Result Then
		ConnectionParameters.Insert("OriginalTransactionCode", Undefined);
		ConnectionParameters.Insert("OperationKind", "");
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

// Function disconnects a device.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Result = True;
	Output_Parameters = New Array();
	Try
		DriverObject.Disable();	
	Except
		Result = False;
	EndTry;	
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
		Amount           = InputParameters[0];
		CardNumber      = InputParameters[1];
		RefNo = ?(InputParameters.Count() > 2, InputParameters[2], "");
		ReceiptNumber      = ?(InputParameters.Count() > 3, InputParameters[3], "");
		Result = ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                          Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);
	  
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

	// Payment preauthorization
	ElsIf Command = "AuthorizePreSales" Then
		Amount      = InputParameters[0];
		CardNumber = InputParameters[1];

		Result = PreauthorizeByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                            Amount, CardNumber, Output_Parameters);

	// Ends preauthorization of the payment.
	ElsIf Command = "AuthorizeCompletion" Then
		Amount          = InputParameters[0];
		CardNumber     = InputParameters[1];
		RefNo = InputParameters[2];
		ReceiptNumber      = InputParameters[3];

		Result = FinishPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                                    Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);

	// Cancel preauthorization of payment.
	ElsIf Command = "AuthorizeVoidPreSales" Then
		Amount          = InputParameters[0];
		CardNumber     = InputParameters[1];
		RefNo = InputParameters[2];
		ReceiptNumber      = InputParameters[3];

		Result = CancelPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                                   Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);

	// Receiving a slip receipt of the last operation.
	ElsIf Command = "GetSlipReceiptLines" Then
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, Undefined, Output_Parameters);

	// Test device
	ElsIf Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive driver version
	ElsIf Command = "GetVersionNumber" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Function returns whether the slip receipts will be printed on the terminal.
	ElsIf Command = "PrintSlipOnTerminal" OR Command = "ReceiptsPrintOnTerminal" Then
		Result = ReceiptsPrintOnTerminal(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.';ru='Команда ""%Команда%"" не поддерживается данным драйвером.'"));
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
                                Amount, CardNumber, Output_Parameters)

	Result = True;

	RefNo = "";
	AuthorizationCode = "";

	ConnectionParameters.OperationKind = NStr("en='Pay';ru='Оплатить'");

	SetDriverParameters(DriverObject, Parameters);
		
	Response = DriverObject.PayByPaymentCard(CardNumber, Amount, RefNo, AuthorizationCode);
	
	If Not Response Then
		ConnectionParameters.OperationKind = "Cancel";
		Output_Parameters.Add(999);
		Output_Parameters.Add("");		
		ErrorCode = DriverObject.GetError(Output_Parameters[1]);
		Result = False;
	Else
		ConnectionParameters.OriginalTransactionCode = RefNo;
		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(CardNumber);
			Output_Parameters.Add(RefNo);
			Output_Parameters.Add(DriverObject.ReceiptNumbers);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);
			Output_Parameters.Add("");
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        Amount, RefNo, DriverObject.ReceiptNumbers, Output_Parameters);
		EndIf;	
	EndIf;    
	Return Result;
EndFunction

// Function carries out a chargeback by a card.
//
Function ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                      Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	ConnectionParameters.OperationKind = NStr("en='Payment return';ru='Возврат платежа'");

	SetDriverParameters(DriverObject, Parameters);
    
	Response = DriverObject.ReturnPaymentByPaymentCard(CardNumber,
	                                                     Amount,
	                                                     RefNo,
	                                                     ReceiptNumber);
	If Not Response Then
		ConnectionParameters.OperationKind = "Cancel";
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		OperationCode = DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		ConnectionParameters.OriginalTransactionCode = DriverObject.NumberReferences;

		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(CardNumber);
			Output_Parameters.Add(RefNo);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);
			Output_Parameters.Add("");
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        Amount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function cancels payment by card.
//
Function CancelPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                      Amount, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	ConnectionParameters.OperationKind = NStr("en='Cancel payment';ru='Отменить платеж'");

	SetDriverParameters(DriverObject, Parameters);
	
	Response = DriverObject.CancelPaymentByPaymentCard("", Amount, RefNo);
	If Not Response Then
		ConnectionParameters.OperationKind = "Cancel";
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		OperationCode = DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		ConnectionParameters.OriginalTransactionCode = DriverObject.NumberReferences;

		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        Amount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;
	
	Return Result;

EndFunction

// Function carries out an emergency cancellation of the card operation.
//
Function EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
                                Amount, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	SetDriverParameters(DriverObject, Parameters);

	DriverObject.NumberReferences = ConnectionParameters.OriginalTransactionCode;

	Response = DriverObject.EmergencyCancelOperations("", Amount, RefNo, ReceiptNumber);
	If Not Response Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		OperationCode = DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// Function verifies totals by cards.
//
Function DayTotalsByCards(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	Response     = Undefined;

	ConnectionParameters.OperationKind = NStr("en='Totals revision';ru='Сверка итогов'");

	SetDriverParameters(DriverObject, Parameters);

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

// Function carries out preauthorization by a card.
// 
Function PreauthorizeByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                        Amount, CardNumber, Output_Parameters)

	Result = True;

	RefNo = Undefined;
	ReceiptNumber      = Undefined;

	ConnectionParameters.OperationKind = NStr("en='Pre-authorize payment';ru='Преавторизовать платеж'");

	SetDriverParameters(DriverObject, Parameters);
    
	
	Response = DriverObject.PreautorizationByPaymentCard(CardNumber,
	                                                      Amount,
	                                                      RefNo,
	                                                      ReceiptNumber);
	If Not Response Then
		ConnectionParameters.OperationKind = "Cancel";
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		OperationCode = DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		ConnectionParameters.OriginalTransactionCode = DriverObject.NumberReferences;

		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(CardNumber);
			Output_Parameters.Add(RefNo);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);
			Output_Parameters.Add("");
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        Amount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;


	Return Result;

EndFunction

// Function ends preauthorization by a card.
//
Function FinishPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                                Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	ConnectionParameters.OperationKind = NStr("en='Finish preauthorization';ru='Завершить преавторизацию'");

	SetDriverParameters(DriverObject, Parameters);
    
	Response = DriverObject.FinishPreauthorizationByPaymentCard(CardNumber,
	                                                                Amount,
	                                                                RefNo,
	                                                                ReceiptNumber);
	If Not Response Then
		ConnectionParameters.OperationKind = "Cancel";
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		OperationCode = DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		ConnectionParameters.OriginalTransactionCode = DriverObject.NumberReferences;

		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        Amount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function cancels preauthorization by a card.
//
Function CancelPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                               Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	ConnectionParameters.OperationKind = NStr("en='Cancel preauthorization';ru='Отменить преавторизацию'");

	SetDriverParameters(DriverObject, Parameters);

	Response = DriverObject.CancelPreauthorizationByPaymentCard(CardNumber,
	                                                              Amount,
	                                                              RefNo);
	If Not Response Then
		ConnectionParameters.OperationKind = "Cancel";
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		OperationCode = DriverObject.GetError(Output_Parameters[1]);

		Result = False;
	Else
		ConnectionParameters.OriginalTransactionCode = DriverObject.NumberReferences;

		SlipReceipt = Undefined;
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
		If Result Then
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
			                        Amount, RefNo, ReceiptNumber, Output_Parameters);
		EndIf;
	EndIf;

	Return Result;

EndFunction
 
// Function tests device.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	TestResult = "";

	SetDriverParameters(DriverObject, Parameters);
	Result = DriverObject.DeviceTest(TestResult);

	Output_Parameters.Add(?(Result, 0, 999));
	Output_Parameters.Add(TestResult);

	Return Result;

EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
	Output_Parameters.Add(NStr("en='Not defined';ru='Не определена'"));

	Try
		Output_Parameters[1] = DriverObject.GetVersionNumber();
	Except
		Result = False;
	EndTry;

	Return Result;

EndFunction
 
// Fills the array with the strings of the slip receipt for subsequent printing on fiscal register.
//
Function GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters)

	Result = True;
	SlipReceipt = DriverObject.ReceiptText;
	Return Result;

EndFunction

// Set driver parameters.
//
Procedure SetDriverParameters(DriverObject, Parameters)

	// System parameters
	DriverObject.TerminalID = Parameters.TerminalID;
	DriverObject.Port = Parameters.Port;
	DriverObject.Speed = Parameters.Speed;
	DriverObject.CurrencyCode = Parameters.CurrencyCode;
	DriverObject.CutCharCode = Parameters.CutCharCode;
	
	If Parameters.Property("HeaderText") Then
		DriverObject.HeaderText = Parameters.HeaderText;
	EndIf;
	
	If Parameters.Property("FooterText") Then
		DriverObject.FooterText = Parameters.FooterText;
	EndIf;

EndProcedure

// Function returns whether the slip receipts will be printed on the terminal.
//
Function ReceiptsPrintOnTerminal(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	Output_Parameters.Clear();  
	Output_Parameters.Add(False);
	Return Result;
	
EndFunction

#EndRegion