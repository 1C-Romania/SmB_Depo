
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	ConnectionParameters.Insert("DeviceID", "");

	Output_Parameters = New Array();

	// Check device parameters.
	Port                       = Undefined;
	Speed                   = Undefined;
	Timeout                    = Undefined;
	CRPassword                  = Undefined;
	SectionNumber                = Undefined;
	PartialCuttingSymbolCode = Undefined;

	Parameters.Property("Port"                      , Port);
	Parameters.Property("Speed"                  , Speed);
	Parameters.Property("Timeout"                   , Timeout);
	Parameters.Property("CRPassword"                 , CRPassword);
	Parameters.Property("SectionNumber"               , SectionNumber);
	Parameters.Property("PartialCuttingSymbolCode", PartialCuttingSymbolCode);

	If Port                       = Undefined
	 Or Speed                   = Undefined
	 Or Timeout                    = Undefined
	 Or CRPassword                  = Undefined
	 Or SectionNumber                = Undefined
	 Or PartialCuttingSymbolCode = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set."
"For the correct work of the device it is necessary to specify the parameters of its work."
"You can do it using the Parameters setting"
"form of the peripheral model in the Connection and equipment setting form.';ru='Не настроены параметры устройства."
"Для корректной работы устройства необходимо задать параметры его работы."
"Сделать это можно при помощи формы"
"""Настройка параметров"" модели подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));

		Result = False;
	EndIf;

	If Result Then
		ValueArray = New Array;
		ValueArray.Add(Parameters.Port);
		ValueArray.Add(Parameters.Speed);
		ValueArray.Add(Parameters.CRPassword);
		ValueArray.Add(Parameters.CRPassword);
		ValueArray.Add(Parameters.Timeout);

		If Not DriverObject.Connect(ValueArray, ConnectionParameters.DeviceID) Then
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1]);

			Result = False;
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function disconnects a device.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = False;

	// Required output
	Output_Parameters = New Array();

	If Not DriverObject.Disable(ConnectionParameters.DeviceID) Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);
	Else
		Result = True;
	EndIf;

	Return Result;

EndFunction

// The function receives, processes and redirects to execute a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;
	
	Output_Parameters = New Array();
	
	// PROCEDURES AND FUNCTIONS OVERALL FOR WORK WITH FISCAL REGISTERS
	
	// Cash session open
	If Command = "OpenDay" OR Command = "OpenSession" Then
		Result = OpenSession(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Print report without blanking
	ElsIf Command = "PrintXReport" OR Command = "PrintReportWithoutBlanking" Then
		Result = PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print report with blanking
	ElsIf Command = "PrintZReport" OR Command = "PrintReportWithBlanking" Then
		Result = PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print receipt
	ElsIf Command = "PrintReceipt" OR Command = "ReceiptPrint" Then
		Result = ReceiptPrint(DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters);

	// Print slip receipt
	ElsIf Command = "PrintText" OR Command = "PrintText"  Then
		TextString   = InputParameters[0];
		Result = PrintText(DriverObject, Parameters, ConnectionParameters,
		                         TextString, Output_Parameters);
	// Cancel an opened receipt
	ElsIf Command = "OpenCheck" OR Command = "OpenReceipt"  Then
		ReturnReceipt   = InputParameters[0];
		FiscalReceipt = InputParameters[1];
		Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, ReturnReceipt, FiscalReceipt, Output_Parameters);
		
	// Cancel an opened receipt
	ElsIf Command = "CancelCheck" OR Command = "CancelReceipt"  Then
		Result = CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Print deposit/withdrawal receipt.
	ElsIf Command = "Encash" OR Command = "Encashment" Then
		EncashmentType = InputParameters[0];
		Amount         = InputParameters[1];
		Result = Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters);

	ElsIf Command = "PrintBarCode" OR Command = "PrintBarcode" Then
		BarCodeType = InputParameters[0];
		Barcode     = InputParameters[1];
		Result = PrintBarcode(DriverObject, Parameters, ConnectionParameters, BarCodeType, Barcode, Output_Parameters);
		
	// Open cash box
	ElsIf Command = "OpenCashDrawer" OR Command = "OpenCashDrawer" Then
		Result = OpenCashDrawer(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Get the width of rows in characters.
	ElsIf Command = "GetLineLength" OR Command = "GetRowWidth" Then
		Result = GetRowWidth(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	
	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Test device
	ElsIf Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
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

// Function opens session.
Function OpenSession(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	// Filling of the output parameters.
	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());

	Return Result;

EndFunction

// Prints a fiscal receipt.
Function ReceiptPrint(DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters)
	       
	Return EquipmentManagerClientOverridable.ReceiptPrint(PeripheralsKKSCashRegistersClient,
		DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters);
		
EndFunction

// Prints text
Function PrintText(DriverObject, Parameters, ConnectionParameters,
                       TextString, Output_Parameters)

	Result  = True;

	// Open receipt
	Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, False, False, Output_Parameters);

	// Print receipt rows
	If Result Then
		For LineNumber = 1 To StrLineCount(TextString) Do
			SelectedRow = StrGetLine(TextString, LineNumber);
			If (Find(SelectedRow, Char(Parameters.PartialCuttingSymbolCode)) > 0)
				Or (Find(SelectedRow, "[segment]") > 0)
				Or (Find(SelectedRow, "[cut]") > 0) Then
				PaymentsTable = New Array();
				Result = CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);
				Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, False, False, Output_Parameters);
			Else
				If Not PrintNotFiscalLine(DriverObject, Parameters, ConnectionParameters,
				                                     SelectedRow, Output_Parameters) Then
					Break;
				EndIf;
			EndIf;
		EndDo;
	EndIf;

	// Close receipt
	If Result Then
		PaymentsTable = New Array();
		Result = CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);
	EndIf;

	Return Result;

EndFunction

// Function opens a new receipt.
//
Function OpenReceipt(DriverObject, Parameters, ConnectionParameters, ReturnReceipt, FiscalReceipt, Output_Parameters) Export

	Result  = True;
	NumberOfSession = 0;
	ReceiptNumber  = 0;

	// Open receipt
	Result = DriverObject.OpenReceipt(ConnectionParameters.DeviceID, FiscalReceipt, ReturnReceipt,
	                                      True, ReceiptNumber, NumberOfSession);
	If Not Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);
	Else
		// Filling of the output parameters.
		Output_Parameters.Clear();
		Output_Parameters.Add(NumberOfSession);
		Output_Parameters.Add(ReceiptNumber);
		Output_Parameters.Add(0); // Document No.
		Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
	EndIf;

	Return Result;

EndFunction

// Function prints a fiscal row.
//
Function PrintFiscalLine(DriverObject, Parameters, ConnectionParameters,
                                   Description, Count, Price, DiscountPercent, Amount,
                                   SectionNumber, VATRate, Output_Parameters) Export

	Result = True;

	Result = DriverObject.PrintFiscString(ConnectionParameters.DeviceID, Description, Count, Price,
	                                                Amount, SectionNumber, VATRate);
	
	If Not Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	EndIf;

	Return Result;

EndFunction

// Function prints a nonfiscal row.
//
Function PrintNotFiscalLine(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters) Export

	Result = True;

	Result = DriverObject.PrintNonFiscalLine(ConnectionParameters.DeviceID, TextString);
	If Not Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	EndIf;

	Return Result;

EndFunction

// Function closes a previously opened receipt.
//
Function CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters) Export

	Result = True;

	SumOfCashPayment     = 0;
	AmountOfNonCashPayment1 = 0;
	AmountOfNonCashPayment2 = 0;

	For paymentIndex = 0 To PaymentsTable.Count() - 1 Do
		If PaymentsTable[PaymentIndex][0].Value = 0 Then
			SumOfCashPayment = SumOfCashPayment + PaymentsTable[PaymentIndex][1].Value;
		ElsIf PaymentsTable[PaymentIndex][0].Value = 1 Then
			AmountOfNonCashPayment1 = AmountOfNonCashPayment1 + PaymentsTable[PaymentIndex][1].Value;
		Else
			AmountOfNonCashPayment2 = AmountOfNonCashPayment2 + PaymentsTable[PaymentIndex][1].Value;
		EndIf;
	EndDo;

	Result = DriverObject.CloseReceipt(ConnectionParameters.DeviceID,
	                                      SumOfCashPayment,
	                                      AmountOfNonCashPayment1,
	                                      AmountOfNonCashPayment2);
	If Not Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	EndIf;

	Return Result;

EndFunction

// Function cancels a previously opened receipt.
//
Function CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	DriverObject.CancelReceipt(ConnectionParameters.DeviceID);

	Return Result;

EndFunction

// Function deposits or withdraws amount in FR.
//
Function Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters)

	Result = True;

	Result = DriverObject.PrintDepositWithdrawReceipt(ConnectionParameters.DeviceID,
	                           ?(EncashmentType = 1, Amount, -Amount));
	If Not Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	Else
		// Filling of the output parameters.
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
	EndIf;

	Return Result;

EndFunction

// Function withdrawals without clearance.
//
Function PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Result = DriverObject.PrintReportWithoutBlanking(ConnectionParameters.DeviceID);
	If Not Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	Else
		// Filling of the output parameters.
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
	EndIf;

	Return Result;

EndFunction

// Function withdrawals with clearance.
//
Function PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Result = DriverObject.PrintReportWithBlanking(ConnectionParameters.DeviceID);
	If Not Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	Else
		// Filling of the output parameters.
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
	EndIf;

	Return Result;

EndFunction

// Function prints a barcode.
//
Function PrintBarcode(DriverObject, Parameters, ConnectionParameters, BarCodeType, Barcode, Output_Parameters)
	
	Result = True;
	
	TextString = NStr("en='Barcode:';ru='ШТРИХКОД:'") + Barcode; 
	Result = DriverObject.PrintNonFiscalLine(ConnectionParameters.DeviceID, TextString);
	If Not Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	EndIf;

	Return Result;

EndFunction

// Function opens a cash box.
//
Function OpenCashDrawer(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	
	Try
		Result = DriverObject.OpenCashDrawer(ConnectionParameters.DeviceID);
	Except
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The ""Open cash drawer"" command is not supported by this driver.';ru='Команда ""Открыть денежный ящик"" не поддерживается данным драйвером.'"));
		Return Result;
	EndTry;
	
	If Not Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);
	EndIf;

	Return Result;

EndFunction

// Function receives the width of row in characters.
//  
Function GetRowWidth(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	WidthRows = Undefined;
	Output_Parameters.Clear();  
	Output_Parameters.Add(WidthRows);
	Return Result;
	
EndFunction

// Function withdrawals without clearance.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	TestResult = "";

	ValueArray = New Array;
	ValueArray.Add(Parameters.Port);
	ValueArray.Add(Parameters.Speed);
	ValueArray.Add(Parameters.CRPassword);
	ValueArray.Add(Parameters.CRPassword);
	ValueArray.Add(Parameters.Timeout);

	Result = DriverObject.DeviceTest(ValueArray, TestResult);

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

#EndRegion
