
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ID", ID);
	Title = NStr("en='Equipment:'") + Chars.NBSp  + String(ID);
	
	tempProductsBase = Undefined;
	
	Parameters.EquipmentParameters.Property("ProductsBase", tempProductsBase);
	
	ProductsBase = ?(tempProductsBase  = Undefined, "", tempProductsBase);
	
	Driver = NStr("en='Not necessary'");
	Version  = NStr("en='Not defined'");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ProductBaseStartChoiceEnd(SelectedFiles, AdditionalParameters) Export
	
	If TypeOf(SelectedFiles) = Type("Array") AND SelectedFiles.Count() > 0 Then
		ProductsBase = SelectedFiles[0];
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductBaseStartChoiceExtantionAvailabilityEnd(Result, AdditionalParameters) Export
	
	If Result Then
		Dialog = New FileDialog(FileDialogMode.Open);
		Dialog.Multiselect = False;
		Dialog.FullFileName = ProductsBase;
		Notification = New NotifyDescription("ProductBaseStartChoiceEnd", ThisObject);
		Dialog.Show(Notification);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsBaseStartChoice(Item, ChoiceData, StandardProcessing)
	
	Notification = New NotifyDescription("ProductBaseStartChoiceExtantionAvailabilityEnd", ThisObject);
	EquipmentManagerClient.CheckFileOperationsExtensionAvailability(Notification);
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ErrorText = "";
	Result = True;
	
	If IsBlankString(ProductsBase) Then
		Result = False;
		ErrorText = NStr("en='Products base file is not specified.'");
	EndIf;
	
	If Result Then
		
		ParametersNewValue = New Structure;
		ParametersNewValue.Insert("ProductsBase", ProductsBase);
		
		Result = New Structure;
		Result.Insert("ID", ID);
		Result.Insert("EquipmentParameters", ParametersNewValue);
		
		Close(Result);
		
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en= 'When verifying the following errors have been detected:'") + ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult = Undefined;

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("ProductsBase", ProductsBase);

	Result = EquipmentManagerClient.RunAdditionalCommand("DeviceTest",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
	                           AND Output_Parameters.Count() >= 2,
	                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1],
	                           "");
	If Result Then
		MessageText = NStr("en = 'Test completed successfully. %AdditionalDetails%%Linefeed%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
		                                                                  "",
		                                                                  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
		                                                                           "",
		                                                                           AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	Else
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
