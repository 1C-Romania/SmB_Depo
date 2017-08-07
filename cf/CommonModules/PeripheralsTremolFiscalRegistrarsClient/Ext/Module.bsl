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
	ConnectionParameters.Insert("CashRegisterSerialNumber", "0");
	ConnectionParameters.Insert("DeviceID", "");

	Output_Parameters = New Array();

	Port                       = Undefined;
	Speed                      = Undefined;
	Timeout                    = Undefined;
	UserPassword               = Undefined;
	AdministratorPassword      = Undefined;
	CancelCheckDuringConnect   = Undefined;
	PaymentDescription1        = Undefined;
	PaymentDescription2        = Undefined;
	SectionNumber              = Undefined;
	PartialCuttingSymbolCode   = Undefined;
	VAT                        = Undefined;
	CompatibleVersions         = Undefined;

	Parameters.Property("Port"                      , Port);
	Parameters.Property("Speed"                     , Speed);
	Parameters.Property("Timeout"                   , Timeout);
	Parameters.Property("UserPassword"              , UserPassword);
	Parameters.Property("AdministratorPassword"     , AdministratorPassword);
	Parameters.Property("CancelCheckDuringConnect"  , CancelCheckDuringConnect);
	Parameters.Property("PaymentDescription1"       , PaymentDescription1);
	Parameters.Property("PaymentDescription2"       , PaymentDescription2);
	Parameters.Property("SectionNumber"             , SectionNumber);
	Parameters.Property("PartialCuttingSymbolCode"  , PartialCuttingSymbolCode);
	Parameters.Property("VAT"                       , VAT);

	If Port                           = Undefined
	 Or Speed                         = Undefined
	 Or Timeout                       = Undefined
	 Or UserPassword                  = Undefined
	 Or CancelCheckDuringConnect      = Undefined
	 Or SectionNumber                 = Undefined
	 Or VAT                           = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not configured.
			|For the correct work of the device it is necessary to specify the parameters of its work.
			|It can be done using the form ""Parameters Setting"" models of the peripherals in the form ""Equipment Connect Setup"".'; ru='Не настроены параметры устройства.
			|Для корректной работы устройства необходимо задать параметры его работы.
			|Сделать это можно при помощи формы ""Настройка параметров"" модели
			|подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));
		Result = False;
	EndIf;

	If Result Then
		Try
			DriverObject.Setup2(Port, Speed, 5, Timeout);
			Status = DriverObject.GetStatus(); 
			If Status.hasFiscalAndFactoryNum = 0 Then 
				Raise "";
			EndIf;
			
			If Parameters.CancelCheckDuringConnect Then
				If DriverObject.TerminateBon(0) <> 0 Then
					ErrorDescription = DriverObject.GetErrorString(DriverObject.errorCode,0);
				EndIf;
 			EndIf;
			Result = True;
		Except
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Device parameters are not configured.
				|For the correct work of the device it is necessary to specify the parameters of its work.
				|It can be done using the form ""Parameters Setting"" models of the peripherals in the form ""Equipment Connect Setup"".'; ru='Не настроены параметры устройства.
				|Для корректной работы устройства необходимо задать параметры его работы.
				|Сделать это можно при помощи формы ""Настройка параметров"" модели
				|подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));
			Result = False;
		EndTry;
		
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
	
	Return Result;
	
EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Cash session open
	If Command = "OpenDay" Or Command = "OpenSession" Then
		Result = OpenSession(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print report without blanking
	ElsIf Command = "PrintXReport" OR Command = "PrintReportWithoutBlanking" Then
		Result = PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print report with blanking
	ElsIf Command = "PrintZReport" OR Command = "PrintReportWithBlanking" Then
		Result = PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Print receipt
	ElsIf Command = "PrintReceipt" OR Command = "ReceiptPrint" Then
		ProductsAndServicesTable      = InputParameters[0];
		PaymentsTable                 = InputParameters[1];
		CommonParameters              = InputParameters[2];
		CheckTemplateParameters       = Undefined;

		Result = ReceiptPrint(DriverObject, Parameters, ConnectionParameters, ProductsAndServicesTable,
		                       PaymentsTable, InputParameters, CommonParameters, Output_Parameters, CheckTemplateParameters);

	// Print slip receipt
	ElsIf Command = "PrintText" OR Command = "PrintText"  Then
		TextString   = InputParameters[0];

		Result = PrintText(DriverObject, Parameters, ConnectionParameters,
		                         TextString, Output_Parameters);

	// Print deposit/withdrawal receipt.
	ElsIf Command = "Encash" OR Command = "Encashment" Then
		EncashmentType = InputParameters[0];
		Amount         = InputParameters[1];

		Result = Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters);

	// Test device
	ElsIf Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	
	// Open cash box
	ElsIf Command = "OpenCashDrawer" OR Command = "OpenCashDrawer" Then
		Result = OpenCashDrawer(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	
	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	ElsIf Command = "CancelFReceipt" OR Command = "CancelCheck" Then
		
		Result = CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	ElsIf Command = "OpenCheck" Then
		
		Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, InputParameters[0] = 1, InputParameters[1], Output_Parameters);

	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Presentation ""%Presentation%"" not supported by this driver.';
			|ru='Команда ""%Presentation%"" не поддерживается данным драйвером.'"));
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

	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(CurrentDate());

	Return Result;

EndFunction

// Prints a fiscal receipt.
Function ReceiptPrint(DriverObject, Parameters, ConnectionParameters, ProductsAndServicesTable,
						PaymentsTable, InputParameters, CommonParameters, Output_Parameters, CheckTemplateParameters)
	
	Return EquipmentManagerClientOverridable.ReceiptPrint(PeripheralsTremolFiscalRegistrarsClient,
		DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters);

EndFunction

// Prints slip receipt.
Function PrintText(DriverObject, Parameters, ConnectionParameters,
                       TextString, Output_Parameters)

	Result  = True;

	Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, False, False, Output_Parameters);

	If Result Then
		For LineNumber = 1 To StrLineCount(TextString) Do
			SelectedRow = StrGetLine(TextString, LineNumber);
			If Find(SelectedRow, Char(Parameters.PartialCuttingSymbolCode)) > 0 Then
				PaymentsTable = New Array();
				Result = CloseNotFiscalReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);
				Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, False, False, Output_Parameters);
			Else
				If NOT PrintNotFiscalLine(DriverObject, Parameters, ConnectionParameters,
				                                     SelectedRow, Output_Parameters) Then
					Break;
				EndIf;
			EndIf;
		EndDo;
	EndIf;

	If Result Then
		PaymentsTable = New Array();
		Result = CloseNotFiscalReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);
	EndIf;

	Return Result;

EndFunction

// Function opens a new receipt.
//
Function OpenReceipt(DriverObject, Parameters, ConnectionParameters, ReturnReceipt, FiscalReceipt, Output_Parameters) Export

	Result           = True;
	NumberOfSession  = 0;
	ReceiptNumber    = 0;
	ErrorDescription = "";
	UserPassword     = "";
	
	Parameters.Property("UserPassword", UserPassword);
	
	ErrorText = NStr("en='Error opening the receipt: ';
		|ru='Ошибка при открытии чека: '");
	
	If FiscalReceipt Then 
		// Open receipt
		If DriverObject.OpenFiscalBon(1, UserPassword, 0, 0) <> 0 Then
			ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
			Result = False;
		EndIf;
	Else 
		If DriverObject.OpenBon(1,UserPassword) <> 0 Then
			ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
			Result = False;
		EndIf;

	EndIf;

	If NOT Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
	Else
		Output_Parameters.Add(DriverObject.GetDailyReport().counter);
		Output_Parameters.Add(DriverObject.GetBonNumber());
		Output_Parameters.Add(0);
		Output_Parameters.Add(CurrentDate());
	EndIf;

	Return Result;

EndFunction

// Function prints a fiscal row.
//
Function PrintFiscalLine(DriverObject, Parameters, ConnectionParameters,
		Description, Count, Price, DiscountPercent, Amount,
		SectionNumber, VATRate, Output_Parameters) Export
	
	Result = True;
	ErrorDescription = "";
	
	CurrentString = Parameters.VAT.Get("Rate" + VATRate);
	If CurrentString = Undefined Then 
		Result = False;
		ErrorDescription = NStr("en='The tax group could not be determined. Check the hardware settings.';
			|ru='Не удалось определить налоговую группу. Проверьте настроки оборудования.'")
	Else
		TAXGroup = CurrentString.TAXGroup;
	EndIf;
	
	
	If DriverObject.SellFree(Description, TAXGroup, Price, Count, -DiscountPercent) <> 0 Then
		ErrorText = NStr("en='Error while printing receipt string: ';
			|ru='Ошибка при печати строки чека: '");
		ErrorDescription = ErrorDescription + ?(ErrorDescription="","",Chars.CR) + ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		Result = False;
	EndIf;
	
	If NOT Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
		
		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	EndIf;
	
	Return Result;
	
EndFunction

// Function prints a nonfiscal row.
//
Function PrintNotFiscalLine(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters)

	Result = True;
	ErrorDescription = "";
	
	
	If DriverObject.PrintText(TextString,0) <> 0 Then
		ErrorText = NStr("en='Error while printing text: ';
			|ru='Ошибка при печати текста: '");

		ErrorDescription = ErrorDescription + ?(ErrorDescription="","",Chars.CR) + ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		Result = False;
	EndIf;
	
	If NOT Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);

		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	EndIf;

	Return Result;
	
EndFunction

// Function closes an opened receipt.
//
Function CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters) Export

	Result           = True;
	ErrorDescription = "";
	MoneyBox         = False;
	Parameters.Property("MoneyBox", MoneyBox);
	GCPayment        = False;
	GCPaymentСode    = Undefined;
	If Parameters.Property("GCPaymentСode", GCPaymentСode) Then
		GCPayment =  ValueIsFilled(GCPaymentСode);
	EndIf;
	
	CashPaymentAmount     = 0;
	NonCashPaymentAmount1 = 0;
	NonCashPaymentAmount2 = 0;

	For PaymentIndex = 0 To PaymentsTable.Count() - 1 Do
		If PaymentsTable[PaymentIndex][0].Value = 0 Then
			CashPaymentAmount = CashPaymentAmount + PaymentsTable[PaymentIndex][1].Value;
		ElsIf PaymentsTable[PaymentIndex][0].Value = 1 Then
			NonCashPaymentAmount1 = NonCashPaymentAmount1 + PaymentsTable[PaymentIndex][1].Value;
		Else
			NonCashPaymentAmount2 = NonCashPaymentAmount2 + PaymentsTable[PaymentIndex][1].Value;
		EndIf;
	EndDo;

	NonCashAmount = NonCashPaymentAmount1 + ?(GCPayment,0,NonCashPaymentAmount2);
	
	If CashPaymentAmount > 0 Then
		If DriverObject.Payment(CashPaymentAmount,0,0) <> 0 Then
			ErrorText = Output_Parameters.Add(NStr("en='Error registering cash payment: ';
				|ru='Ошибка при регистрации наличного платежа: '"));
			ErrorDescription = ErrorDescription + ?(ErrorDescription="","",Chars.CR)
				+ ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
			Result = False;
		EndIf;
	EndIf;
	
	If NonCashAmount > 0 Then
		If DriverObject.Payment(NonCashAmount,4,0) <> 0 Then
			ErrorText = Output_Parameters.Add(NStr("en='Error registering non-cash payment: ';
				|ru='Ошибка при регистрации безналичного платежа : '"));
			ErrorDescription = ErrorDescription + ?(ErrorDescription="","",Chars.CR)
				+ ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
			Result = False;
		EndIf;
	EndIf;
	
	If GCPayment И (NonCashPaymentAmount2 > 0) Then
		If DriverObject.Payment(NonCashPaymentAmount2,GCPaymentСode,0) <> 0 Then
			ErrorText = Output_Parameters.Add(NStr("en='Error registering gift certificate payment: ';
				|ru='Ошибка при регистрации платежа подарочными сертификатами : '"));
			ErrorDescription = ErrorDescription + ?(ErrorDescription="","",Chars.CR)
				+ ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		EndIf;
	EndIf;
	
	If DriverObject.CloseFiscalBon() <> 0 Then
		ErrorText = Output_Parameters.Add(NStr("en='Error closing the receipt: ';
			|ru='Error closing the receipt: '"));
		ErrorDescription = ErrorDescription + ?(ErrorDescription="","",Chars.CR)
			+ ErrorText+DriverObject.GetErrorString(DriverObject.errorCode,0);
		Result = False;
	EndIf;
	
	If NOT (MoneyBox = Undefined) Then
		If MoneyBox Then
			If Result Then 
				If CashPaymentAmount > 0 Then
					If DriverObject.OpenTill() <> 0 Then
						ErrorText = Output_Parameters.Add(NStr("en='Error openint the money box: ';
							|ru='Ошибка при открытии денежного ящика: '"));
						ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
						Result = False;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
		
	If NOT Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
		
		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	EndIf;

	Return Result;

EndFunction

// Function closes an opened non fiscal receipt.
//
Function CloseNotFiscalReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters)

	Result = True;
	ErrorDescription = "";
		
	If DriverObject.CloseBon() <> 0 Then;
		ErrorText = Output_Parameters.Add(NStr("en='Error closing the receipt: ';
			|ru='Error closing the receipt: '"));
		ErrorDescription = ErrorDescription + ?(ErrorDescription="","",Chars.CR) + ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		Result = False;
	EndIf;
	
	If NOT Result Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
		
		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	EndIf;

	Return Result;

EndFunction

// Function cancels a previously opened receipt.
//
Function CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	
	If DriverObject.TerminateBon(0) <> 0 Then    // 1 - pay current receippts, 0 - clear
		ErrorText = Output_Parameters.Add(NStr("en='Error canceling the receipt: ';
			|ru='Ошиба при аннулировании чека: '"));
		ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
		Result = False;
	EndIf;
		
	Return Result;

EndFunction

Function Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters)

	Result = True;
	
	ErrorDescription = "";
	UserPassword = "";
	Parameters.Property("UserPassword",UserPassword);
	
	If DriverObject.OfficialSums(1,UserPassword,0,?(EncashmentType = 1, Amount, -Amount)) <> 0 Then
		ErrorText = Output_Parameters.Add(NStr("en='Error in depositing/withdrawing money: ';
			|ru='Ошибка при внесении/изъятии денег: '"));
		ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		Result = False;
	EndIf;

 	If NOT Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
		
		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	Else
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(0);
		Output_Parameters.Add(CurrentDate());
	EndIf;

	Return Result;

EndFunction

Function PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	ErrorDescription = "";
	DetailedReport = 1;
	
	If Result = DriverObject.ReportDaily(0,DetailedReport)<> 0 Then
		ErrorText = Output_Parameters.Add(NStr("en='Error printing Z-Report: ';
			|ru='Ошибка при печати Z-отчета: '"));
		ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		Result = False;
	EndIf;
	
	If NOT Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	Else
		
	EndIf;
	
	Return Result;
	
EndFunction

Function PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result           = True;
	ErrorDescription = "";
	DetailedReport   = 1;
	
	If Result = DriverObject.ReportDaily(1,DetailedReport)<> 0 Then
		ErrorText = Output_Parameters.Add(NStr("en='Error printing Z-Report: ';
			|ru='Ошибка при печати Z-отчета: '"));
		ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
		Result = False;
	EndIf;
	
	If NOT Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
		CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	Else
		
	EndIf;

	Return Result;

EndFunction

Function OpenCashDrawer(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	ErrorDescription = "";
	MoneyBox = False;
	Parameters.Property("MoneyBox",MoneyBox);
	
	If NOT (MoneyBox = Undefined) Then
		If MoneyBox Then
			If DriverObject.OpenTill() <> 0 Then
				ErrorText = Output_Parameters.Add(NStr("en='Error openint the money box: ';
					|ru='Ошибка при открытии денежного ящика: '"));
				ErrorDescription = ErrorText + DriverObject.GetErrorString(DriverObject.errorCode,0);
				Result = False;
			EndIf;
		EndIf;
	EndIf;
	
	If NOT Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorDescription);
	EndIf;

	Return Result;

EndFunction

Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	
	Return Result;

EndFunction

Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("ru='Установлен';en='Installed'"));
	Output_Parameters.Add(NStr("ru='Не определена';en='Undefined'"));

	Try
		Output_Parameters[1] = 2.05;
	Except
	EndTry;

	Return Result;

EndFunction

#EndRegion
