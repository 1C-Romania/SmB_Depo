
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	Title = NStr("en='Equipment:';ru='Оборудование:'") + Chars.NBSp + String(ID);
	
	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;
	
	ListCOMPortDF = Items.COMPortAE.ChoiceList;
	For IndexOf = 1 To 32 Do
		ListCOMPortDF.Add(IndexOf, "COM" + String(IndexOf));
	EndDo;
	
	ListExchangeDFSpeed = Items.ExchangeSpeedWithDO.ChoiceList;
	ListExchangeDFSpeed.Add(9600,     "9600");
	ListExchangeDFSpeed.Add(19200,   "19200");
	ListExchangeDFSpeed.Add(38400,   "38400");
	ListExchangeDFSpeed.Add(57600,   "57600");
	ListExchangeDFSpeed.Add(115200, "115200");
	
	ListDFDataSize = Items.AEDataSize.ChoiceList;
	ListDFDataSize.Add(4, "4");
	ListDFDataSize.Add(5, "5");
	ListDFDataSize.Add(6, "6");
	ListDFDataSize.Add(7, "7");
	ListDFDataSize.Add(8, "8");
	
	ListDFParity = Items.AEParity.ChoiceList;
	ListDFParity.Add(0, "None");
	ListDFParity.Add(1, "Odd");
	ListDFParity.Add(2, "Even");
	ListDFParity.Add(3, "Mark");
	ListDFParity.Add(4, "Space");
	
	ListDFStopBits = Items.AEStopBits.ChoiceList;
	ListDFStopBits.Add(0, NStr("en='1 stop-bit';ru='1 стоп-бит'"));
	ListDFStopBits.Add(1, NStr("en='1,5 stop bits';ru='1,5 стоп-бита'"));
	ListDFStopBits.Add(2, NStr("en='2 stop-bits';ru='2 стоп-бита'"));
	
	ListDFThreadManagement = Items.AEThreadManagement.ChoiceList;
	ListDFThreadManagement.Add(0, "Xon/Xoff");
	ListDFThreadManagement.Add(1, "Hardware");
	ListDFThreadManagement.Add(2, "None");
	
	ListSlipReceiptWidth = Items.SlipReceiptWidth.ChoiceList;
	ListSlipReceiptWidth.Add(24,  NStr("en='24 ch.';ru='24 сим.'"));
	ListSlipReceiptWidth.Add(32,  NStr("en='32 ch.';ru='32 сим.'"));
	ListSlipReceiptWidth.Add(36,  NStr("en='36 ch.';ru='36 сим.'"));
	ListSlipReceiptWidth.Add(40,  NStr("en='40 ch.';ru='40 сим.'"));
	ListSlipReceiptWidth.Add(48,  NStr("en='48 ch.';ru='48 сим.'"));
	
	// Reading values from parameters.
	
	tempAddressAS         = Undefined;
	tempPortAS          = Undefined;
	TempScriptX25       = Undefined;
	TempTimeoutACS      = Undefined;
	tempTimeoutAS       = Undefined;
	TempNumberNAK        = Undefined;
	tempPackageSize    = Undefined;
	tempOperationTimeout = Undefined;

	Parameters.EquipmentParameters.Property("AddressAS",         tempAddressAS);
	Parameters.EquipmentParameters.Property("PortCA",          tempPortAS);
	Parameters.EquipmentParameters.Property("ScriptX25",       TempScriptX25);
	Parameters.EquipmentParameters.Property("TimeoutACK",      TempTimeoutACS);
	Parameters.EquipmentParameters.Property("TimeoutAS",       tempTimeoutAS);
	Parameters.EquipmentParameters.Property("NumberNAK",        TempNumberNAK);
	Parameters.EquipmentParameters.Property("PackageSize",    tempPackageSize);
	Parameters.EquipmentParameters.Property("OperationsTimeout", tempOperationTimeout);

	AddressAS         = ?(tempAddressAS          = Undefined, "127.0.0.1", tempAddressAS);
	PortCA          = ?(tempPortAS           = Undefined,           0, tempPortAS);
	ScriptX25       = ?(TempScriptX25        = Undefined,          "", TempScriptX25);
	TimeoutACK      = ?(TempTimeoutACS       = Undefined,        5000, TempTimeoutACS);
	TimeoutAS       = ?(tempTimeoutAS        = Undefined,       45000, tempTimeoutAS);
	NumberNAK        = ?(TempNumberNAK         = Undefined,           3, TempNumberNAK);
	PackageSize    = ?(tempPackageSize     = Undefined,        1024, tempPackageSize);
	OperationsTimeout = ?(tempOperationTimeout  = Undefined,          90, tempOperationTimeout);

	TimeAddressCE                = Undefined;
	tempPortCD                 = Undefined;
	tempTimeoutCE              = Undefined;
	TempTerminalIdentifier = Undefined;
	tempCOMPortWF              = Undefined;
	TempExchangeSpeedWithDF      = Undefined;
	tempDataSizeBEFORE         = Undefined;
	TempParityWF             = Undefined;
	TempStopBitsWF             = Undefined;
	TempFlowControlWF    = Undefined;

	Parameters.EquipmentParameters.Property("AddressCC",                TimeAddressCE);
	Parameters.EquipmentParameters.Property("PortKU",                 tempPortCD);
	Parameters.EquipmentParameters.Property("TimeoutCC",              tempTimeoutCE);
	Parameters.EquipmentParameters.Property("TerminalIdentifier", TempTerminalIdentifier);
	Parameters.EquipmentParameters.Property("COMPortAE",              tempCOMPortWF);
	Parameters.EquipmentParameters.Property("ExchangeSpeedWithDO",      TempExchangeSpeedWithDF);
	Parameters.EquipmentParameters.Property("AEDataSize",         tempDataSizeBEFORE);
	Parameters.EquipmentParameters.Property("AEParity",             TempParityWF);
	Parameters.EquipmentParameters.Property("AEStopBits",             TempStopBitsWF);
	Parameters.EquipmentParameters.Property("AEThreadManagement",    TempFlowControlWF);

	AddressCC                = ?(TimeAddressCE                = Undefined, "127.0.0.1", TimeAddressCE);
	PortKU                 = ?(tempPortCD                 = Undefined,           0, tempPortCD);
	TimeoutCC              = ?(tempTimeoutCE              = Undefined,       60000, tempTimeoutCE);
	TerminalIdentifier = ?(TempTerminalIdentifier = Undefined,          "", TempTerminalIdentifier);
	COMPortAE              = ?(tempCOMPortWF              = Undefined,           1, tempCOMPortWF);
	ExchangeSpeedWithDO      = ?(TempExchangeSpeedWithDF      = Undefined,       19200, TempExchangeSpeedWithDF);
	AEDataSize         = ?(tempDataSizeBEFORE         = Undefined,           8, tempDataSizeBEFORE);
	AEParity             = ?(TempParityWF             = Undefined,           0, TempParityWF);
	AEStopBits             = ?(TempStopBitsWF             = Undefined,           0, TempStopBitsWF);
	AEThreadManagement    = ?(TempFlowControlWF    = Undefined,           2, TempFlowControlWF);

	tempCurrencyCode                  = Undefined;
	tempSlipReceiptWidth             = Undefined;
	TempSlipReceiptCopiesCount    = Undefined;
	tempPartialCuttingSymbolCode = Undefined;
	tempSlipReceiptTemplateData       = Undefined;

	Parameters.EquipmentParameters.Property("CurrencyCode"                 , tempCurrencyCode);
	Parameters.EquipmentParameters.Property("SlipReceiptWidth"            , tempSlipReceiptWidth);
	Parameters.EquipmentParameters.Property("SlipReceiptCopiesCount"   , TempSlipReceiptCopiesCount);
	Parameters.EquipmentParameters.Property("PartialCuttingSymbolCode", tempPartialCuttingSymbolCode);
	Parameters.EquipmentParameters.Property("SlipReceiptTemplateData"      , tempSlipReceiptTemplateData);

	CurrencyCode                  = ?(tempCurrencyCode                  = Undefined, "643", tempCurrencyCode);
	SlipReceiptWidth             = ?(tempSlipReceiptWidth             = Undefined,    36, tempSlipReceiptWidth);
	SlipReceiptCopiesCount    = ?(TempSlipReceiptCopiesCount    = Undefined,     2, TempSlipReceiptCopiesCount);
	PartialCuttingSymbolCode = ?(tempPartialCuttingSymbolCode = Undefined,    22, tempPartialCuttingSymbolCode);
	SlipReceiptTemplateData       = tempSlipReceiptTemplateData;

	ReadTemplateData();

EndProcedure

// Procedure - handler of the Before opening event form.
//
// Parameters:
//  Cancel                - <Boolean>
//                       - Shows that the form opening is denied. If
//                         you set the True
//                         value for this parameter in the body of the procedure-processor, the form will not be opened.
//                         Default value: False.
//
//  StandardProcessing - <Boolean>
//                       - A flag of standard (system) event handler is passed to this parameter. If
//                         you set the False
//                         value for this parameter in
//                         the body of the procedure-processor, there will be no standard processing of the event. If you
//                         reject the standard processing, form opening will not be canceled.
//                         Default value: True.
//
&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

// The procedure is the Click
// event handler of the OK button in the MainFormActions command bar.
//
// Parameters:
//  Button - <CommandBarButton>
//         - Button associated with this event (OK button).
//
&AtClient
Procedure WriteAndCloseExecute()

	WriteTemplateData();
	
	ParametersNewValue = New Structure;
	
	ParametersNewValue.Insert("AddressAS"                , AddressAS);
	ParametersNewValue.Insert("PortCA"                 , PortCA);
	ParametersNewValue.Insert("ScriptX25"              , ScriptX25);
	ParametersNewValue.Insert("TimeoutACK"             , TimeoutACK);
	ParametersNewValue.Insert("TimeoutAS"              , TimeoutAS);
	ParametersNewValue.Insert("NumberNAK"               , NumberNAK);
	ParametersNewValue.Insert("PackageSize"           , PackageSize);
	ParametersNewValue.Insert("OperationsTimeout"        , OperationsTimeout);

	ParametersNewValue.Insert("AddressCC"                , AddressCC);
	ParametersNewValue.Insert("PortKU"                 , PortKU);
	ParametersNewValue.Insert("TimeoutCC"              , TimeoutCC);
	ParametersNewValue.Insert("TerminalIdentifier" , TerminalIdentifier);
	ParametersNewValue.Insert("COMPortAE"              , COMPortAE);
	ParametersNewValue.Insert("ExchangeSpeedWithDO"      , ExchangeSpeedWithDO);
	ParametersNewValue.Insert("AEDataSize"         , AEDataSize);
	ParametersNewValue.Insert("AEParity"             , AEParity);
	ParametersNewValue.Insert("AEStopBits"             , AEStopBits);
	ParametersNewValue.Insert("AEThreadManagement"    , AEThreadManagement);
	
	ParametersNewValue.Insert("CurrencyCode"                  , CurrencyCode);
	ParametersNewValue.Insert("SlipReceiptWidth"             , SlipReceiptWidth);
	ParametersNewValue.Insert("SlipReceiptCopiesCount"    , SlipReceiptCopiesCount);
	ParametersNewValue.Insert("PartialCuttingSymbolCode" , PartialCuttingSymbolCode);
	ParametersNewValue.Insert("SlipReceiptTemplateData"       , SlipReceiptTemplateData);

	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult = Undefined;

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("AddressAS"                   , AddressAS);
	tempDeviceParameters.Insert("PortCA"                    , PortCA);
	tempDeviceParameters.Insert("ScriptX25"                 , ScriptX25);
	tempDeviceParameters.Insert("TimeoutACK"                , TimeoutACK);
	tempDeviceParameters.Insert("TimeoutAS"                 , TimeoutAS);
	tempDeviceParameters.Insert("NumberNAK"                  , NumberNAK);
	tempDeviceParameters.Insert("PackageSize"              , PackageSize);
	tempDeviceParameters.Insert("OperationsTimeout"           , OperationsTimeout);

	tempDeviceParameters.Insert("AddressCC"                   , AddressCC);
	tempDeviceParameters.Insert("PortKU"                    , PortKU);
	tempDeviceParameters.Insert("TimeoutCC"                 , TimeoutCC);
	tempDeviceParameters.Insert("TerminalIdentifier"    , TerminalIdentifier);
	tempDeviceParameters.Insert("COMPortAE"                 , COMPortAE);
	tempDeviceParameters.Insert("ExchangeSpeedWithDO"         , ExchangeSpeedWithDO);
	tempDeviceParameters.Insert("AEDataSize"            , AEDataSize);
	tempDeviceParameters.Insert("AEParity"                , AEParity);
	tempDeviceParameters.Insert("AEStopBits"                , AEStopBits);
	tempDeviceParameters.Insert("AEThreadManagement"       , AEThreadManagement);

	tempDeviceParameters.Insert("CurrencyCode"                 , CurrencyCode);
	tempDeviceParameters.Insert("SlipReceiptWidth"            , SlipReceiptWidth);
	tempDeviceParameters.Insert("SlipReceiptCopiesCount"   , SlipReceiptCopiesCount);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("SlipReceiptTemplateData"      , SlipReceiptTemplateData);

	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	If Result Then
		MessageText = NStr("en='Test successfully performed.';ru='Тест успешно выполнен.'");
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
		                           AND Output_Parameters.Count() >= 2,
		                           NStr("en='Additional description:';ru='Дополнительное описание:'") + " " + Output_Parameters[1],
		                           "");


		MessageText = NStr("en='Test failed.%Linefeed% %AdditionalDetails%';ru='Тест не пройден.%ПереводСтроки%%ДополнительноеОписание%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
		                                                                  "",
		                                                                  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
		                                                                           "",
		                                                                           AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;

EndProcedure

&AtClient
Procedure SetupDriver(Command)
	
	ClearMessages();
	Text = NStr("en=""Driver is set using vendor's distribution."";ru=""Driver is set using vendor's distribution.""");
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("AddressAS"                   , AddressAS);
	tempDeviceParameters.Insert("PortCA"                    , PortCA);
	tempDeviceParameters.Insert("ScriptX25"                 , ScriptX25);
	tempDeviceParameters.Insert("TimeoutACK"                , TimeoutACK);
	tempDeviceParameters.Insert("TimeoutAS"                 , TimeoutAS);
	tempDeviceParameters.Insert("NumberNAK"                  , NumberNAK);
	tempDeviceParameters.Insert("PackageSize"              , PackageSize);
	tempDeviceParameters.Insert("OperationsTimeout"           , OperationsTimeout);

	tempDeviceParameters.Insert("AddressCC"                   , AddressCC);
	tempDeviceParameters.Insert("PortKU"                    , PortKU);
	tempDeviceParameters.Insert("TimeoutCC"                 , TimeoutCC);
	tempDeviceParameters.Insert("TerminalIdentifier"    , TerminalIdentifier);
	tempDeviceParameters.Insert("COMPortAE"                 , COMPortAE);
	tempDeviceParameters.Insert("ExchangeSpeedWithDO"         , ExchangeSpeedWithDO);
	tempDeviceParameters.Insert("AEDataSize"            , AEDataSize);
	tempDeviceParameters.Insert("AEParity"                , AEParity);
	tempDeviceParameters.Insert("AEStopBits"                , AEStopBits);
	tempDeviceParameters.Insert("AEThreadManagement"       , AEThreadManagement);

	tempDeviceParameters.Insert("CurrencyCode"                 , CurrencyCode);
	tempDeviceParameters.Insert("SlipReceiptWidth"            , SlipReceiptWidth);
	tempDeviceParameters.Insert("SlipReceiptCopiesCount"   , SlipReceiptCopiesCount);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("SlipReceiptTemplateData"      , SlipReceiptTemplateData);

	If EquipmentManagerClient.RunAdditionalCommand("GetDriverVersion",
	                                                               InputParameters,
	                                                               Output_Parameters,
	                                                               ID,
	                                                               tempDeviceParameters) Then
		Driver = Output_Parameters[0];
		Version  = Output_Parameters[1];
	Else
		Driver = Output_Parameters[2];
		Version  = NStr("en='Not defined';ru='Не определена'");
	EndIf;

	Items.Driver.TextColor = ?(Driver = NStr("en='Not set';ru='Не установлен'"), ErrorColor, TextColor);
	Items.Version.TextColor  = ?(Version  = NStr("en='Not defined';ru='Не определена'"), ErrorColor, TextColor);

EndProcedure

Procedure ReadTemplateData()

	If SlipReceiptTemplateData.Count() = 0 Then
		SlipReceiptTemplateData.Add("Bank"   , "Bank");
		SlipReceiptTemplateData.Add(""       , "Company");
		SlipReceiptTemplateData.Add(""       , "City");
		SlipReceiptTemplateData.Add(""       , "Address");
		SlipReceiptTemplateData.Add("DEPARTMENT1" , "Department");
		SlipReceiptTemplateData.Add("CASHIER" , "Cashier");
		SlipReceiptTemplateData.Add("THANKYOU", "FooterText");
	EndIf;

	Bank         = SlipReceiptTemplateData[0].Value;
	Company  = SlipReceiptTemplateData[1].Value;
	City        = SlipReceiptTemplateData[2].Value;
	Address        = SlipReceiptTemplateData[3].Value;
	Department        = SlipReceiptTemplateData[4].Value;
	Cashier       = SlipReceiptTemplateData[5].Value;
	FooterText = SlipReceiptTemplateData[6].Value;

EndProcedure

Procedure WriteTemplateData()

	SlipReceiptTemplateData[0].Value = Bank;
	SlipReceiptTemplateData[1].Value = Company;
	SlipReceiptTemplateData[2].Value = City;
	SlipReceiptTemplateData[3].Value = Address;
	SlipReceiptTemplateData[4].Value = Department;
	SlipReceiptTemplateData[5].Value = Cashier;
	SlipReceiptTemplateData[6].Value = FooterText;

EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
