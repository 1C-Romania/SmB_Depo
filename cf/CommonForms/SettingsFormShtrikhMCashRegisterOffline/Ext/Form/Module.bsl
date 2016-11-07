
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ID", ID);
	
	Title = NStr("en='Equipment:';ru='Оборудование:'") + Chars.NBSp  + String(ID);
	
	tempProductsBase  = Undefined;
	tempReportFile    = Undefined;
	tempExportFlag   = Undefined;
	Parameters.EquipmentParameters.Property("ProductsBase", tempProductsBase);
	Parameters.EquipmentParameters.Property("ReportFile", tempReportFile);
	Parameters.EquipmentParameters.Property("ExportFlag",tempExportFlag);

	ProductsBase = ?(tempProductsBase = Undefined, "", tempProductsBase);
	ReportFile   = ?(tempReportFile   = Undefined, "", tempReportFile);
	ExportFlag = ?(tempExportFlag = Undefined, "", tempExportFlag);
	
	Driver = NStr("en='Not necessary';ru='Не требуется'");
	Version  = NStr("en='Not defined';ru='Не определена'");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ProductBaseStartChoiceEnd(SelectedFiles, Parameters) Export
	
	If TypeOf(SelectedFiles) = Type("Array") AND SelectedFiles.Count() > 0 Then
		ProductsBase = SelectedFiles[0];
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsBaseStartChoice(Item, ChoiceData, StandardProcessing)
	
	Notification = New NotifyDescription("ProductBaseStartChoiceEnd", ThisObject);
	EquipmentManagerClient.StartFileSelection(Notification, ProductsBase);
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ExportFlagStartChoiceEnd(SelectedFiles, Parameters) Export
	
	If TypeOf(SelectedFiles) = Type("Array") AND SelectedFiles.Count() > 0 Then
		ExportFlag = SelectedFiles[0];
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportFlagStartChoice(Item, ChoiceData, StandardProcessing)
	
	Notification = New NotifyDescription("ExportFlagStartChoiceEnd", ThisObject);
	EquipmentManagerClient.StartFileSelection(Notification, ExportFlag);
	StandardProcessing = False;

EndProcedure

&AtClient
Procedure ReportFileStartChoiceEnd(SelectedFiles, Parameters) Export
	
	If TypeOf(SelectedFiles) = Type("Array") AND SelectedFiles.Count() > 0 Then
		ReportFile = SelectedFiles[0];
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	Notification = New NotifyDescription("ReportFileStartChoiceEnd", ThisObject);
	EquipmentManagerClient.StartFileSelection(Notification, ExportFlag);
	StandardProcessing = False;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ErrorText = "";
	CommonErrorText = "";

	If IsBlankString(ProductsBase) Then
		Result = False;
		CommonErrorText = NStr("en='Products base file is not specified.';ru='Файл базы товаров не указан.'");
	EndIf;
	
	If IsBlankString(ReportFile) Then
		Result = False;
		CommonErrorText = CommonErrorText + ?(IsBlankString(CommonErrorText), "", Chars.LF); 
		CommonErrorText = CommonErrorText + NStr("en='Report file is not specified.';ru='Файл отчета не указан.'") 
	EndIf;
	
	If IsBlankString(CommonErrorText) Then
		
		ParametersNewValue = New Structure;
		ParametersNewValue.Insert("ProductsBase", ProductsBase);
		ParametersNewValue.Insert("ReportFile", ReportFile);
		ParametersNewValue.Insert("ExportFlag", ExportFlag);
		
		Result = New Structure;
		Result.Insert("ID", ID);
		Result.Insert("EquipmentParameters", ParametersNewValue);
		
		Close(Result);
		
	Else
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='When verifying the following errors have been detected:';ru='При проверке были обнаружены следующие ошибки:'")+ Chars.LF + CommonErrorText);
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
	tempDeviceParameters.Insert("ReportFile", 	ReportFile);
	tempDeviceParameters.Insert("ExportFlag",ExportFlag);

	Result = EquipmentManagerClient.RunAdditionalCommand("DeviceTest",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
	                           AND Output_Parameters.Count() >= 2,
	                           NStr("en='Additional description:';ru='Дополнительное описание:'") + " " + Output_Parameters[1],
	                           "");
	If Result Then
		MessageText = NStr("en='Test completed successfully. %AdditionalDetails%%Linefeed%';ru='Тест успешно выполнен.%ПереводСтроки%%ДополнительноеОписание%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
		                                                                  "",
		                                                                  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
		                                                                           "",
		                                                                           AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	Else
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
