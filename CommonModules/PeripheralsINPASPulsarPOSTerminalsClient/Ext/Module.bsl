
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
	AddressAS         = Undefined;
	PortCA          = Undefined;
	ScriptX25       = Undefined;
	TimeoutACK      = Undefined;
	TimeoutAS       = Undefined;
	NumberNAK        = Undefined;
	PackageSize    = Undefined;
	OperationsTimeout = Undefined;

	AddressCC                = Undefined;
	PortKU                 = Undefined;
	TimeoutCC              = Undefined;
	TerminalIdentifier = Undefined;
	COMPortAE              = Undefined;
	ExchangeSpeedWithDO      = Undefined;
	AEDataSize         = Undefined;
	AEParity             = Undefined;
	AEStopBits             = Undefined;
	AEThreadManagement    = Undefined;

	SlipReceiptWidth          = Undefined;
	SlipReceiptCopiesCount = Undefined;
	SlipReceiptTemplateData    = Undefined;

	Parameters.Property("AddressAS",         AddressAS);
	Parameters.Property("PortCA",          PortCA);
	Parameters.Property("ScriptX25",       ScriptX25);
	Parameters.Property("TimeoutACK",      TimeoutACK);
	Parameters.Property("TimeoutAS",       TimeoutAS);
	Parameters.Property("NumberNAK",        NumberNAK);
	Parameters.Property("PackageSize",    PackageSize);
	Parameters.Property("OperationsTimeout", OperationsTimeout);

	Parameters.Property("AddressCC",                AddressCC);
	Parameters.Property("PortKU",                 PortKU);
	Parameters.Property("TimeoutCC",              TimeoutCC);
	Parameters.Property("TerminalIdentifier", TerminalIdentifier);
	Parameters.Property("COMPortAE",              COMPortAE);
	Parameters.Property("ExchangeSpeedWithDO",      ExchangeSpeedWithDO);
	Parameters.Property("AEDataSize",         AEDataSize);
	Parameters.Property("AEParity",             AEParity);
	Parameters.Property("AEStopBits",             AEStopBits);
	Parameters.Property("AEThreadManagement",    AEThreadManagement);

	Parameters.Property("SlipReceiptWidth",          SlipReceiptWidth);
	Parameters.Property("SlipReceiptCopiesCount", SlipReceiptCopiesCount);
	Parameters.Property("SlipReceiptTemplateData",    SlipReceiptTemplateData);

	If AddressAS                 = Undefined
	 Or PortCA                  = Undefined
	 Or ScriptX25               = Undefined
	 Or TimeoutACK              = Undefined
	 Or TimeoutAS               = Undefined
	 Or NumberNAK                = Undefined
	 Or PackageSize            = Undefined
	 Or OperationsTimeout         = Undefined
	 Or AddressCC                 = Undefined
	 Or PortKU                  = Undefined
	 Or TimeoutCC               = Undefined
	 Or TerminalIdentifier  = Undefined
	 Or COMPortAE               = Undefined
	 Or ExchangeSpeedWithDO       = Undefined
	 Or AEDataSize          = Undefined
	 Or AEParity              = Undefined
	 Or AEStopBits              = Undefined
	 Or AEThreadManagement     = Undefined
	 Or SlipReceiptWidth          = Undefined
	 Or SlipReceiptCopiesCount = Undefined
	 Or SlipReceiptTemplateData    = Undefined Then
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
	If Command = "AuthorizeSales" Then
		Amount      = InputParameters[0];
		CardNumber = InputParameters[1];

		Result = PayByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                    Amount, CardNumber, Output_Parameters);

	// Payment return
	ElsIf Command = "AuthorizeRefund" Then
		Amount          = InputParameters[0];
		CardNumber     = InputParameters[1];
		RefNo = ?(InputParameters.Count() > 2, InputParameters[2], "");
		ReceiptNumber      = ?(InputParameters.Count() > 3, InputParameters[3], "");
		Result = ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                          Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);
	  
	// Cancel payment
	ElsIf Command = "AuthorizeVoid" Then
		Amount          = InputParameters[0];
		RefNo = InputParameters[1];
		ReceiptNumber      = InputParameters[2];

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
	ValidityPeriod = "";
	If Not IsBlankString(CardNumber) Then
		SeparatorPosition = Find(CardNumber, "=");
		If SeparatorPosition > 0 Then
			CardCode     = Left(CardNumber, SeparatorPosition - 1);
			ValidityPeriod = Mid(CardNumber, SeparatorPosition + 1, 4);

			DriverObject.CardValidityPeriod = ValidityPeriod;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Invalid card number.';ru='Указан неверный номер карты.'"));

			Result = False;
		EndIf;
	EndIf;

	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.PayByPaymentCard(CardCode,
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
			ConnectionParameters.OriginalTransactionCode = DriverObject.OperationsAtTerminalID;

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
	ValidityPeriod = "";
	If Not IsBlankString(CardNumber) Then
		SeparatorPosition = Find(CardNumber, "=");
		If SeparatorPosition > 0 Then
			CardCode     = Left(CardNumber, SeparatorPosition - 1);
			ValidityPeriod = Mid(CardNumber, SeparatorPosition + 1, 4);

			DriverObject.CardValidityPeriod = ValidityPeriod;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Invalid card number.';ru='Указан неверный номер карты.'"));

			Result = False;
		EndIf;
	EndIf;

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
			ConnectionParameters.OriginalTransactionCode = DriverObject.OperationsAtTerminalID;

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

	ConnectionParameters.OperationKind = NStr("en='Cancel payment';ru='Отменить платеж'");

	SetDriverParameters(DriverObject, Parameters);

	If Result Then
		tempAmount = Amount * 100;

		Response = DriverObject.CancelPaymentByPaymentCard("",
		                                                       tempAmount,
		                                                       RefNo);
		If Not Response Then
			ConnectionParameters.OperationKind = NStr("en='Cancel';ru='Отменить'");
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			OperationCode = DriverObject.GetError(Output_Parameters[1]);

			Result = False;
		Else
			ConnectionParameters.OriginalTransactionCode = DriverObject.OperationsAtTerminalID;

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

	DriverObject.OperationsAtTerminalID = ConnectionParameters.OriginalTransactionCode;
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

	RefNo = Undefined;
	ReceiptNumber      = Undefined;

	ConnectionParameters.OperationKind = NStr("en='Pre-authorize payment';ru='Преавторизовать платеж'");

	SetDriverParameters(DriverObject, Parameters);

	// Transform card numbers into card code and validity term.
	CardCode = "";
	ValidityPeriod = "";
	If Not IsBlankString(CardNumber) Then
		SeparatorPosition = Find(CardNumber, "=");
		If SeparatorPosition > 0 Then
			CardCode     = Left(CardNumber, SeparatorPosition - 1);
			ValidityPeriod = Mid(CardNumber, SeparatorPosition + 1, 4);

			DriverObject.CardValidityPeriod = ValidityPeriod;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Invalid card number.';ru='Указан неверный номер карты.'"));

			Result = False;
		EndIf;
	EndIf;

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
			ConnectionParameters.OriginalTransactionCode = DriverObject.OperationsAtTerminalID;

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
	ValidityPeriod = "";
	If Not IsBlankString(CardNumber) Then
		SeparatorPosition = Find(CardNumber, "=");
		If SeparatorPosition > 0 Then
			CardCode     = Left(CardNumber, SeparatorPosition - 1);
			ValidityPeriod = Mid(CardNumber, SeparatorPosition + 1, 4);

			DriverObject.CardValidityPeriod = ValidityPeriod;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Invalid card number.';ru='Указан неверный номер карты.'"));

			Result = False;
		EndIf;
	EndIf;

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
			ConnectionParameters.OriginalTransactionCode = DriverObject.OperationsAtTerminalID;

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
	ValidityPeriod = "";
	If Not IsBlankString(CardNumber) Then
		SeparatorPosition = Find(CardNumber, "=");
		If SeparatorPosition > 0 Then
			CardCode     = Left(CardNumber, SeparatorPosition - 1);
			ValidityPeriod = Mid(CardNumber, SeparatorPosition + 1, 4);

			DriverObject.CardValidityPeriod = ValidityPeriod;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Invalid card number.';ru='Указан неверный номер карты.'"));

			Result = False;
		EndIf;
	EndIf;

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
			ConnectionParameters.OriginalTransactionCode = DriverObject.OperationsAtTerminalID;

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

	Document     = New TextDocument();
	Area      = Undefined;
	TemplateName    = "SlipReceiptINPAS";
	FieldValue = "";

	CodesOfCurrency = New Map();
	CodesOfCurrency.Insert("643", "RUR");
	CodesOfCurrency.Insert("840", "USD");
	CodesOfCurrency.Insert("978", "EUR");
	CodesOfCurrency.Insert("826", "GBP");
	CodesOfCurrency.Insert("036", "AUD");
	CodesOfCurrency.Insert("974", "BYR");
	CodesOfCurrency.Insert("208", "DKK");
	CodesOfCurrency.Insert("352", "ISK");
	CodesOfCurrency.Insert("398", "KZT");
	CodesOfCurrency.Insert("124", "CAD");
	CodesOfCurrency.Insert("578", "NOK");
	CodesOfCurrency.Insert("702", "SGD");
	CodesOfCurrency.Insert("792", "TRL");
	CodesOfCurrency.Insert("980", "UAH");
	CodesOfCurrency.Insert("752", "SEK");
	CodesOfCurrency.Insert("756", "CHF");
	CodesOfCurrency.Insert("392", "JPY");
	CodesOfCurrency.Insert("999", "BONUS");

	If ConnectionParameters.OperationKind = NStr("en='Pay';ru='Оплатить'")
	 Or ConnectionParameters.OperationKind = NStr("en='Payment return';ru='Возврат платежа'")
	 Or ConnectionParameters.OperationKind = NStr("en='Cancel payment';ru='Отменить платеж'")
	 Or ConnectionParameters.OperationKind = NStr("en='Pre-authorize payment';ru='Преавторизовать платеж'")
	 Or ConnectionParameters.OperationKind = NStr("en='Finish preauthorization';ru='Завершить преавторизацию'")
	 Or ConnectionParameters.OperationKind = NStr("en='Cancel preauthorization';ru='Отменить преавторизацию'") Then
		AreaParameters = New Structure();

		AreaParameters.Insert("Bank"       , Parameters.SlipReceiptTemplateData[0].Value);
		AreaParameters.Insert("Company", Parameters.SlipReceiptTemplateData[1].Value);
		AreaParameters.Insert("City"      , Parameters.SlipReceiptTemplateData[2].Value);
		AreaParameters.Insert("Address"      , Parameters.SlipReceiptTemplateData[3].Value);
		AreaParameters.Insert("Department"      , Parameters.SlipReceiptTemplateData[4].Value);
		AreaParameters.Insert("Cashier"     , Parameters.SlipReceiptTemplateData[5].Value);
		AreaParameters.Insert("TID"        , DriverObject.TerminalIdentifier);
		AreaParameters.Insert("MID"        , DriverObject.IDSeller);
		If ConnectionParameters.OperationKind = NStr("en='Pay';ru='Оплатить'") Then
			AreaParameters.Insert("Operation", NStr("en='PAYMENT FOR PRODUCTS';ru='ОПЛАТА ТОВАРА'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Payment return';ru='Возврат платежа'") Then
			AreaParameters.Insert("Operation", NStr("en='RETURN PRODUCTS';ru='ВОЗВРАТ ТОВАРА'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Cancel payment';ru='Отменить платеж'") Then
			AreaParameters.Insert("Operation", NStr("en='CANCEL PAYMENT FOR PRODUCTS';ru='ОТМЕНА ОПЛАТЫ ТОВАРА'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Pre-authorize payment';ru='Преавторизовать платеж'") Then
			AreaParameters.Insert("Operation", NStr("en='Preauthorization';ru='ПРЕАВТОРИЗАЦИЯ'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Finish preauthorization';ru='Завершить преавторизацию'") Then
			AreaParameters.Insert("Operation", NStr("en='END PREAUTHORIZATION';ru='ЗАВЕРШЕНИЕ ПРЕАВТОРИЗАЦИИ'"));
		ElsIf ConnectionParameters.OperationKind = NStr("en='Cancel preauthorization';ru='Отменить преавторизацию'") Then
			AreaParameters.Insert("Operation", NStr("en='CANCEL PREAUTHORIZATION';ru='ОТМЕНА ПРЕАВТОРИЗАЦИИ'"));
		EndIf;
		AreaParameters.Insert("Amount",
		                          Format(Number(DriverObject.Amount),
		                                 "ND=15; NFD=2; NS=2; NGS=' '; NG=3,0")
		                         + " "
		                         + CodesOfCurrency[DriverObject.CurrencyCode]);
		AreaParameters.Insert("Total", 
		                          Format(Number(DriverObject.Amount),
		                                 "ND=15; NFD=2; NS=2; NGS=' '; NG=3,0")
		                         + " "
		                         + CodesOfCurrency[DriverObject.CurrencyCode]);
		AreaParameters.Insert("CardName", DriverObject.CardType);
		AreaParameters.Insert("PIN", ?(DriverObject.MethodToInputPin = 0, "", "PIN"));
		AreaParameters.Insert("CardNumber",
		                          Left(DriverObject.CardNumber, 4) + " "
		                         + Mid(DriverObject.CardNumber, 5, 2) + "** **** "
		                         + Right(DriverObject.CardNumber, 4));
		AreaParameters.Insert("ValidityPeriod",
		                          Left(DriverObject.CardValidityPeriod,2) + "/" + Right(DriverObject.CardValidityPeriod,2));
		AreaParameters.Insert("AuthorizationCode", Format(DriverObject.AuthorizationCode, "NG=0"));
		AreaParameters.Insert("RRNCode", DriverObject.RRNCode);
		AreaParameters.Insert("HostResponseCode", DriverObject.HostResponseCode);
		AreaParameters.Insert("ResponseHostDescriptionFull", DriverObject.ResponseHostDescriptionFull);
		AreaParameters.Insert("Date", Format(Date(DriverObject.TimeOfOperationsAtTerminal), "DF=yy/MM/dd"));
		AreaParameters.Insert("Time", Format(Date(DriverObject.TimeOfOperationsAtTerminal), "DF=HH:mm:ss"));
		AreaParameters.Insert("ApplicationId", DriverObject.ApplicationId);
		AreaParameters.Insert("ApplicationName", DriverObject.ApplicationName);
		AreaParameters.Insert("TVR", DriverObject.TVR);
		AreaParameters.Insert("CardHolderName", DriverObject.CardHolderName);
		AreaParameters.Insert("FooterText", Parameters.SlipReceiptTemplateData[6].Value);
		
		SlipReceipt = EquipmentManagerClient.GetSlipReceipt(TemplateName, Parameters.SlipReceiptWidth, AreaParameters);
		
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

	// System parameters
	DriverObject.ServerAddressAuthorization   = Parameters.AddressAS;
	DriverObject.PortServerAuthorization    = Parameters.PortCA;
	DriverObject.ScriptX25                 = Parameters.ScriptX25;
	DriverObject.TimeoutACK                = Parameters.TimeoutACK;
	DriverObject.AuthorizationServerTimeout = Parameters.TimeoutAS;
	DriverObject.NumberNAK                  = Parameters.NumberNAK;
	DriverObject.PackageSize              = Parameters.PackageSize;
	DriverObject.OperationsTimeout           = Parameters.OperationsTimeout;

	DriverObject.AddressOfChannelManagement     = Parameters.AddressCC;
	DriverObject.ControlChannelPort      = Parameters.PortKU;
	DriverObject.ChannelManagementTimeout   = Parameters.TimeoutCC;
	DriverObject.COMPortAE                 = Parameters.COMPortAE;
	DriverObject.ExchangeSpeedWithDO         = Parameters.ExchangeSpeedWithDO;
	DriverObject.AEDataSize            = Parameters.AEDataSize;
	DriverObject.AEParity                = Parameters.AEParity;
	DriverObject.AEStopBits                = Parameters.AEStopBits;
	DriverObject.AEThreadManagement       = Parameters.AEThreadManagement;

	DriverObject.TerminalIdentifier    = Parameters.TerminalIdentifier;
	DriverObject.CurrencyCode                 = Parameters.CurrencyCode;
	DriverObject.TimeOfOperationsAtTerminal  = Format(EquipmentManagerClientOverridable.SessionDate(), "DF=YyyyMMddHHMMss");

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
