
#Region ProgramInterface

// Function connects a device.
//
// Parameters:
//  DriverObject   - <*>
//           - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Check set parameters.
	SlipReceiptWidth           = Undefined;
	SlipReceiptCopiesCount     = Undefined;
	SlipReceiptTemplateData    = Undefined;

	Parameters.Property("SlipReceiptWidth",          SlipReceiptWidth);
	Parameters.Property("SlipReceiptCopiesCount", SlipReceiptCopiesCount);
	Parameters.Property("SlipReceiptTemplateData",    SlipReceiptTemplateData);

	If SlipReceiptWidth          = Undefined
	 Or SlipReceiptCopiesCount   = Undefined
	 Or SlipReceiptTemplateData  = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.';ru='Не настроены параметры устройства.
		|Для корректной работы устройства необходимо задать параметры его работы.
		|Сделать это можно при помощи формы
		|""Настройка параметров"" модели подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));

		Result = False;
	EndIf;
	// End: Check set parameters.

	If Result Then
		ConnectionParameters.Insert("OperationKind", "");
		ConnectionParameters.Insert("CardNumber", "");
		ConnectionParameters.Insert("ReceiptNumber", "");
		ConnectionParameters.Insert("RefNo", "");
	EndIf;

	Return Result;

EndFunction

// Function disconnects a device.
//
// Parameters:
//  DriverObject - <*>
//         - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

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
	If Command    = "AuthorizeSales" Then
		Amount      = InputParameters[0];
		CardNumber  = InputParameters[1];
		Result = PayByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                    Amount, CardNumber, Output_Parameters);

	// Payment return
	ElsIf Command     = "AuthorizeRefund" Then
		Amount          = InputParameters[0];
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
	ElsIf Command    = "EmergencyVoid" Then
		Amount         = InputParameters[0];
		RefNo          = InputParameters[1];
		ReceiptNumber  = ?(InputParameters.Count() > 2, InputParameters[2], "");
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
	ElsIf Command       = "AuthorizeCompletion" Then
		Amount             = InputParameters[0];
		CardNumber         = InputParameters[1];
		RefNo              = InputParameters[2];
		ReceiptNumber      = InputParameters[3];

		Result = FinishPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                                    Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);

	// Cancel preauthorization of payment.
	ElsIf Command        = "AuthorizeVoidPreSales" Then
		Amount             = InputParameters[0];
		CardNumber         = InputParameters[1];
		RefNo              = InputParameters[2];
		ReceiptNumber      = InputParameters[3];

		Result = CancelPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                                   Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);

	// Receive the slip receipt of the last operation.
	ElsIf Command = "GetSlipReceiptLines" Then
		Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, Undefined, Output_Parameters);

	// Test device
	ElsIf Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Function returns if slip receipt is printed on the terminal.
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
	ReceiptNumber      = "";

	ConnectionParameters.OperationKind = NStr("en='Pay';ru='Оплатить'");

	SetDriverParameters(DriverObject, Parameters);

	// Transform card numbers into card code and validity term.
	CardCode = "";

	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.PayByPaymentCard(CardCode,
		                                               tempAmount,
		                                               RefNo,
		                                               ReceiptNumber);
		If Not Response Then
			ConnectionParameters.OperationKind = NStr("en='Cancel';ru='Отменить'");
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.FIELDRESPONSETEXT);
			OperationCode = DriverObject.GetError(Output_Parameters[1]);
			Output_Parameters[0] = OperationCode;

			Result = False;
		Else
			ConnectionParameters.Insert("CardNumber", 	CardCode);
			ConnectionParameters.Insert("ReceiptNumber", 		ReceiptNumber);
			ConnectionParameters.Insert("RefNo", RefNo);

			SlipReceipt = Undefined;
			Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
			If Result Then
				Output_Parameters.Add(CardCode);
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
	EndIf;

	Return Result;

EndFunction

// Function carries out a chargeback by a card.
//
Function ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                      Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	//RefNumber = Undefined;
	//ReceiptNumber      = Undefined.

	ConnectionParameters.OperationKind = NStr("en='Payment return';ru='Возврат платежа'");

	SetDriverParameters(DriverObject, Parameters);

	// Transform card numbers into card code and validity term.
	CardCode = "";

	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.ReturnPaymentByPaymentCard(CardCode,
		                                                     tempAmount,
		                                                     RefNo,
		                                                     ReceiptNumber);
		If Not Response Then
			ConnectionParameters.OperationKind = "Cancel";
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			OperationCode = DriverObject.GetError(Output_Parameters[1]);

			Result = False;
		Else
			ConnectionParameters.Insert("CardNumber", 	CardCode);
			ConnectionParameters.Insert("ReceiptNumber", 		ReceiptNumber);
			ConnectionParameters.Insert("RefNo", RefNo);

			SlipReceipt = Undefined;
			Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
			If Result Then
				Output_Parameters.Add(CardCode);
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
	EndIf;

	Return Result;

EndFunction

// Function cancels payment by card.
//
Function CancelPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                      Amount, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	RefNo = Undefined;
	ReceiptNumber      = Undefined;
	CardNumber 	   = "";

	ConnectionParameters.OperationKind = NStr("en='Cancel payment';ru='Отменить платеж'");

	SetDriverParameters(DriverObject, Parameters);

	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.CancelPaymentByPaymentCard(CardNumber,
		                                                       tempAmount,
		                                                       RefNo);
		If Not Response Then
			ConnectionParameters.OperationKind = NStr("en='Cancel';ru='Отменить'");
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			OperationCode = DriverObject.GetError(Output_Parameters[1]);

			Result = False;
		Else
			ConnectionParameters.Insert("CardNumber", 	CardNumber);
			ConnectionParameters.Insert("ReceiptNumber", 		ReceiptNumber);
			ConnectionParameters.Insert("RefNo", RefNo);

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
	EndIf;

	Return Result;

EndFunction

// Function carries out an emergency cancellation of the card operation.
//
Function EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
                                Amount, RefNo, ReceiptNumber, Output_Parameters)

	Result = True;

	SetDriverParameters(DriverObject, Parameters);

	//DriverObject.OperationIDOnTerminal = ConnectionParameters.OriginalTransactionCode;
	tempAmount = Amount * 100;

	Response = DriverObject.EmergencyCancelOperations("", tempAmount * 100, RefNo, ReceiptNumber);
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
		SlipReceipt = "";

		Output_Parameters.Add(New Array());
		Output_Parameters[0].Add("SlipReceipt");
		Output_Parameters[0].Add(SlipReceipt);
	EndIf;

	Return Result;

EndFunction

// Function carries out preauthorization by a card.
// 
Function PreauthorizeByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                        Amount, CardNumber, Output_Parameters)

	Result = True;

	RefNo         = Undefined;
	ReceiptNumber = Undefined;

	ConnectionParameters.OperationKind = NStr("en='Pre-authorize payment';ru='Преавторизовать платеж'");

	SetDriverParameters(DriverObject, Parameters);

	// Transform card numbers into card code and validity term.
	CardCode = "";
	
	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.PreautorizationByPaymentCard(CardCode,
		                                                      tempAmount,
		                                                      RefNo,
		                                                      ReceiptNumber);
		If Not Response Then
			ConnectionParameters.OperationKind = NStr("en='Cancel';ru='Отменить'");
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			OperationCode = DriverObject.GetError(Output_Parameters[1]);

			Result = False;
		Else
			ConnectionParameters.Insert("CardNumber", 	CardCode);
			ConnectionParameters.Insert("ReceiptNumber", 		ReceiptNumber);
			ConnectionParameters.Insert("RefNo", RefNo);

			SlipReceipt = Undefined;
			Result = GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters);
			If Result Then
				Output_Parameters.Add(CardCode);
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

	// Transform card numbers into card code and validity term.
	CardCode = "";
	
	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.CompletionPreauthorizationForPaymentCard(CardCode,
		                                                                tempAmount,
		                                                                RefNo,
		                                                                ReceiptNumber);
		If Not Response Then
			ConnectionParameters.OperationKind = NStr("en='Cancel';ru='Отменить'");
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			OperationCode = DriverObject.GetError(Output_Parameters[1]);

			Result = False;
		Else
			ConnectionParameters.Insert("CardNumber", 	CardCode);
			ConnectionParameters.Insert("ReceiptNumber", 		ReceiptNumber);
			ConnectionParameters.Insert("RefNo", RefNo);

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

	// Transform card numbers into card code and validity term.
	CardCode = "";
	
	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.CancelPreauthorizationByPaymentCard(CardCode,
		                                                              tempAmount,
		                                                              RefNo);
		If Not Response Then
			ConnectionParameters.OperationKind = NStr("en='Cancel';ru='Отменить'");
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			OperationCode = DriverObject.GetError(Output_Parameters[1]);

			Result = False;
		Else
			ConnectionParameters.Insert("CardNumber", 	CardCode);
			ConnectionParameters.Insert("ReceiptNumber", 		ReceiptNumber);
			ConnectionParameters.Insert("RefNo", RefNo);

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
	EndTry;

	Return Result;

EndFunction

 // Fills the array with slip receipt rows to print in FR.
//
Function GetSlipReceiptLines(DriverObject, Parameters, ConnectionParameters, SlipReceipt, Output_Parameters)

	Result = True;
	TemplateName = "SlipReceiptSoftCase";

	If ConnectionParameters.OperationKind  = NStr("en='Pay';ru='Оплатить'")
	 Or ConnectionParameters.OperationKind = NStr("en='Payment return';ru='Возврат платежа'")
	 Or ConnectionParameters.OperationKind = NStr("en='Cancel payment';ru='Отменить платеж'")
	 Or ConnectionParameters.OperationKind = NStr("en='Pre-authorize payment';ru='Преавторизовать платеж'")
	 Or ConnectionParameters.OperationKind = NStr("en='Finish preauthorization';ru='Завершить преавторизацию'")
	 Or ConnectionParameters.OperationKind = NStr("en='Cancel preauthorization';ru='Отменить преавторизацию'") Then
		AreaParameters = New Structure();

		// Parameters set by the user.
		AreaParameters.Insert("Bank"       , Parameters.SlipReceiptTemplateData[0].Value);
		AreaParameters.Insert("Company"    , Parameters.SlipReceiptTemplateData[1].Value);
		AreaParameters.Insert("City"       , Parameters.SlipReceiptTemplateData[2].Value); 
		AreaParameters.Insert("Address"    , Parameters.SlipReceiptTemplateData[3].Value);
		
		// Parameters supplied by the driver.
		AreaParameters.Insert("TID"        	, DriverObject.FIELDTERMINALNO);
		DateTime = Date("20"+DriverObject.FIELDTIMETRANSACTION);
		AreaParameters.Insert("Date"        , Format(DateTime, "DF=dd.MM.yy"));
		AreaParameters.Insert("Time"        , Format(DateTime, "DF=HH:mm"));
		If ConnectionParameters.OperationKind = NStr("en='Pay';ru='Оплатить'") Then
			AreaParameters.Insert("Operation", NStr("en='PAYMENT';ru='ОПЛАТА'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Payment return';ru='Возврат платежа'") Then
			AreaParameters.Insert("Operation", NStr("en='Return';ru='Возврат'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Cancel payment';ru='Отменить платеж'") Then
			AreaParameters.Insert("Operation", NStr("en='PAYMENT CANCEL';ru='PAYMENT CANCEL'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Pre-authorize payment';ru='Преавторизовать платеж'") Then
			AreaParameters.Insert("Operation", NStr("en='Preauthorization';ru='ПРЕАВТОРИЗАЦИЯ'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Finish preauthorization';ru='Завершить преавторизацию'") Then
			AreaParameters.Insert("Operation", NStr("en='END PREAUTHORIZATION';ru='ЗАВЕРШЕНИЕ ПРЕАВТОРИЗАЦИИ'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Cancel preauthorization';ru='Отменить преавторизацию'") Then
			AreaParameters.Insert("Operation", NStr("en='CANCEL PREAUTHORIZATION';ru='ОТМЕНА ПРЕАВТОРИЗАЦИИ'"));
		EndIf;
		AreaParameters.Insert("Amount",
		                          Format(?(IsBlankString(DriverObject.FIELDAMOUNT), 0, Number(DriverObject.FIELDAMOUNT)),
		                                 "ND=15; NFD=2; NS=2; NGS=' '; NG=3,0")
		                         + " "
		                         + "rub.");
		AreaParameters.Insert("CardNumber",	ConnectionParameters.CardNumber);
		AreaParameters.Insert("RRNCode",		ConnectionParameters.RefNo);
		AreaParameters.Insert("TransactionNo", 		DriverObject.FIELDTRANSACTIONNO);
		AreaParameters.Insert("AuthorizationCode", 		DriverObject.FIELDAUTHORIZATIONCODE);
		AreaParameters.Insert("ResponseCode", 				DriverObject.FIELDRESPONSECODE);
		AreaParameters.Insert("ResponseHostDescriptionFull", 	DriverObject.FIELDRESPONSETEXT);
		AreaParameters.Insert("FooterText", Parameters.SlipReceiptTemplateData[4].Value);
		
		If Mid(DriverObject.FIELDPEM, 2, 1) = "1" Then
			// PIN input flag
			PINAuthorization = True;
			
			AreaParameters.Insert("CardHolderName", 	DriverObject.FIELDCARDHOLDER);
			AreaParameters.Insert("Certificate", 		DriverObject.FIELDTRANSACTIONCERTIFICATE);
			AreaParameters.Insert("AID", 				DriverObject.FILDAID);
			AreaParameters.Insert("CardType", 			DriverObject.FIELDAPPLICATIONMARK);
			
		Else
			// Authorization without PIN input
			PINAuthorization = False;
			
			If Left(ConnectionParameters.CardNumber, 1) = "4" Then
				CardType = "Visa";
			ElsIf Left(ConnectionParameters.CardNumber, 1) = "5"
				OR Left(ConnectionParameters.CardNumber, 1) = "6" Then
				CardType = "Maestro/Master card";
			Else
				CardType = "";
			EndIf;
			AreaParameters.Insert("CardType", CardType);
			
		EndIf;
		
		SlipReceipt = EquipmentManagerClient.GetSlipReceipt(TemplateName, Parameters.SlipReceiptWidth, AreaParameters, PINAuthorization);
		
	ElsIf ConnectionParameters.OperationKind <> NStr("en='TotalsRevision';ru='СверкаИтогов'") Then
		Result = False;
		Output_Parameters.Add(999);
		Output_Parameters.Add("Unknown operation type: data processor does not support operation kind (%OperationKind%).
		                                   |Contact system administrator");
		Output_Parameters[1] = StrReplace(Output_Parameters[1],
		                                               "%OperationKind%",
		                                               ConnectionParameters.OperationKind);
	EndIf;

	If Result Then
		ChequeSlipCopies = "";
		For IndexOf = 1 To Parameters.SlipReceiptCopiesCount Do
			ChequeSlipCopies = ChequeSlipCopies + SlipReceipt + ?(IndexOf = Parameters.SlipReceiptCopies,
			                                            "",
			                                            Chars.LF + Char(Parameters.PartialCuttingSymbolCode) + Chars.LF);
		EndDo;
		SlipReceipt = ChequeSlipCopies;
	EndIf;

	Return Result;

EndFunction

// Set driver parameters.
//
Procedure SetDriverParameters(DriverObject, Parameters)

EndProcedure

// Function returns if slip receipt is printed on the terminal.
//
Function ReceiptsPrintOnTerminal(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	Output_Parameters.Clear();  
	Output_Parameters.Add(False);
	Return Result;
	
EndFunction

#EndRegion
