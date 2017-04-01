#Region FormEventsHandlers

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not ValueIsFilled(DataProcessorFileName) Or Not ValueIsFilled(DataProcessorFileAddress) Then
		
		CommonUseClientServer.MessageToUser(NStr("en='Specify file of external report or data processor';ru='Укажите файл внешнего отчета или обработки'"), , "DataProcessorFileAddress");
		Cancel = True;
		
	EndIf;
	
	If Not ValueIsFilled(SafeMode) Then
		
		CommonUseClientServer.MessageToUser(NStr("en='Specify a safe mode to connect an external module';ru='Укажите безопасный режим для подключения внешнего модуля'"), , "SafeMode");
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormManagementItemsEventsHandlers

&AtClient
Procedure DataProcessorFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = True;
	
	Notification = New NotifyDescription("DataProcessorFileNameStartChoiceAfterPlacingFile", ThisObject);
	BeginPutFile(Notification, , , True, ThisObject.UUID);
	
EndProcedure

&AtClient
Procedure DataProcessorFileNameStartChoiceAfterPlacingFile(Result, Address, SelectedFileName, Context) Export
	
	If Result Then
		
		DataProcessorFileName = SelectedFileName;
		DataProcessorFileAddress = Address;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataProcessorFileNameClearing(Item, StandardProcessing)
	
	DeleteFromTempStorage(DataProcessorFileAddress);
	
	DataProcessorFileAddress = "";
	DataProcessorFileName = "";
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ConnectAndOpen(Command)
	
	If CheckFilling() Then
		
		Name = EnableOnServer();
		
		Extension = Right(Lower(TrimAll(DataProcessorFileName)), 3);
		
		If Extension = "epf" Then
			
			ExternalModuleFormName = "ExternalDataProcessor." + Name + ".Form";
			
		Else
			
			ExternalModuleFormName = "ExternalReport." + Name + ".Form";
			
		EndIf;
		
		OpenForm(ExternalModuleFormName, , ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function EnableOnServer()
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en='Insufficient access rights.';ru='Недостаточно прав доступа.'");
	EndIf;
	
	Extension = Right(Lower(TrimAll(DataProcessorFileName)), 3);
	
	If Extension = "epf" Then
		
		Manager = ExternalDataProcessors;
		
	ElsIf Extension = "erf" Then
		
		Manager = ExternalReports;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'File %1 is not a file of an external report or data processor"), DataProcessorFileName);
		
	EndIf;
	
	Name = Manager.Connect(DataProcessorFileAddress, , SafeMode);
	
	Return Name;
	
EndFunction

#EndRegion














