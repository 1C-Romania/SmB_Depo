
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	Title = NStr("en='Equipment:'") + Chars.NBSp + String(ID);

	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;

	ListSlipReceiptWidth = Items.SlipReceiptWidth.ChoiceList;
	ListSlipReceiptWidth.Add(24,  NStr("en='24 ch.'"));
	ListSlipReceiptWidth.Add(32,  NStr("en='32 ch.'"));
	ListSlipReceiptWidth.Add(36,  NStr("en='36 ch.'"));
	ListSlipReceiptWidth.Add(40,  NStr("en='40 ch.'")); 
	ListSlipReceiptWidth.Add(48,  NStr("en='48 ch.'"));

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
	ParametersNewValue.Insert("SlipReceiptWidth"            , SlipReceiptWidth);
	ParametersNewValue.Insert("SlipReceiptCopiesCount"   , SlipReceiptCopiesCount);
	ParametersNewValue.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	ParametersNewValue.Insert("SlipReceiptTemplateData"      , SlipReceiptTemplateData);
	
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
		MessageText = NStr("en = 'Test successfully performed.'");
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
		                           AND Output_Parameters.Count() >= 2,
		                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1],
		                           "");


		MessageText = NStr("en = 'Test failed.%Linefeed% %AdditionalDetails%'");
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
	Text = NStr("en = 'Driver is set using vendor''s distribution.'");
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
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
		Version  = NStr("en='Not defined'");
	EndIf;

	Items.Driver.TextColor = ?(Driver = NStr("en='Not set'"), ErrorColor, TextColor);
	Items.Version.TextColor  = ?(Version  = NStr("en='Not defined'"), ErrorColor, TextColor);

EndProcedure

Procedure ReadTemplateData()

	If SlipReceiptTemplateData.Count() = 0 Then
		SlipReceiptTemplateData.Add("JSC ""Alpha Bank"""	, "Bank");
		SlipReceiptTemplateData.Add(""       				, "Company");
		SlipReceiptTemplateData.Add(""       				, "City");
		SlipReceiptTemplateData.Add(""       				, "Address");
		SlipReceiptTemplateData.Add("THANKYOU"				, "FooterText");
	EndIf;

	Bank         = SlipReceiptTemplateData[0].Value;
	Company  = SlipReceiptTemplateData[1].Value;
	City        = SlipReceiptTemplateData[2].Value;
	Address        = SlipReceiptTemplateData[3].Value;
	FooterText = SlipReceiptTemplateData[4].Value;

EndProcedure

Procedure WriteTemplateData()

	SlipReceiptTemplateData[0].Value = Bank;
	SlipReceiptTemplateData[1].Value = Company;
	SlipReceiptTemplateData[2].Value = City;
	SlipReceiptTemplateData[3].Value = Address;
	SlipReceiptTemplateData[4].Value = FooterText;

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
